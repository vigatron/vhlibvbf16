// ----------------------------------------------
// vhlibvbf16 - Pipelined BF16 adder with RNE rounding.
// RNE = round-to-nearest-even (IEEE-754 default), без DSP.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_add_bf16_bf16_bf16_rne_lat4.v
// Module: vhfastmulb16_add_bf16_bf16_bf16_rne_lat4
// BF16 + BF16 -> BF16 (round-to-nearest-even)
// Latency 4 clk, fully pipelined
// Subnormal inputs are treated as finite values (no FTZ).
// NaN policy: canonical quiet NaN 0x7FC0 (payload is not propagated).
// Zero sign: per IEEE-754 default (+0 + (-0) = +0; exact cancellation -> +0).
// Overflow (RNE): Inf 0x7F80 (IEEE-754 default rounding).
// en=0: HOLD (drain accepted data, keep last value)
// reset: synchronous, priority over en
// ----------------------------------------------

/**
 * @brief  Pipelined BF16 adder with round-to-nearest-even (RNE) rounding.
 *
 * Computes obf16c = ibf16a + ibf16b for the bfloat16 format
 * (s[15] | exp[14:7] | frac[6:0], bias 127).
 *
 * The 8-bit BF16 significand is extended to 14 bits (8 significand bits +
 * 6 guard bits).  The six guard bits make the alignment exact for exponent
 * differences up to 6 and provide enough G/R/S information after
 * normalization; for larger differences the smaller operand is collapsed
 * into a sticky bit, which is sufficient because the result is dominated
 * by the larger operand and the normalization shift is at most one.
 *
 * Rounding uses guard (G), round (R) and sticky (S) bits:
 *   G=0          -> truncate
 *   G=1, R|S=1   -> round up
 *   G=1, R=0, S=0 -> tie: round to even (increment if LSB of kept part = 1)
 *
 * Subnormal operands are not flushed to zero.  All finite BF16 values are
 * integer multiples of 2^-133, therefore every non-zero subnormal sum is
 * exactly representable; the subnormal rounding path is kept as a
 * defensive implementation of the specification.
 *
 * NaN handling: any NaN operand or Inf + (-Inf) produces the canonical
 * quiet NaN 0x7FC0; sign and payload are not propagated.
 *
 * Overflow in RNE mode produces Inf, as required by IEEE-754 default
 * rounding.
 *
 * Pipeline is balanced in 4 stages:
 *   S1: unpack, class flags, exponent compare, mantissa alignment + sticky
 *   S2: 15-bit mantissa add/sub (bit 14 = addition carry)
 *   S3: carry fix-up, LZD, 9-bit signed exponent, G/R/S shift precompute
 *   S4: RNE rounding, subnormal shift, BF16 pack -> output register
 *
 * @param clk     Clock signal.
 * @param reset   Synchronous reset, active high, priority over en.
 * @param en      Enable: accept a new sample when 1, hold when 0.
 * @param ibf16a  First BF16 operand: [15] sign, [14:7] exp, [6:0] frac.
 * @param ibf16b  Second BF16 operand: [15] sign, [14:7] exp, [6:0] frac.
 * @param obf16c  BF16 result: [15] sign, [14:7] exp, [6:0] frac.
 */
