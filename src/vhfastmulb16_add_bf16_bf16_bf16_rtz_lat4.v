// ----------------------------------------------
// vhlibvbf16 - Pipelined BF16 adder with RTZ rounding.
// RTZ = round toward zero (отсечение), без DSP.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4.v
// Module: vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4
// BF16 + BF16 -> BF16 (round toward zero)
// Latency 4 clk, fully pipelined
// Subnormal inputs are treated as finite values (no FTZ).
// NaN policy: canonical quiet NaN 0x7FC0 (payload is not propagated).
// Zero sign: per IEEE-754 default (+0 + (-0) = +0; exact cancellation -> +0).
// Overflow (RTZ): max finite 0x7F7F (strict IEEE-754 roundTowardZero).
// en=0: HOLD (drain accepted data, keep last value)
// reset: synchronous, priority over en
// ----------------------------------------------

/**
 * @brief  Pipelined BF16 adder with round-toward-zero (RTZ) rounding.
 *
 * Computes obf16c = ibf16a + ibf16b for the bfloat16 format
 * (s[15] | exp[14:7] | frac[6:0], bias 127).
 *
 * The 8-bit BF16 significand is extended to 14 bits (8 significand bits +
 * 6 guard bits).  The six guard bits make the alignment exact for exponent
 * differences up to 6 and provide G/R/S information for the RNE variant.
 * For larger differences the smaller operand is collapsed into a sticky
 * bit, which is sufficient because the result is then dominated by the
 * larger operand and the normalization shift is at most one.
 *
 * Subnormal operands are not flushed to zero: they are normalized into
 * the BF16 result.  All finite BF16 values are integer multiples of
 * 2^-133, therefore every non-zero subnormal sum is exactly representable
 * and no subnormal rounding/underflow occurs for valid BF16 inputs.
 *
 * NaN handling: any NaN operand or Inf + (-Inf) produces the canonical
 * quiet NaN 0x7FC0; sign and payload are not propagated.
 *
 * Overflow in RTZ mode saturates to the maximum finite value 0x7F7F,
 * as required by IEEE-754 for roundTowardZero.
 *
 * Pipeline is balanced in 4 stages:
 *   S1: unpack, class flags, exponent compare, mantissa alignment + sticky
 *   S2: 15-bit mantissa add/sub (bit 14 = addition carry)
 *   S3: carry fix-up, LZD, 9-bit signed exponent, subnormal shift
 *   S4: subnormal shift, RTZ truncation, BF16 pack -> output register
 *
 * @param clk     Clock signal.
 * @param reset   Synchronous reset, active high, priority over en.
 * @param en      Enable: accept a new sample when 1, hold when 0.
 * @param ibf16a  First BF16 operand: [15] sign, [14:7] exp, [6:0] frac.
 * @param ibf16b  Second BF16 operand: [15] sign, [14:7] exp, [6:0] frac.
 * @param obf16c  BF16 result: [15] sign, [14:7] exp, [6:0] frac.
 */
