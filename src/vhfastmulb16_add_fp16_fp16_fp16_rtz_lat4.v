// ----------------------------------------------
// vhlibvbf16 - Pipelined FP16 adder with RTZ rounding.
// RTZ = round toward zero (отсечение), без DSP.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4.v
// Module: vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4
// FP16 + FP16 -> FP16 (round toward zero)
// Latency 4 clk, fully pipelined
// Subnormal inputs are treated as finite values (no FTZ).
// NaN payload: sign and mantissa fields preserved from the NaN operand.
// Zero sign: per IEEE-754 default (+0 + (-0) = +0; exact cancellation -> +0).
// en=0: HOLD (drain accepted data, keep last value)
// reset: synchronous, priority over en
// ----------------------------------------------

/**
 * @brief  Pipelined FP16 adder with round-toward-zero (RTZ) rounding.
 *
 * Computes outf16c = inf16a + inf16b per IEEE-754 binary16.
 * Since the exact f16 sum may require more than 11 significand bits,
 * the mantissa datapath is extended to 14 bits (11 significand bits +
 * guard/round/sticky).  RTZ rounding simply drops the three low bits,
 * but the extension is required to align the smaller operand without
 * losing information (sticky is folded into bit 0).
 *
 * Subnormal operands are not flushed to zero: they are normalized into
 * the F16 result, which allows exact representation of sums such as
 * min_subnormal + min_subnormal = 2^-23.
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
 *   S4: subnormal shift, RTZ truncation, F16 pack -> output register
 *
 * @param clk     Clock signal.
 * @param reset   Synchronous reset, active high, priority over en.
 * @param en      Enable: accept a new sample when 1, hold when 0.
 * @param inf16a  First FP16 operand: [15] sign, [14:10] exp, [9:0] frac.
 * @param inf16b  Second FP16 operand: [15] sign, [14:10] exp, [9:0] frac.
 * @param outf16c FP16 result: [15] sign, [14:10] exp, [9:0] frac.
 */
module vhfastmulb16_add_fp16_fp16_fp16_rtz_lat4 (
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
    // Stage S1: exponent compare, mantissa alignment, sign determination
    //   Combinational during cycle N, captured at N+1 edge
    //
    //   Timing driven structure:
    //     * |ea - eb| is computed by two independent subtractors.  Only one
    //       of them does not wrap, and each drives its own shifter, so no
    //       absolute-value mux sits in front of the barrel shifters;
    //     * the magnitude comparison runs in parallel with the alignment and
    //       only selects the final hi/lo pair and the sign;
    //     * a true difference of 14 or more shifts every significand bit out
    //       naturally (only the sticky bit survives).
    // ------------------------------------------------------------------
    wire [4:0] ea = a_exp_eff;
    wire [4:0] eb = b_exp_eff;

    // d_ab is the true difference when ea >= eb, d_ba when eb >= ea.
    // This avoids an absolute-value mux on the shifter select path.
    wire [4:0] d_ab = ea - eb;
    wire [4:0] d_ba = eb - ea;

    // Only the low five bits drive the barrel shifter.  For a 14-bit extended
    // mantissa, any shift >= 14 shifts all significand bits out naturally;
    // only the sticky bit survives.  Differences 14..31 flush naturally.
    wire [4:0] sh_ab = d_ab[4:0];   // shifts b
    wire [4:0] sh_ba = d_ba[4:0];   // shifts a

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
    // When op_add is set both signs are equal, so the magnitude mux already
    // yields a_sign; the NaN/zero cases are folded into one late mux.
    wire sign_mag  = a_larger ? a_sign : b_sign;
    wire sign_spec = res_nan ? nan_sign_c : (a_sign & b_sign);
    wire spec_sel  = res_nan || res_zero;
    wire sign_res_c = spec_sel ? sign_spec : sign_mag;

    wire [13:0] hi_al_c     = a_larger ? a_man_ext : b_man_ext;
    wire [13:0] lo_al_final = a_larger ? b_sh : a_sh;
    wire [4:0]  exp_max_c   = a_larger ? ea : eb;

    // ------------------------------------------------------------------
    // Stage S1 -> Stage S2 registers (capture at N+1 edge)
    // ------------------------------------------------------------------
    reg [13:0] man_hi_al_d1;
    reg [13:0] man_lo_al_d1;
    reg [4:0]  exp_max_d1;
    reg        sign_res_d1;
    reg        op_add_d1;
    reg [2:0]  flags_d1;     // {nan, inf, zero}
    reg        is_bz_d1;     // both inputs zero
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
            man_hi_al_d1     <= hi_al_c;
            man_lo_al_d1     <= lo_al_final;
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

    // Subnormal shift for S4: 4 - exp_pre == (4 - exp_adj) + lzd.
    // exp_pre >= -25 for finite inputs, so five bits are sufficient.
    wire [4:0] sub_base    = 5'd4 - exp_adj[4:0];
    wire [4:0] sub_shift_c = sub_base + lzd_c;

    // ------------------------------------------------------------------
    // Stage S3 -> Stage S4 registers (capture at N+3 edge)
    // ------------------------------------------------------------------
    reg [13:0] man_norm_d1;
    reg [5:0]  exp_pre_d1;
    reg [4:0]  sub_shift_d1;
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
            sub_shift_d1   <= 5'd0;
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
            sub_shift_d1   <= sub_shift_c;
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
    // Stage S4: subnormal shift / truncation + F16 pack -> output register
    //   Normal:    exp = exp_pre (1..30), frac = man_norm[12:3]
    //              (three G/R/S bits are dropped, RTZ truncation)
    //   Subnormal: value = 1.f * 2^(exp_pre - 15)
    //              frac = man_norm >> (4 - exp_pre), exp field = 0
    // ------------------------------------------------------------------
    wire        exp_nonpos = exp_pre_d1[5] | (exp_pre_d1 == 6'd0);
    wire [13:0] man_sub     = man_norm_d1 >> sub_shift_d1;
    wire [9:0]  frac_sub    = man_sub[9:0];
    wire [9:0]  frac_norm   = man_norm_d1[12:3];
    wire [9:0]  frac_sel    = exp_nonpos ? frac_sub : frac_norm;
    wire [4:0]  exp_sel     = exp_nonpos ? 5'd0 : exp_pre_d1[4:0];

    reg [15:0] c_next;

    always @(*) begin
        if (flags_d3[2]) begin
            // NaN: preserve sign and payload, force quiet bit
            c_next = {nan_sign_d3, 5'h1F, nan_frac_d3};
        end else if (flags_d3[1] || (exp_pre_d1 == 6'd31)) begin
            // Inf, or overflow of a finite sum: {sign, 31, 0}
            c_next = {sign_res_d3, 5'h1F, 10'h000};
        end else if (flags_d3[0] || is_zero_d3) begin
            // Zero
            if (flags_d3[0])
                // Both inputs zero: sign = a_sign & b_sign (IEEE-754: (-0)+(-0)=-0)
                c_next = {zero_and_sign_d3, 15'h0000};
            else
                // Exact cancellation: RTZ -> +0
                c_next = {1'b0, 15'h0000};
        end else begin
            // Normal (exp_sel >= 1) or subnormal (exp_sel == 0) result
            c_next = {sign_res_d3, exp_sel, frac_sel};
        end
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