module vhfastmulb16_add_bf16_bf16_bf16_rne_lat4 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [15:0] ibf16a,
    input  wire [15:0] ibf16b,
    output reg  [15:0] obf16c
);

    // ------------------------------------------------------------------
    // Operand unpack (combinational, stage S1)
    // ------------------------------------------------------------------
    wire       a_sign = ibf16a[15];
    wire       b_sign = ibf16b[15];
    wire [7:0] a_exp  = ibf16a[14:7];
    wire [7:0] b_exp  = ibf16b[14:7];
    wire [6:0] a_frac = ibf16a[6:0];
    wire [6:0] b_frac = ibf16b[6:0];

    wire a_exp_z  = (a_exp == 8'h00);
    wire b_exp_z  = (b_exp == 8'h00);
    wire a_frac_z = (a_frac == 7'h00);
    wire b_frac_z = (b_frac == 7'h00);

    wire a_zero = a_exp_z && a_frac_z;
    wire b_zero = b_exp_z && b_frac_z;
    wire a_sub  = a_exp_z && !a_frac_z;
    wire b_sub  = b_exp_z && !b_frac_z;
    wire a_inf  = (a_exp == 8'hFF) && a_frac_z;
    wire b_inf  = (b_exp == 8'hFF) && b_frac_z;
    wire a_nan  = (a_exp == 8'hFF) && !a_frac_z;
    wire b_nan  = (b_exp == 8'hFF) && !b_frac_z;

    // ------------------------------------------------------------------
    // Exception classification (combinational, stage S1)
    // ------------------------------------------------------------------
    wire res_nan   = a_nan || b_nan || (a_inf && b_inf && (a_sign != b_sign));
    wire res_inf   = !res_nan && (a_inf || b_inf);
    wire both_zero = !res_nan && !res_inf && a_zero && b_zero;
    wire op_add    = (a_sign == b_sign);   // 1: add magnitudes, 0: subtract

    // ------------------------------------------------------------------
    // Effective exponent and mantissa (no FTZ for subnormals)
    //   normal:    value = {1'b1, frac} * 2^(exp - 127)
    //   subnormal: value = {1'b0, frac} * 2^(1 - 127) = frac * 2^-133
    // ------------------------------------------------------------------
    wire [7:0] a_exp_eff = a_exp_z ? 8'd1 : a_exp;
    wire [7:0] b_exp_eff = b_exp_z ? 8'd1 : b_exp;
    wire [7:0] a_man     = a_exp_z ? {1'b0, a_frac} : {1'b1, a_frac};
    wire [7:0] b_man     = b_exp_z ? {1'b0, b_frac} : {1'b1, b_frac};

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
    //     * two independent 8-bit subtractors compute the exponent
    //       differences; only the non-wrapping one drives the shifter for
    //       the smaller operand, so no absolute-value mux is on the path;
    //     * the 8-bit difference is split into a high nibble (>= 16) and a
    //       low nibble.  A true difference >= 16 flushes every mantissa bit
    //       into the sticky bit; differences 14 and 15 also flush naturally
    //       through the 4-bit shifter;
    //     * the magnitude compare runs in parallel with alignment and only
    //       selects the final hi/lo pair and the result sign.
    // ------------------------------------------------------------------
    wire [7:0] ea = a_exp_eff;
    wire [7:0] eb = b_exp_eff;

    // d_ab is the true difference when ea >= eb, d_ba when eb >= ea.
    wire [7:0] d_ab = ea - eb;
    wire [7:0] d_ba = eb - ea;

    wire       ab_hi = |d_ab[7:4];   // diff >= 16: all significand bits out
    wire [3:0] ab_lo = d_ab[3:0];
    wire       ba_hi = |d_ba[7:4];
    wire [3:0] ba_lo = d_ba[3:0];

    // 14-bit extended mantissas: 8-bit significand + 6 low bits.
    wire [13:0] a_man_ext = {a_man, 6'b000000};
    wire [13:0] b_man_ext = {b_man, 6'b000000};

    // Sticky-inclusive right shift: every discarded bit is ORed into bit 0.
    // p4[i] = |x[i:0] is a log-depth prefix OR; pv2[j] = |x[j-1:0].
    wire [13:0] ap1 = a_man_ext | (a_man_ext << 1);
    wire [13:0] ap2 = ap1 | (ap1 << 2);
    wire [13:0] ap3 = ap2 | (ap2 << 4);
    wire [13:0] ap4 = ap3 | (ap3 << 8);
    wire [15:0] apv = {{2{ap4[13]}}, ap4};
    wire [15:0] apv2 = {apv[14:0], 1'b0};

    wire [13:0] bp1 = b_man_ext | (b_man_ext << 1);
    wire [13:0] bp2 = bp1 | (bp1 << 2);
    wire [13:0] bp3 = bp2 | (bp2 << 4);
    wire [13:0] bp4 = bp3 | (bp3 << 8);
    wire [15:0] bpv = {{2{bp4[13]}}, bp4};
    wire [15:0] bpv2 = {bpv[14:0], 1'b0};

    wire [13:0] a_sh = ba_hi ? 14'd0 : (a_man_ext >> ba_lo);
    wire        a_st = ba_hi ? (|a_man_ext) : apv2[ba_lo];
    wire [13:0] b_sh = ab_hi ? 14'd0 : (b_man_ext >> ab_lo);
    wire        b_st = ab_hi ? (|b_man_ext) : bpv2[ab_lo];

    wire [13:0] a_al = a_sh | {13'd0, a_st};
    wire [13:0] b_al = b_sh | {13'd0, b_st};

    // Magnitude compare of {exponent, mantissa}: parallel-prefix
    // "equal in all higher bits" tree instead of a carry chain.
    wire [15:0] mag_a = {ea, a_man};
    wire [15:0] mag_b = {eb, b_man};
    wire [15:0] g_bit = mag_a & ~mag_b;
    wire [15:0] e_bit = ~(mag_a ^ mag_b);
    wire [15:0] e_suf1 = e_bit  & {1'b1,            e_bit[15:1]};
    wire [15:0] e_suf2 = e_suf1 & {2'b11,           e_suf1[15:2]};
    wire [15:0] e_suf4 = e_suf2 & {4'hF,            e_suf2[15:4]};
    wire [15:0] e_suf8 = e_suf4 & {8'hFF,           e_suf4[15:8]};
    wire [15:0] higher_eq = {1'b1, e_suf8[15:1]};
    wire        a_larger  = (|(g_bit & higher_eq)) | (&e_bit);

    // Sign of the result.  For both-zero the IEEE-754 rule is
    // (+0)+(-0)=+0 and (-0)+(-0)=-0; exact cancellation is forced to +0
    // later by is_zero.
    wire sign_mag   = a_larger ? a_sign : b_sign;
    wire zero_sign  = a_sign & b_sign;
    wire sign_res_c = both_zero ? zero_sign : sign_mag;

    wire [13:0] hi_al_c   = a_larger ? a_man_ext : b_man_ext;
    wire [13:0] lo_al_c   = a_larger ? b_al : a_al;
    wire [7:0]  exp_max_c = a_larger ? ea : eb;

    // ------------------------------------------------------------------
    // Stage S1 -> Stage S2 registers (capture at N+1 edge)
    // ------------------------------------------------------------------
    reg [13:0] man_hi_al_d1;
    reg [13:0] man_lo_al_d1;
    reg [7:0]  exp_max_d1;
    reg        sign_res_d1;
    reg        op_add_d1;
    reg [1:0]  flags_d1;      // {nan, inf}
    reg        both_zero_d1;
    reg        zero_sign_d1;

    always @(posedge clk) begin
        if (reset) begin
            man_hi_al_d1 <= 14'd0;
            man_lo_al_d1 <= 14'd0;
            exp_max_d1   <= 8'd0;
            sign_res_d1  <= 1'b0;
            op_add_d1    <= 1'b0;
            flags_d1     <= 2'b00;
            both_zero_d1 <= 1'b0;
            zero_sign_d1 <= 1'b0;
        end else if (en_pipe) begin
            man_hi_al_d1 <= hi_al_c;
            man_lo_al_d1 <= lo_al_c;
            exp_max_d1   <= exp_max_c;
            sign_res_d1  <= sign_res_c;
            op_add_d1    <= op_add;
            flags_d1     <= {res_nan, res_inf};
            both_zero_d1 <= both_zero;
            zero_sign_d1 <= zero_sign;
        end
    end

    // ------------------------------------------------------------------
    // Stage S2: mantissa add/sub
    //   man_hi_al_d1 is always the larger magnitude, so subtraction is
    //   unconditional hi - lo (bit 14 is only set by addition carry).
    //   Combinational during cycle N+1, captured at N+2 edge.
    // ------------------------------------------------------------------
    wire [14:0] man_raw_c = op_add_d1 ?
                            ({1'b0, man_hi_al_d1} + {1'b0, man_lo_al_d1}) :
                            ({1'b0, man_hi_al_d1} - {1'b0, man_lo_al_d1});

    // ------------------------------------------------------------------
    // Stage S2 -> Stage S3 registers (capture at N+2 edge)
    // ------------------------------------------------------------------
    reg [14:0] man_raw_d1;
    reg [7:0]  exp_max_d2;
    reg        sign_res_d2;
    reg [1:0]  flags_d2;
    reg        both_zero_d2;
    reg        zero_sign_d2;

    always @(posedge clk) begin
        if (reset) begin
            man_raw_d1   <= 15'd0;
            exp_max_d2   <= 8'd0;
            sign_res_d2  <= 1'b0;
            flags_d2     <= 2'b00;
            both_zero_d2 <= 1'b0;
            zero_sign_d2 <= 1'b0;
        end else if (en_pipe) begin
            man_raw_d1   <= man_raw_c;
            exp_max_d2   <= exp_max_d1;
            sign_res_d2  <= sign_res_d1;
            flags_d2     <= flags_d1;
            both_zero_d2 <= both_zero_d1;
            zero_sign_d2 <= zero_sign_d1;
        end
    end

    // ------------------------------------------------------------------
    // Stage S3: normalization (LZD) + 9-bit signed exponent
    //   Combinational during cycle N+2, captured at N+3 edge.
    //   man_norm has its leading one at bit 13; exp_pre is a 9-bit
    //   two's-complement unbiased exponent (negative => subnormal).
    // ------------------------------------------------------------------
    wire        man_carry = man_raw_d1[14];
    wire [13:0] man_norm0 = man_carry ?
                            ({1'b0, man_raw_d1[14:1]} | {13'd0, man_raw_d1[0]}) :
                            man_raw_d1[13:0];
    wire [8:0]  exp_adj   = {1'b0, exp_max_d2} + {8'd0, man_carry};

    // Leading-zero detect over the 15-bit raw sum.
    wire [14:0] lz1   = man_raw_d1 | (man_raw_d1 >> 1);
    wire [14:0] lz2   = lz1 | (lz1 >> 2);
    wire [14:0] lz4   = lz2 | (lz2 >> 4);
    wire [14:0] lz8   = lz4 | (lz4 >> 8);
    wire [14:0] lz_oh = lz8 & ~{1'b0, lz8[14:1]};

    wire [3:0] lzd_c;
    assign lzd_c[0] = |(lz_oh & 15'b001010101010101);
    assign lzd_c[1] = |(lz_oh & 15'b000110011001100);
    assign lzd_c[2] = |(lz_oh & 15'b000001111000011);
    assign lzd_c[3] = |(lz_oh & 15'b000000000111111);

    wire [13:0] man_norm_c = man_norm0 << lzd_c;

    // exp_pre = exp_adj - lzd, 9-bit Kogge-Stone prefix borrow chain.
    wire [8:0] ep_lz = {5'd0, lzd_c};
    wire [8:0] ep_p  = ~exp_adj | ep_lz;
    wire [8:0] ep_g  = ~exp_adj & ep_lz;
    wire [8:0] ep_g1 = ep_g  | (ep_p  & {ep_g[7:0],  1'b0});
    wire [8:0] ep_p1 = ep_p  & {ep_p[7:0],  1'b0};
    wire [8:0] ep_g2 = ep_g1 | (ep_p1 & {ep_g1[6:0], 2'b00});
    wire [8:0] ep_p2 = ep_p1 & {ep_p1[6:0], 2'b00};
    wire [8:0] ep_g3 = ep_g2 | (ep_p2 & {ep_g2[4:0], 4'b0000});
    wire [8:0] ep_p3 = ep_p2 & {ep_p2[4:0], 4'b0000};
    wire [8:0] ep_g4 = ep_g3 | (ep_p3 & {ep_g3[0], 8'b00000000});
    wire [8:0] exp_pre_c = (exp_adj ^ ep_lz) ^ {ep_g4[7:0], 1'b0};

    // G/R/S shift for the subnormal path:
    //   frac = man_norm >> sub_shift, sub_shift = 7 - exp_pre
    //   grs_shift = sub_shift - 2 = 5 - exp_pre
    //   = 5 - exp_adj + lzd
    // After shifting by grs_shift:
    //   man_grs[0] = R, man_grs[1] = G, man_grs[8:2] = frac.
    wire [4:0] grs_base    = 5'd5 - exp_adj[4:0];
    wire [4:0] grs_shift_c = grs_base + {1'b0, lzd_c};

    // ------------------------------------------------------------------
    // Stage S3 -> Stage S4 registers (capture at N+3 edge)
    // ------------------------------------------------------------------
    reg [13:0] man_norm_d1;
    reg [8:0]  exp_pre_d1;
    reg [4:0]  grs_shift_d1;
    reg        sign_res_d3;
    reg [1:0]  flags_d3;
    reg        both_zero_d3;
    reg        zero_sign_d3;
    reg        is_zero_d3;

    always @(posedge clk) begin
        if (reset) begin
            man_norm_d1  <= 14'd0;
            exp_pre_d1   <= 9'd0;
            grs_shift_d1 <= 5'd0;
            sign_res_d3  <= 1'b0;
            flags_d3     <= 2'b00;
            both_zero_d3 <= 1'b0;
            zero_sign_d3 <= 1'b0;
            is_zero_d3   <= 1'b0;
        end else if (en_pipe) begin
            man_norm_d1  <= man_norm_c;
            exp_pre_d1   <= exp_pre_c;
            grs_shift_d1 <= grs_shift_c;
            sign_res_d3  <= sign_res_d2;
            flags_d3     <= flags_d2;
            both_zero_d3 <= both_zero_d2;
            zero_sign_d3 <= zero_sign_d2;
            is_zero_d3   <= (man_raw_d1 == 15'd0) && !both_zero_d2;
        end
    end

    // ------------------------------------------------------------------
    // Stage S4: RNE rounding + BF16 pack
    //
    // Normal result (exp_pre >= 1):
    //   kept = man_norm[13:6]  (8-bit significand, hidden bit at kept[7])
    //   G = man_norm[5], R = man_norm[4], S = |man_norm[3:0]
    //   round up when G & (R | S | kept[0])   (ties to even)
    //   carry out of kept -> frac = 0, exponent + 1
    //
    // Subnormal result (exp_pre <= 0):
    //   frac = man_norm >> sub_shift (7 bits)
    //   G = bit (sub_shift-1), R = bit (sub_shift-2),
    //   S = OR of all bits below R.
    //   A carry out of the 7-bit frac -> smallest normal (exp=1, frac=0).
    // ------------------------------------------------------------------
    wire [7:0] kept     = man_norm_d1[13:6];
    wire       g_norm   = man_norm_d1[5];
    wire       r_norm   = man_norm_d1[4];
    wire       s_norm   = |man_norm_d1[3:0];
    wire       rup_norm = g_norm && (r_norm | s_norm | kept[0]);

    wire [8:0] kept_inc = {1'b0, kept} + {8'd0, rup_norm};
    wire       ovf_norm = kept_inc[8];
    wire [6:0] frac_norm = ovf_norm ? 7'd0 : kept_inc[6:0];

    // Prefix OR for the subnormal sticky bit:
    // low_or[j] = |man_norm_d1[j-1:0], low_or[0] = 0.
    wire [13:0] lo1 = man_norm_d1 | (man_norm_d1 << 1);
    wire [13:0] lo2 = lo1 | (lo1 << 2);
    wire [13:0] lo4 = lo2 | (lo2 << 4);
    wire [13:0] lo8 = lo4 | (lo4 << 8);
    wire [15:0] low_or = {lo8[13], lo8, 1'b0};

    // Defensive clamp: for grs_shift > 15 the result is far below the
    // minimum subnormal and rounds to zero; index 15 gives G=0, R=0.
    wire [4:0] grs_shift_eff = (grs_shift_d1 > 5'd15) ? 5'd15 : grs_shift_d1;

    wire [13:0] man_grs  = man_norm_d1 >> grs_shift_eff;
    wire        r_sub    = man_grs[0];
    wire        g_sub    = man_grs[1];
    wire [6:0]  frac_sub = man_grs[8:2];
    wire        s_sub    = low_or[grs_shift_eff];
    wire        rup_sub  = g_sub && (r_sub | s_sub | frac_sub[0]);

    wire [7:0] frac_inc = {1'b0, frac_sub} + {7'd0, rup_sub};
    wire       ovf_sub  = frac_inc[7];
    wire [6:0] frac_sub_final = ovf_sub ? 7'd0 : frac_inc[6:0];

    // Exponent selection and overflow detection.  exp_pre + 1 and the
    // overflow flags are derived from the registered exponent in parallel
    // with the mantissa increment.
    wire        sub_out    = exp_pre_d1[8] | (exp_pre_d1 == 9'd0);
    wire [8:0]  exp_plus1  = exp_pre_d1 + 9'd1;
    // Negative exp_pre (bit 8 = 1) is a subnormal result, not overflow.
    wire        exp_ovf    = (!exp_pre_d1[8] && (exp_pre_d1 >= 9'd255)) |
                             (exp_pre_d1 == 9'd256) |
                             (!sub_out && (exp_pre_d1 == 9'd254) && ovf_norm);
    wire [7:0]  exp_norm_final = ovf_norm ? exp_plus1[7:0] : exp_pre_d1[7:0];
    wire [7:0]  exp_sub_final  = ovf_sub ? 8'd1 : 8'd0;
    wire [7:0]  exp_final      = sub_out ? exp_sub_final : exp_norm_final;
    wire [6:0]  frac_final     = sub_out ? frac_sub_final : frac_norm;

    reg [15:0] c_next;

    always @(*) begin
        if (flags_d3[1]) begin
            // NaN: canonical quiet NaN
            c_next = 16'h7FC0;
        end else if (flags_d3[0] || exp_ovf) begin
            // Infinity or RNE overflow
            c_next = {sign_res_d3, 8'hFF, 7'h00};
        end else if (both_zero_d3) begin
            // IEEE-754: (-0)+(-0) = -0, (+0)+(-0) = +0
            c_next = {zero_sign_d3, 15'h0000};
        end else if (is_zero_d3) begin
            // Exact cancellation of non-zero operands -> +0
            c_next = 16'h0000;
        end else begin
            // Normal (exp_sel >= 1) or subnormal (exp_sel == 0) result
            c_next = {sign_res_d3, exp_final, frac_final};
        end
    end

    // ------------------------------------------------------------------
    // Output register (cycle N+4)
    // reset has priority over en; en=0 holds the last value (HOLD).
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            obf16c <= 16'h0000;
        end else if (en_pipe) begin
            obf16c <= c_next;
        end
        // else: HOLD (keep last value)
    end

endmodule