module vhfastmulb16_add_bf16_bf16_bf16_rtz_lat4 (
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
    wire res_nan  = a_nan || b_nan || (a_inf && b_inf && (a_sign != b_sign));
    wire res_inf  = !res_nan && (a_inf || b_inf);
    wire both_zero = !res_nan && !res_inf && a_zero && b_zero;
    wire op_add   = (a_sign == b_sign);   // 1: add magnitudes, 0: subtract

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
    wire sign_mag  = a_larger ? a_sign : b_sign;
    wire zero_sign = a_sign & b_sign;
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

    // Leading-zero detect over the 15-bit raw sum.  The addition carry,
    // when present, is the leading one and encodes a zero count.
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

    // exp_pre = exp_adj - lzd, 9-bit Kogge-Stone prefix borrow chain.
    wire [8:0] ep_lz = {5'd0, lzd_c};
    wire [8:0] ep_p  = ~exp_adj | ep_lz;   // borrow propagate
    wire [8:0] ep_g  = ~exp_adj & ep_lz;   // borrow generate
    wire [8:0] ep_g1 = ep_g  | (ep_p  & {ep_g[7:0],  1'b0});
    wire [8:0] ep_p1 = ep_p  & {ep_p[7:0],  1'b0};
    wire [8:0] ep_g2 = ep_g1 | (ep_p1 & {ep_g1[6:0], 2'b00});
    wire [8:0] ep_p2 = ep_p1 & {ep_p1[6:0], 2'b00};
    wire [8:0] ep_g3 = ep_g2 | (ep_p2 & {ep_g2[4:0], 4'b0000});
    wire [8:0] ep_p3 = ep_p2 & {ep_p2[4:0], 4'b0000};
    wire [8:0] ep_g4 = ep_g3 | (ep_p3 & {ep_g3[0], 8'b00000000});
    wire [8:0] exp_pre_c = (exp_adj ^ ep_lz) ^ {ep_g4[7:0], 1'b0};

    // Subnormal shift for S4: 7 - exp_pre == (7 - exp_adj) + lzd.
    // For valid BF16 inputs sub_shift is in the range 7..13; five bits
    // leave headroom for defensive cases.
    wire [4:0] sub_base    = 5'd7 - exp_adj[4:0];
    wire [4:0] sub_shift_c = sub_base + {1'b0, lzd_c};

    // ------------------------------------------------------------------
    // Stage S3 -> Stage S4 registers (capture at N+3 edge)
    // ------------------------------------------------------------------
    reg [13:0] man_norm_d1;
    reg [8:0]  exp_pre_d1;
    reg [4:0]  sub_shift_d1;
    reg        sign_res_d3;
    reg [1:0]  flags_d3;
    reg        both_zero_d3;
    reg        zero_sign_d3;
    reg        is_zero_d3;

    always @(posedge clk) begin
        if (reset) begin
            man_norm_d1  <= 14'd0;
            exp_pre_d1   <= 9'd0;
            sub_shift_d1 <= 5'd0;
            sign_res_d3  <= 1'b0;
            flags_d3     <= 2'b00;
            both_zero_d3 <= 1'b0;
            zero_sign_d3 <= 1'b0;
            is_zero_d3   <= 1'b0;
        end else if (en_pipe) begin
            man_norm_d1  <= man_norm_c;
            exp_pre_d1   <= exp_pre_c;
            sub_shift_d1 <= sub_shift_c;
            sign_res_d3  <= sign_res_d2;
            flags_d3     <= flags_d2;
            both_zero_d3 <= both_zero_d2;
            zero_sign_d3 <= zero_sign_d2;
            is_zero_d3   <= (man_raw_d1 == 15'd0) && !both_zero_d2;
        end
    end

    // ------------------------------------------------------------------
    // Stage S4: subnormal shift / RTZ truncation + BF16 pack
    //   Normal:    exp = exp_pre (1..254), frac = man_norm[12:6]
    //              (six low guard/G/R/S bits are dropped)
    //   Subnormal: frac = (man_norm >> sub_shift)[6:0], exp field = 0
    //   Overflow:  max finite 0x7F7F (sign preserved)
    // ------------------------------------------------------------------
    wire        exp_nonpos = exp_pre_d1[8] | (exp_pre_d1 == 9'd0);
    wire [13:0] man_sub    = man_norm_d1 >> sub_shift_d1;
    wire [6:0]  frac_sub   = man_sub[6:0];
    wire [6:0]  frac_norm  = man_norm_d1[12:6];
    wire [6:0]  frac_sel   = exp_nonpos ? frac_sub : frac_norm;
    wire [7:0]  exp_sel    = exp_nonpos ? 8'd0 : exp_pre_d1[7:0];
    // Negative exp_pre (bit 8 = 1) is a subnormal result, not overflow.
    wire        exp_ovf    = (!exp_pre_d1[8] && (exp_pre_d1 >= 9'd255)) ||
                             (exp_pre_d1 == 9'd256);

    reg [15:0] c_next;

    always @(*) begin
        if (flags_d3[1]) begin
            // NaN: canonical quiet NaN
            c_next = 16'h7FC0;
        end else if (flags_d3[0]) begin
            // Infinity
            c_next = {sign_res_d3, 8'hFF, 7'h00};
        end else if (exp_ovf) begin
            // RTZ overflow: maximum finite value
            c_next = {sign_res_d3, 8'hFE, 7'h7F};
        end else if (both_zero_d3) begin
            // IEEE-754: (-0)+(-0) = -0, (+0)+(-0) = +0
            c_next = {zero_sign_d3, 15'h0000};
        end else if (is_zero_d3) begin
            // Exact cancellation of non-zero operands -> +0
            c_next = 16'h0000;
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
            obf16c <= 16'h0000;
        end else if (en_pipe) begin
            obf16c <= c_next;
        end
        // else: HOLD (keep last value)
    end

endmodule
