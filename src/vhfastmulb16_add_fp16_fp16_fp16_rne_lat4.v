// ----------------------------------------------
// vhlibvbf16 - Pipelined FP16 adder with RNE rounding.
// RNE = round-to-nearest-even (IEEE-754 default), без DSP.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_add_fp16_fp16_fp16_rne_lat4.v
// Module: vhfastmulb16_add_fp16_fp16_fp16_rne_lat4
// FP16 + FP16 -> FP16 (round-to-nearest-even)
// Latency 4 clk, fully pipelined
// Subnormal inputs are treated as finite values (no FTZ).
// NaN payload: sign and mantissa fields preserved from the NaN operand.
// Zero sign: per IEEE-754 default (+0 + (-0) = +0; exact cancellation -> +0).
// en=0: HOLD (drain accepted data, keep last value)
// reset: synchronous, priority over en
// ----------------------------------------------

/**
 * @brief  Pipelined FP16 adder with round-to-nearest-even (RNE) rounding.
 *
 * Computes outf16c = inf16a + inf16b per IEEE-754 binary16 with default
 * rounding mode (round-to-nearest, ties to even).
 *
 * Rounding uses guard (G), round (R), sticky (S) bits obtained from the
 * normalized 14-bit mantissa (11-bit significand + G/R/S):
 *   G=0   -> truncate
 *   G=1, R|S=1 -> round up (increment significand)
 *   G=1, R=0, S=0 -> tie: round to even (increment if LSB of kept part = 1)
 *
 * Sticky bit is computed during mantissa alignment (S1) to capture bits
 * lost when the smaller operand is right-shifted for exponent matching.
 * Since the alignment shift is performed on a 14-bit extended value
 * (11 significand bits + 3 zero bits), a non-zero sticky implies that the
 * result is almost equal to the larger operand, hence the normalization
 * shift is at most 1 and the sticky stays in the G/R/S field.
 *
 * Subnormal operands are not flushed to zero: they are normalized into
 * the F16 result.
 *
 * NaN handling: sign and mantissa (payload) fields are preserved from
 * the NaN operand; the quiet bit (frac[9]) is forced to 1.
 *
 * Zero sign: per IEEE-754 default — (+0)+(-0) = +0, (-0)+(-0) = -0,
 * and exact cancellation of non-zero operands yields +0.
 *
 * Pipeline is balanced 4 stages:
 *   S1: operand unpack, class flags, exponent compare, mantissa alignment (with sticky)
 *   S2: mantissa add/sub (15-bit raw result, bit 14 = carry)
 *   S3: carry fix-up, normalization (LZD), 6-bit signed exponent
 *   S4: RNE rounding, subnormal shift, F16 pack -> output register
 *
 * @param clk     Clock signal.
 * @param reset   Synchronous reset, active high, priority over en.
 * @param en      Enable: accept a new sample when 1, hold when 0.
 * @param inf16a  First FP16 operand: [15] sign, [14:10] exp, [9:0] frac.
 * @param inf16b  Second FP16 operand: [15] sign, [14:10] exp, [9:0] frac.
 * @param outf16c FP16 result: [15] sign, [14:10] exp, [9:0] frac.
 */
module vhfastmulb16_add_fp16_fp16_fp16_rne_lat4 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [15:0] inf16a,
    input  wire [15:0] inf16b,
    output reg  [15:0] outf16c
);

    // ------------------------------------------------------------------
    // Operand unpack (combinational, stage S1)
    // ------------------------------------------------------------------
    wire       a_sign = inf16a[15];
    wire       b_sign = inf16b[15];
    wire [4:0] a_exp  = inf16a[14:10];
    wire [4:0] b_exp  = inf16b[14:10];
    wire [9:0] a_frac = inf16a[9:0];
    wire [9:0] b_frac = inf16b[9:0];

    wire a_exp_z  = (a_exp == 5'h00);
    wire b_exp_z  = (b_exp == 5'h00);
    wire a_frac_z = (a_frac == 10'h000);
    wire b_frac_z = (b_frac == 10'h000);

    wire a_zero = a_exp_z && a_frac_z;
    wire b_zero = b_exp_z && b_frac_z;
    wire a_sub  = a_exp_z && !a_frac_z;
    wire b_sub  = b_exp_z && !b_frac_z;
    wire a_inf  = (a_exp == 5'h1F) && a_frac_z;
    wire b_inf  = (b_exp == 5'h1F) && b_frac_z;
    wire a_nan  = (a_exp == 5'h1F) && !a_frac_z;
    wire b_nan  = (b_exp == 5'h1F) && !b_frac_z;

    // ------------------------------------------------------------------
    // Exception classification (combinational, stage S1)
    // ------------------------------------------------------------------
    wire res_nan  = a_nan || b_nan || (a_inf && b_inf && (a_sign != b_sign));
    wire res_inf  = !res_nan && (a_inf || b_inf);
    wire res_zero = !res_nan && !res_inf && (a_zero && b_zero);
    wire op_add   = (a_sign == b_sign);   // 1: add magnitudes, 0: subtract

    // ------------------------------------------------------------------
    // Effective exponent and mantissa (no FTZ for subnormals)
    //   normal:    value = {1'b1, frac} * 2^(exp - 15)
    //   subnormal: value = {1'b0, frac} * 2^(1 - 15) = frac * 2^-24
    // ------------------------------------------------------------------
    wire [4:0] a_exp_eff = a_exp_z ? 5'd1 : a_exp;
    wire [4:0] b_exp_eff = b_exp_z ? 5'd1 : b_exp;
    wire [10:0] a_man = a_exp_z ? {1'b0, a_frac} : {1'b1, a_frac};
    wire [10:0] b_man = b_exp_z ? {1'b0, b_frac} : {1'b1, b_frac};

    // NaN result: preserve sign and payload from the NaN operand, force quiet bit
    wire        nan_sign_c = a_nan ? a_sign : b_sign;
    wire [9:0]  nan_frac_c = a_nan ? (a_frac | 10'h200) : (b_frac | 10'h200);

    // ------------------------------------------------------------------
    // Pipeline enable: 4 stages + output register.
    // After en=0 the pipeline drains 4 cycles, then holds.
    // ------------------------------------------------------------------
    reg en_d1;
    reg en_d2;
    reg en_d3;
    reg en_d4;

    always @(posedge clk) begin
        if (reset) begin
            en_d1 <= 1'b0;
            en_d2 <= 1'b0;
            en_d3 <= 1'b0;
            en_d4 <= 1'b0;
        end else begin
            en_d1 <= en;
            en_d2 <= en_d1;
            en_d3 <= en_d2;
            en_d4 <= en_d3;
        end
    end

    wire en_pipe = en | en_d1 | en_d2 | en_d3 | en_d4;

    // ------------------------------------------------------------------
    // Stage S1: exponent compare, mantissa alignment with sticky bit
    //   Combinational during cycle N, captured at N+1 edge
    //
    //   Timing driven structure:
    //     * |ea - eb| is computed by two independent subtractors; each one
    //       drives its own shifter, so no absolute-value mux sits in front
    //       of the barrel shifters;
    //     * the magnitude comparison runs in parallel with the alignment and
    //       only selects the final hi/lo pair and the sign;
    //     * a true difference >= 32 is flushed to the sticky bit after the
    //       shifter, off the shift-amount critical path.
    // ------------------------------------------------------------------
    wire [4:0] ea = a_exp_eff;
    wire [4:0] eb = b_exp_eff;

    // d_ab is the true difference when ea >= eb, d_ba when eb >= ea.
    // This avoids an absolute-value mux on the shifter select path.
    wire [4:0] d_ab = ea - eb;
    wire [4:0] d_ba = eb - ea;

    // 14-bit extended mantissas: 11-bit significand + 3 low bits (G/R/S).
    wire [13:0] a_man_ext = {a_man, 3'b000};
    wire [13:0] b_man_ext = {b_man, 3'b000};

    // Sticky-inclusive right shift: every discarded bit is ORed into bit 0.
    // p4[i] = |x[i:0] is a log-depth prefix OR, so the sticky bit is the
    // prefix entry selected by sh (no shift-mask decoder, no subtract).
    wire [13:0] ap1 = a_man_ext | (a_man_ext << 1);
    wire [13:0] ap2 = ap1 | (ap1 << 2);
    wire [13:0] ap3 = ap2 | (ap2 << 4);
    wire [13:0] ap4 = ap3 | (ap3 << 8);
    wire [31:0] apv = {{18{ap4[13]}}, ap4};

    wire [13:0] bp1 = b_man_ext | (b_man_ext << 1);
    wire [13:0] bp2 = bp1 | (bp1 << 2);
    wire [13:0] bp3 = bp2 | (bp2 << 4);
    wire [13:0] bp4 = bp3 | (bp3 << 8);
    wire [31:0] bpv = {{18{bp4[13]}}, bp4};

    // pv2[j] = |x[j-1:0] (left shift by one); index 0 is zero so shift == 0
    // yields no sticky.
    wire [31:0] apv2 = {apv[30:0], 1'b0};
    wire [31:0] bpv2 = {bpv[30:0], 1'b0};

    wire [4:0] sh_ab = d_ab[4:0];   // shifts b
    wire [4:0] sh_ba = d_ba[4:0];   // shifts a

    wire [13:0] a_sh = (a_man_ext >> sh_ba) | {13'd0, apv2[sh_ba]};
    wire [13:0] b_sh = (b_man_ext >> sh_ab) | {13'd0, bpv2[sh_ab]};

    // No flush needed for FP16: shifts >= 14 naturally shift all bits out,
    // and apv2[sh] supplies the sticky bit for sh >= 14.

    // Magnitude compare of {exponent, mantissa}: identical to the original
    // (exponent first, mantissa on ties) but built as a parallel-prefix
    // "equal in all higher bits" tree instead of a carry chain.
    wire [15:0] mag_a  = {ea, a_man};
    wire [15:0] mag_b  = {eb, b_man};
    wire [15:0] g_bit  = mag_a & ~mag_b;
    wire [15:0] e_bit  = ~(mag_a ^ mag_b);
    wire [15:0] e_suf1  = e_bit  & {1'b1,            e_bit[15:1]};
    wire [15:0] e_suf2  = e_suf1 & {2'b11,           e_suf1[15:2]};
    wire [15:0] e_suf4  = e_suf2 & {4'hF,            e_suf2[15:4]};
    wire [15:0] e_suf8  = e_suf4 & {8'hFF,           e_suf4[15:8]};
    wire [15:0] higher_eq = {1'b1, e_suf8[15:1]};
    wire        a_larger  = (|(g_bit & higher_eq)) | (&e_bit);

    // Sign of result (NaN and both-zero handled separately below).
    wire sign_mag  = a_larger ? a_sign : b_sign;
    wire sign_spec = res_nan ? nan_sign_c : (a_sign & b_sign);
    wire spec_sel  = res_nan || res_zero;
    wire sign_res_c = spec_sel ? sign_spec : sign_mag;

    wire [13:0] hi_man_ext = a_larger ? a_man_ext : b_man_ext;
    wire [13:0] lo_man_al_c = a_larger ? b_sh : a_sh;

    wire [4:0] exp_max_c = a_larger ? ea : eb;

    // ------------------------------------------------------------------
    // Stage S1 -> Stage S2 registers (capture at N+1 edge)
    // ------------------------------------------------------------------
    reg [13:0] man_hi_al_d1;
    reg [13:0] man_lo_al_d1;
    reg [4:0]  exp_max_d1;
    reg        sign_res_d1;
    reg        op_add_d1;
    reg [2:0]  flags_d1;        // {nan, inf, zero}
    reg        is_bz_d1;        // both inputs zero
    reg        zero_and_sign_d1;
    reg        nan_sign_d1;
    reg [9:0]  nan_frac_d1;

    always @(posedge clk) begin
        if (reset) begin
            man_hi_al_d1     <= 14'd0;
            man_lo_al_d1     <= 14'd0;
            exp_max_d1       <= 5'd0;
            sign_res_d1      <= 1'b0;
            op_add_d1        <= 1'b0;
            flags_d1         <= 3'b000;
            is_bz_d1         <= 1'b0;
            zero_and_sign_d1 <= 1'b0;
            nan_sign_d1      <= 1'b0;
            nan_frac_d1      <= 10'd0;
        end else if (en_pipe) begin
            man_hi_al_d1     <= hi_man_ext;
            man_lo_al_d1     <= lo_man_al_c;
            exp_max_d1       <= exp_max_c;
            sign_res_d1      <= sign_res_c;
            op_add_d1        <= op_add;
            flags_d1         <= {res_nan, res_inf, res_zero};
            is_bz_d1         <= res_zero;
            zero_and_sign_d1 <= a_sign & b_sign;
            nan_sign_d1      <= nan_sign_c;
            nan_frac_d1      <= nan_frac_c;
        end
    end

    // ------------------------------------------------------------------
    // Stage S2: mantissa add/sub
    //   man_hi_al_d1 is always the larger magnitude, so subtraction is
    //   unconditional hi - lo (bit 14 is only set by addition carry).
    //   Combinational during cycle N+1, captured at N+2 edge
    // ------------------------------------------------------------------
    wire [14:0] man_raw_c = op_add_d1 ?
                            ({1'b0, man_hi_al_d1} + {1'b0, man_lo_al_d1}) :
                            ({1'b0, man_hi_al_d1} - {1'b0, man_lo_al_d1});

    // ------------------------------------------------------------------
    // Stage S2 -> Stage S3 registers (capture at N+2 edge)
    // ------------------------------------------------------------------
    reg [14:0] man_raw_d1;
    reg [4:0]  exp_max_d2;
    reg        sign_res_d2;
    reg [2:0]  flags_d2;
    reg        is_bz_d2;
    reg        zero_and_sign_d2;
    reg        nan_sign_d2;
    reg [9:0]  nan_frac_d2;

    always @(posedge clk) begin
        if (reset) begin
            man_raw_d1      <= 15'd0;
            exp_max_d2      <= 5'd0;
            sign_res_d2     <= 1'b0;
            flags_d2        <= 3'b000;
            is_bz_d2        <= 1'b0;
            zero_and_sign_d2 <= 1'b0;
            nan_sign_d2     <= 1'b0;
            nan_frac_d2     <= 10'd0;
        end else if (en_pipe) begin
            man_raw_d1      <= man_raw_c;
            exp_max_d2      <= exp_max_d1;
            sign_res_d2     <= sign_res_d1;
            flags_d2        <= flags_d1;
            is_bz_d2        <= is_bz_d1;
            zero_and_sign_d2 <= zero_and_sign_d1;
            nan_sign_d2     <= nan_sign_d1;
            nan_frac_d2     <= nan_frac_d1;
        end
    end

    // ------------------------------------------------------------------
    // Stage S3: normalization (LZD) + signed exponent
    //   Combinational during cycle N+2, captured at N+3 edge
    //   man_norm has its leading one at bit 13; exp_pre is a 6-bit
    //   two's-complement unbiased exponent (negative => subnormal).
    // ------------------------------------------------------------------
    wire        man_carry = man_raw_d1[14];
    wire [13:0] man_norm0 = man_carry ?
                            ({1'b0, man_raw_d1[14:1]} | {13'd0, man_raw_d1[0]}) :
                            man_raw_d1[13:0];
    wire [5:0]  exp_adj   = {1'b0, exp_max_d2} + {5'd0, man_carry};

    // Leading-zero detect over the 15-bit raw sum.  The addition carry, when
    // present, is the leading one, and it encodes a zero count, so the carry
    // fix-up mux stays off the LZD path.
    wire [14:0] lz1   = man_raw_d1 | (man_raw_d1 >> 1);
    wire [14:0] lz2   = lz1 | (lz1 >> 2);
    wire [14:0] lz4   = lz2 | (lz2 >> 4);
    wire [14:0] lz8   = lz4 | (lz4 >> 8);
    wire [14:0] lz_oh = lz8 & ~{1'b0, lz8[14:1]};

    // One-hot to binary: lzd = 13 - p, with the carry position (14) and
    // position 13 both mapping to 0.  Masks are constant literals.
    wire [3:0] lzd_c;
    assign lzd_c[0] = |(lz_oh & 15'b001010101010101);
    assign lzd_c[1] = |(lz_oh & 15'b000110011001100);
    assign lzd_c[2] = |(lz_oh & 15'b000001111000011);
    assign lzd_c[3] = |(lz_oh & 15'b000000000111111);

    wire [13:0] man_norm_c = man_norm0 << lzd_c;

    // exp_pre = exp_adj - lzd, 6-bit Kogge-Stone prefix borrow chain.
    wire [5:0] ep_lz = {2'd0, lzd_c};
    wire [5:0] ep_p  = ~exp_adj | ep_lz;   // borrow propagate
    wire [5:0] ep_g  = ~exp_adj & ep_lz;   // borrow generate
    wire [5:0] ep_g1 = ep_g  | (ep_p  & {ep_g[4:0],  1'b0});
    wire [5:0] ep_p1 = ep_p  & {ep_p[4:0],  1'b0};
    wire [5:0] ep_g2 = ep_g1 | (ep_p1 & {ep_g1[3:0], 2'b00});
    wire [5:0] ep_p2 = ep_p1 & {ep_p1[3:0], 2'b00};
    wire [5:0] ep_g3 = ep_g2 | (ep_p2 & {ep_g2[1:0], 4'b0000});
    wire [5:0] exp_pre_c = (exp_adj ^ ep_lz) ^ {ep_g3[4:0], 1'b0};

    // Subnormal shift for S4: the RNE guard bit is at
    //   man_norm >> (4 - exp_pre - 1) = man_norm >> (3 - exp_adj + lzd),
    // so the complete shift is precomputed here (exp_pre >= -25 for finite
    // inputs, five bits are sufficient).
    wire [4:0] grs_base    = 5'd3 - exp_adj[4:0];
    wire [4:0] grs_shift_c = grs_base + lzd_c;

    // ------------------------------------------------------------------
    // Stage S3 -> Stage S4 registers (capture at N+3 edge)
    // ------------------------------------------------------------------
    reg [13:0] man_norm_d1;
    reg [5:0]  exp_pre_d1;
    reg [4:0]  grs_shift_d1;
    reg        sign_res_d3;
    reg [2:0]  flags_d3;
    reg        is_bz_d3;
    reg        zero_and_sign_d3;
    reg        is_zero_d3;
    reg        nan_sign_d3;
    reg [9:0]  nan_frac_d3;

    always @(posedge clk) begin
        if (reset) begin
            man_norm_d1    <= 14'd0;
            exp_pre_d1     <= 6'd0;
            grs_shift_d1   <= 5'd0;
            sign_res_d3    <= 1'b0;
            flags_d3       <= 3'b000;
            is_bz_d3       <= 1'b0;
            zero_and_sign_d3 <= 1'b0;
            is_zero_d3     <= 1'b0;
            nan_sign_d3    <= 1'b0;
            nan_frac_d3    <= 10'd0;
        end else if (en_pipe) begin
            man_norm_d1    <= man_norm_c;
            exp_pre_d1     <= exp_pre_c;
            grs_shift_d1   <= grs_shift_c;
            sign_res_d3    <= sign_res_d2;
            flags_d3       <= flags_d2;
            is_bz_d3       <= is_bz_d2;
            zero_and_sign_d3 <= zero_and_sign_d2;
            is_zero_d3     <= (man_raw_d1 == 15'd0) && !is_bz_d2;
            nan_sign_d3    <= nan_sign_d2;
            nan_frac_d3    <= nan_frac_d2;
        end
    end

    // ------------------------------------------------------------------
    // Stage S4: RNE rounding + F16 pack -> output register
    //
    // Normal result:
    //   kept = man_norm[13:4]  (11-bit significand, hidden bit at kept[10])
    //   G = man_norm[3], R = man_norm[2], S = man_norm[1]
    //   round up when G & (R | S | kept[0])  (ties to even)
    //   carry out of kept -> frac = 0, exponent + 1
    //   (the alignment sticky lives in man_norm[0]; see S1 note)
    //
    // Subnormal result (exp_pre <= 0):
    //   frac = man_norm >> (4 - exp_pre)
    //   G = bit below the 10-bit fraction, R = the next one,
    //   S = OR of all remaining low bits; carry out -> smallest normal
    //
    // exp_pre + 1 and the overflow/subnormal flags are derived directly from
    // the registered exponent, in parallel with the rounding increment.
    // ------------------------------------------------------------------
    wire [10:0] kept     = man_norm_d1[13:3];
    wire        g_norm   = man_norm_d1[2];
    wire        r_norm   = man_norm_d1[1];
    wire        s_norm   = man_norm_d1[0];
    wire        rup_norm = g_norm && (r_norm | s_norm | kept[0]);

    wire [11:0] kept_inc = {1'b0, kept} + {10'd0, rup_norm};
    wire        ovf_norm = kept_inc[11];
    wire [10:0] kept_r   = ovf_norm ? 11'h400 : kept_inc[10:0];

    wire [13:0] man_grs   = man_norm_d1 >> grs_shift_d1;
    wire        g_sub     = man_grs[0];
    wire        r_sub     = man_grs[1];
    wire        s_sub     = |man_grs[2:0];
    wire [9:0]  frac_raw  = man_grs[10:1];
    wire        rup_sub   = g_sub && (r_sub | s_sub | frac_raw[0]);

    wire [10:0] frac_inc = {1'b0, frac_raw} + {9'd0, rup_sub};
    wire        ovf_sub  = frac_inc[10];
    wire [9:0]  frac_sub = frac_inc[9:0];

    // exp_pre + 1, overflow and subnormal flags are derived from the
    // registered exponent, in parallel with the rounding increment.
    wire        sub_out    = exp_pre_d1[5] | (exp_pre_d1 == 6'd0);
    wire [4:0]  exp_plus1  = exp_pre_d1[4:0] + 5'd1;
    wire        exp_ge31   = (exp_pre_d1[4:0] == 5'h1F) & ~exp_pre_d1[5];
    wire        exp_eq30   = (exp_pre_d1[4:0] == 5'h1E) & ~exp_pre_d1[5];
    wire        exp_ovf    = !sub_out && (exp_ge31 | (exp_eq30 & ovf_norm));
    wire [4:0]  exp_final  = sub_out ? (ovf_sub ? 5'd1 : 5'd0)
                                      : (ovf_norm ? exp_plus1 : exp_pre_d1[4:0]);
    wire [9:0]  frac_final = sub_out ? (ovf_sub ? 10'd0 : frac_sub)
                                      : kept_r[9:0];

    // Output selection: NaN > Inf/overflow > zero > normal/subnormal.
    // kind = {nan_or_inf, nan_or_zero}; the vector mux is only two levels.
    wire [15:0] v_nan  = {nan_sign_d3, 5'h1F, nan_frac_d3};
    wire [15:0] v_inf  = {sign_res_d3, 5'h1F, 10'h000};
    wire [15:0] v_zero = {zero_and_sign_d3 & flags_d3[0], 15'h0000};
    wire [15:0] v_norm = {sign_res_d3, exp_final, frac_final};

    wire        kind_hi = flags_d3[2] | flags_d3[1] | exp_ovf;
    wire        kind_lo = flags_d3[2] |
                          ((flags_d3[0] | is_zero_d3) & ~(flags_d3[1] | exp_ovf));
    wire [15:0] c_hi   = kind_lo ? v_nan : v_inf;
    wire [15:0] c_lo   = kind_lo ? v_zero : v_norm;

    reg [15:0] c_next;

    always @(*) begin
        c_next = kind_hi ? c_hi : c_lo;
    end

    // ------------------------------------------------------------------
    // Output register (cycle N+4)
    // reset has priority over en; en=0 holds the last value (HOLD).
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            outf16c <= 16'h0000;
        end else if (en_pipe) begin
            outf16c <= c_next;
        end
        // else: HOLD (keep last value)
    end

endmodule