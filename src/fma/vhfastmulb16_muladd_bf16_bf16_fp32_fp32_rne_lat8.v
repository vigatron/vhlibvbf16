// ----------------------------------------------
// vhlibvbf16 - Fused Multiply-Add BF16 x BF16 + FP32 -> FP32.
// RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8.v
// Module: vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8
// RESULT = SUMM + (VALA_BF16 × VALB_BF16), FP32 output, RNE rounding
// Latency 8 clk, fully pipelined, optimized for max Fmax.
// Pipeline 8 stages (retiming S7→S8: right barrel-shift + sticky moved from S8 to S7):
//   S1: operand decode, classification, mul4x4_comb partial products,
//       exponent bases exp_p/exp_s, SUMM leading-zero count (encoder only)
//   S2: CSA-tree (2 levels) + SUMM normalization shifter
//   S3: CPA -> 16-bit mantissa product; LOD k
//   S4: product normalization p24; exp_p + k; direct |exp_p - exp_s|;
//       large/small select
//   S5: sticky-bit tree; alignment shift of small mantissa; op_add/sign
//   S6: mantissa add/sub (28-bit raw); carry fix-up; LZD precompute
//   S7: LZD normalization; exp_pre and grs_shift from two parallel
//       CARRY4 subtractors; **right barrel-shift + sticky precompute for subnormal path**
//   S8: RNE rounding (G/R/S + tie-to-even) with precomputed g_sub/s_sub;
//       subnormal shift; NaN/Inf/Zero/Normal/Subnormal select; F32 pack -> output register
// BF16 subnormal inputs are treated as finite values (no FTZ).
// NaN -> canonical quiet NaN 0x7FC00000
// en=0: HOLD (drain accepted data, keep last value)
// reset: synchronous, priority over en
// ----------------------------------------------

/**
 * @brief  Fused Multiply-Add: RESULT = SUMM + (VALA × VALB), FP32 output, RNE.
 *
 * Computes outfp32s = infp32s + (inbf16a * inbf16b) per IEEE-754 binary32
 * with default rounding mode (round-to-nearest, ties to even).
 *
 * The BF16 x BF16 product is exact (no intermediate rounding); the single
 * RNE rounding is applied only at the final FMA result.
 *
 * Internal exponent scale: value = ext27 * 2^(exp - 150), where ext27 is the
 * 27-bit extended mantissa (24-bit significand + 3 GRS bits).  This matches
 * the FP32 adder convention (biased exponent - 150 = unbiased - 23).
 *
 * Pipeline is 8 stages for maximum Fmax (retiming S7→S8):
 *   S1: operand decode, classification, mul4x4_comb partial products,
 *       exponent bases, SUMM leading-zero count (encoder only)
 *   S2: CSA-tree 2 levels + SUMM normalization shifter
 *   S3: CPA -> man_prod; LOD k
 *   S4: product normalization p24; exp_p + k; direct |exp_p - exp_s|;
 *       large/small select
 *   S5: sticky-bit tree; alignment shift; op_add / sign
 *   S6: mantissa add/sub (28-bit raw); carry fix-up; LZD precompute
 *   S7: LZD normalization; exp_pre / grs_shift (parallel CARRY4);
 *       **right barrel-shift + sticky precompute for subnormal path**
 *   S8: RNE rounding; subnormal shift with precomputed g_sub/s_sub;
 *       special-case select; F32 pack; output reg
 *
 * Every pipeline stage uses its own valid bit as a flip-flop clock enable
 * (per-stage CE): no new sample is accepted while en=0, accepted samples
 * drain through the pipeline, then outfp32s holds the last value.
 *
 * @param clk      Clock signal.
 * @param reset    Synchronous reset, active high, priority over en.
 * @param en       Enable: accept a new sample when 1, hold when 0.
 * @param inbf16a  First BF16 operand VALA: [15] sign | [14:7] exp | [6:0] frac
 * @param inbf16b  Second BF16 operand VALB: [15] sign | [14:7] exp | [6:0] frac
 * @param infp32s  Third FP32 operand SUMM: [31] sign | [30:23] exp | [22:0] frac
 * @param outfp32s FP32 result: SUMM + (VALA × VALB)
 */
module vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [15:0] inbf16a,
    input  wire [15:0] inbf16b,
    input  wire [31:0] infp32s,
    output reg  [31:0] outfp32s
);

    localparam [31:0] F32_QNAN = 32'h7FC0_0000;

    // ============================================================
    // STAGE S1: operand decode + classification + partial products
    //   Combinational during cycle N, captured at N+1 edge (CE = en)
    // ============================================================

    // ---------------------------------------------------
    // BF16 operand decomposition (VALA / VALB)
    // ---------------------------------------------------
    wire       a_sign = inbf16a[15];
    wire       b_sign = inbf16b[15];
    wire [7:0] a_exp  = inbf16a[14:7];
    wire [7:0] b_exp  = inbf16b[14:7];
    wire [6:0] a_frac = inbf16a[6:0];
    wire [6:0] b_frac = inbf16b[6:0];

    wire a_exp_z  = (a_exp == 8'h00);
    wire b_exp_z  = (b_exp == 8'h00);
    wire a_frac_z = (a_frac == 7'h00);
    wire b_frac_z = (b_frac == 7'h00);

    wire a_zero = a_exp_z && a_frac_z;
    wire b_zero = b_exp_z && b_frac_z;
    wire a_inf  = (a_exp == 8'hFF) && a_frac_z;
    wire b_inf  = (b_exp == 8'hFF) && b_frac_z;
    wire a_nan  = (a_exp == 8'hFF) && !a_frac_z;
    wire b_nan  = (b_exp == 8'hFF) && !b_frac_z;

    // ---------------------------------------------------
    // FP32 operand decomposition (SUMM)
    // ---------------------------------------------------
    wire       s_sign = infp32s[31];
    wire [7:0] s_exp  = infp32s[30:23];
    wire [22:0] s_frac = infp32s[22:0];

    wire s_exp_z  = (s_exp == 8'h00);
    wire s_frac_z = (s_frac == 23'h000000);

    wire s_zero = s_exp_z && s_frac_z;
    wire s_inf  = (s_exp == 8'hFF) && s_frac_z;
    wire s_nan  = (s_exp == 8'hFF) && !s_frac_z;

    // ---------------------------------------------------
    // Product exceptions
    // ---------------------------------------------------
    wire prod_nan  = a_nan || b_nan || (a_inf && b_zero) || (b_inf && a_zero);
    wire prod_inf  = !prod_nan && (a_inf || b_inf);
    wire prod_zero = !prod_nan && !prod_inf && (a_zero || b_zero);

    // ---------------------------------------------------
    // FMA exception classification (priority: NaN > Inf > Zero)
    // ---------------------------------------------------
    wire prod_sign = a_sign ^ b_sign;

    wire res_nan  = s_nan || prod_nan || (prod_inf && s_inf && (prod_sign != s_sign));
    wire res_inf  = !res_nan && (prod_inf || s_inf);
    wire res_zero = !res_nan && !res_inf && (prod_zero && s_zero);

    // NaN result: canonical quiet NaN (no payload preservation for speed)

    // ---------------------------------------------------
    // Effective BF16 exponent and mantissa (no FTZ)
    // exp_eff = exp | exp_z  (exp==0 -> 1 для субнормала, иначе exp без изменений)
    // man     = {~exp_z, frac} (скрытый бит = 0 для субнормала, 1 для нормала)
    // ---------------------------------------------------
    wire [7:0] a_exp_eff = a_exp | {7'd0, a_exp_z};
    wire [7:0] b_exp_eff = b_exp | {7'd0, b_exp_z};
    wire [7:0] a_man     = {~a_exp_z, a_frac};
    wire [7:0] b_man     = {~b_exp_z, b_frac};

    // Raw exponent sum S = a_exp_eff + b_exp_eff (9-bit, 2..508)
    wire [8:0] exp_sum_raw = {1'b0, a_exp_eff} + {1'b0, b_exp_eff};

    // ---------------------------------------------------
    // Effective FP32 exponent and mantissa (no FTZ)
    // ---------------------------------------------------
    wire [7:0] s_exp_eff = s_exp | {7'd0, s_exp_z};
    wire [23:0] s_man    = {~s_exp_z, s_frac};

    // Leading-zero count of the SUMM significand (encoder only in S1;
    // the normalization shift itself is placed in S2 to balance the stages).
    function [4:0] clz24;
        input [23:0] v;
        begin
            if      (v[23]) clz24 = 5'd0;
            else if (v[22]) clz24 = 5'd1;
            else if (v[21]) clz24 = 5'd2;
            else if (v[20]) clz24 = 5'd3;
            else if (v[19]) clz24 = 5'd4;
            else if (v[18]) clz24 = 5'd5;
            else if (v[17]) clz24 = 5'd6;
            else if (v[16]) clz24 = 5'd7;
            else if (v[15]) clz24 = 5'd8;
            else if (v[14]) clz24 = 5'd9;
            else if (v[13]) clz24 = 5'd10;
            else if (v[12]) clz24 = 5'd11;
            else if (v[11]) clz24 = 5'd12;
            else if (v[10]) clz24 = 5'd13;
            else if (v[9])  clz24 = 5'd14;
            else if (v[8])  clz24 = 5'd15;
            else if (v[7])  clz24 = 5'd16;
            else if (v[6])  clz24 = 5'd17;
            else if (v[5])  clz24 = 5'd18;
            else if (v[4])  clz24 = 5'd19;
            else if (v[3])  clz24 = 5'd20;
            else if (v[2])  clz24 = 5'd21;
            else if (v[1])  clz24 = 5'd22;
            else if (v[0])  clz24 = 5'd23;
            else            clz24 = 5'd24;
        end
    endfunction

    wire [4:0]  s_lz = clz24(s_man);

    // Product exponent base (k = 0): exp_p = S + k - 144 (internal scale).
    // SUMM exponent: exp_s = e_eff - 3 - s_lz (internal scale).
    wire [10:0] exp_p0 = {2'b00, exp_sum_raw} - 11'd144;
    wire [10:0] exp_s0 = {3'b000, s_exp_eff} - 11'd3 - {6'd0, s_lz};

    // ---------------------------------------------------
    // Per-stage pipeline enable (clock enable of each stage)
    // ---------------------------------------------------
    reg en_d1;
    reg en_d2;
    reg en_d3;
    reg en_d4;
    reg en_d5;
    reg en_d6;
    reg en_d7;

    always @(posedge clk) begin
        if (reset) begin
            en_d1 <= 1'b0;
            en_d2 <= 1'b0;
            en_d3 <= 1'b0;
            en_d4 <= 1'b0;
            en_d5 <= 1'b0;
            en_d6 <= 1'b0;
            en_d7 <= 1'b0;
        end else begin
            en_d1 <= en;
            en_d2 <= en_d1;
            en_d3 <= en_d2;
            en_d4 <= en_d3;
            en_d5 <= en_d4;
            en_d6 <= en_d5;
            en_d7 <= en_d6;
        end
    end

    // Kept for testbench visibility (not used by the datapath).
    wire en_pipe = en | en_d1 | en_d2 | en_d3 | en_d4 | en_d5 | en_d6 | en_d7;

    // ---------------------------------------------------
    // Combinational partial products (during cycle N)
    // ---------------------------------------------------
    wire [3:0] a_high = a_man[7:4];
    wire [3:0] b_high = b_man[7:4];
    wire [3:0] a_low  = a_man[3:0];
    wire [3:0] b_low  = b_man[3:0];

    wire [7:0] p_hh_calc, p_hl_calc, p_lh_calc, p_ll_calc;

    vhfastmulb16_mul4x4_comb pp_hh (
        .a(a_high),
        .b(b_high),
        .c(p_hh_calc)
    );

    vhfastmulb16_mul4x4_comb pp_hl (
        .a(a_high),
        .b(b_low),
        .c(p_hl_calc)
    );

    vhfastmulb16_mul4x4_comb pp_lh (
        .a(a_low),
        .b(b_high),
        .c(p_lh_calc)
    );

    vhfastmulb16_mul4x4_comb pp_ll (
        .a(a_low),
        .b(b_low),
        .c(p_ll_calc)
    );

    // ============================================================
    // STAGE S1 registers (capture at N+1 edge, CE = en)
    // ============================================================
    reg [7:0] p_hh_d1;
    reg [7:0] p_hl_d1;
    reg [7:0] p_lh_d1;
    reg [7:0] p_ll_d1;
    reg [10:0] exp_p_d1;
    reg [10:0] exp_s_d1;
    reg [23:0] s_man_d1;
    reg [4:0]  s_lz_d1;
    reg        prod_sign_d1;
    reg        s_sign_d1;
    reg        prod_zero_d1;
    reg        s_zero_d1;
    reg        s_inf_d1;
    reg [2:0]  flags_d1;        // {res_nan, res_inf, res_zero}

    always @(posedge clk) begin
        if (reset) begin
            p_hh_d1     <= 8'd0;
            p_hl_d1     <= 8'd0;
            p_lh_d1     <= 8'd0;
            p_ll_d1     <= 8'd0;
            exp_p_d1    <= 11'd0;
            exp_s_d1    <= 11'd0;
            s_man_d1    <= 24'd0;
            s_lz_d1     <= 5'd0;
            prod_sign_d1 <= 1'b0;
            s_sign_d1    <= 1'b0;
            prod_zero_d1 <= 1'b0;
            s_zero_d1    <= 1'b0;
            s_inf_d1      <= 1'b0;
            flags_d1     <= 3'b000;
        end else if (en) begin
            p_hh_d1     <= p_hh_calc;
            p_hl_d1     <= p_hl_calc;
            p_lh_d1     <= p_lh_calc;
            p_ll_d1     <= p_ll_calc;
            exp_p_d1    <= exp_p0;
            exp_s_d1    <= exp_s0;
            s_man_d1    <= s_man;
            s_lz_d1     <= s_lz;
            prod_sign_d1 <= prod_sign;
            s_sign_d1    <= s_sign;
            prod_zero_d1 <= prod_zero;
            s_zero_d1    <= s_zero;
            s_inf_d1      <= s_inf;
            flags_d1     <= {res_nan, res_inf, res_zero};
        end
    end

    // ============================================================
    // STAGE S2: CSA-tree 2 levels + SUMM normalization shift
    //   Combinational during cycle N+1, captured at N+2 edge (CE = en_d1)
    // ============================================================

    // 16-bit mantissa product from partial products
    wire [15:0] P0 = {8'h00, p_hh_d1} << 8;
    wire [15:0] P1 = {8'h00, p_hl_d1} << 4;
    wire [15:0] P2 = {8'h00, p_lh_d1} << 4;
    wire [15:0] P3 = {8'h00, p_ll_d1};

    wire [15:0] g1 = (P0 & P1) | (P0 & P2) | (P1 & P2);
    wire [15:0] s1 = P0 ^ P1 ^ P2;
    wire [15:0] c1 = {g1[14:0], 1'b0};

    wire [15:0] g2 = (s1 & c1) | (s1 & P3) | (c1 & P3);
    wire [15:0] s2 = s1 ^ c1 ^ P3;
    wire [15:0] c2 = {g2[14:0], 1'b0};

    // SUMM significand normalization (fast path is a plain bypass when
    // the exponent is non-zero and s_lz = 0).
    wire [23:0] s_man_n = s_man_d1 << s_lz_d1;

    // ============================================================
    // STAGE S2 registers (capture at N+2 edge, CE = en_d1)
    // ============================================================
    reg [15:0] s2_d2;
    reg [15:0] c2_d2;
    reg [10:0] exp_p_d2;
    reg [10:0] exp_s_d2;
    reg [23:0] s_man_d2;
    reg        prod_sign_d2;
    reg        s_sign_d2;
    reg        prod_zero_d2;
    reg        s_zero_d2;
    reg        s_inf_d2;
    reg [2:0]  flags_d2;

    always @(posedge clk) begin
        if (reset) begin
            s2_d2      <= 16'd0;
            c2_d2      <= 16'd0;
            exp_p_d2   <= 11'd0;
            exp_s_d2   <= 11'd0;
            s_man_d2   <= 24'd0;
            prod_sign_d2 <= 1'b0;
            s_sign_d2    <= 1'b0;
            prod_zero_d2 <= 1'b0;
            s_zero_d2    <= 1'b0;
            s_inf_d2     <= 1'b0;
            flags_d2     <= 3'b000;
        end else if (en_d1) begin
            s2_d2      <= s2;
            c2_d2      <= c2;
            exp_p_d2   <= exp_p_d1;
            exp_s_d2   <= exp_s_d1;
            s_man_d2   <= s_man_n;
            prod_sign_d2 <= prod_sign_d1;
            s_sign_d2    <= s_sign_d1;
            prod_zero_d2 <= prod_zero_d1;
            s_zero_d2    <= s_zero_d1;
            s_inf_d2     <= s_inf_d1;
            flags_d2     <= flags_d1;
        end
    end

    // ============================================================
    // STAGE S3: CPA -> man_prod; LOD k
    //   Combinational during cycle N+2, captured at N+3 edge (CE = en_d2)
    // ============================================================

    wire [15:0] man_prod = s2_d2 + c2_d2;

    // Product leading-one detect (k: index of highest set bit, 0..15)
    reg [3:0] k_calc;
    always @(*) begin
        casez (man_prod)
            16'b1???????????????: k_calc = 4'd15;
            16'b01??????????????: k_calc = 4'd14;
            16'b001?????????????: k_calc = 4'd13;
            16'b0001????????????: k_calc = 4'd12;
            16'b00001???????????: k_calc = 4'd11;
            16'b000001??????????: k_calc = 4'd10;
            16'b0000001?????????: k_calc = 4'd9;
            16'b00000001????????: k_calc = 4'd8;
            16'b000000001???????: k_calc = 4'd7;
            16'b0000000001??????: k_calc = 4'd6;
            16'b00000000001?????: k_calc = 4'd5;
            16'b000000000001????: k_calc = 4'd4;
            16'b0000000000001???: k_calc = 4'd3;
            16'b00000000000001??: k_calc = 4'd2;
            16'b000000000000001?: k_calc = 4'd1;
            default:             k_calc = 4'd0;
        endcase
    end

    // ============================================================
    // STAGE S3 registers (capture at N+3 edge, CE = en_d2)
    // ============================================================
    reg [15:0] man_prod_d3;
    reg [3:0]  k_d3;
    reg [10:0] exp_p_d3;
    reg [10:0] exp_s_d3;
    reg [23:0] s_man_d3;
    reg        prod_sign_d3;
    reg        s_sign_d3;
    reg        prod_zero_d3;
    reg        s_zero_d3;
    reg        s_inf_d3;
    reg [2:0]  flags_d3;

    always @(posedge clk) begin
        if (reset) begin
            man_prod_d3 <= 16'd0;
            k_d3        <= 4'd0;
            exp_p_d3    <= 11'd0;
            exp_s_d3    <= 11'd0;
            s_man_d3    <= 24'd0;
            prod_sign_d3 <= 1'b0;
            s_sign_d3    <= 1'b0;
            prod_zero_d3 <= 1'b0;
            s_zero_d3    <= 1'b0;
            s_inf_d3     <= 1'b0;
            flags_d3     <= 3'b000;
        end else if (en_d2) begin
            man_prod_d3 <= man_prod;
            k_d3        <= k_calc;
            exp_p_d3    <= exp_p_d2;
            exp_s_d3    <= exp_s_d2;
            s_man_d3    <= s_man_d2;
            prod_sign_d3 <= prod_sign_d2;
            s_sign_d3    <= s_sign_d2;
            prod_zero_d3 <= prod_zero_d2;
            s_zero_d3    <= s_zero_d2;
            s_inf_d3     <= s_inf_d2;
            flags_d3     <= flags_d2;
        end
    end

    // ============================================================
    // STAGE S4: product normalization; direct exponent difference;
    //           large/small select
    //   Combinational during cycle N+3, captured at N+4 edge (CE = en_d3)
    // ============================================================

    // Normalize product to 24-bit significand P24 (leading bit at position 23)
    // P_norm = man_prod << (15 - k)  -> leading bit at position 15
    // P24 = {P_norm, 8'h00}          -> leading bit at position 23
    wire [15:0] p_norm = man_prod_d3 << (4'd15 - k_d3);
    wire [23:0] p24 = {p_norm, 8'h00};

    // Product exponent in internal scale: exp_p = S + k - 144
    wire [10:0] exp_p_calc = exp_p_d3 + {7'd0, k_d3};

    // Zero-operand handling for comparison: zero mantissa -> very negative exponent
    wire prod_man_zero = prod_zero_d3;   // prod_zero
    wire s_man_zero    = s_zero_d3;      // s_zero

    // Sign-extend to 11-bit for signed comparison
    wire [10:0] exp_p_eff = prod_man_zero ? 11'b10000000000 : exp_p_calc; // -512 if zero
    wire [10:0] exp_s_eff = s_man_zero    ? 11'b10000000000 : exp_s_d3;   // -512 if zero

    // Direct signed exponent difference (sign-extended to 12 bits).
    // large/small selection and the alignment shift both derive from this
    // difference, so no multiplexer sits on the shift-amount path.
    wire [11:0] exp_diff = {exp_p_eff[10], exp_p_eff} -
                           {exp_s_eff[10], exp_s_eff};
    wire        exp_diff_neg = exp_diff[11];
    wire [11:0] shift_abs    = exp_diff_neg ? (~exp_diff + 12'd1) : exp_diff;
    wire [4:0]  shift_amt    = shift_abs[4:0];
    wire        shift_ge32   = |shift_abs[11:5];

    wire exp_p_eq_exp_s = (exp_diff == 12'd0);

    // When exponents equal, compare mantissas (P24 vs s_man_d3)
    wire p24_ge_sman = (p24 >= s_man_d3);

    // Large/small selection
    wire large_is_prod = !exp_diff_neg && (!exp_p_eq_exp_s || p24_ge_sman);

    wire [23:0] large_man = large_is_prod ? p24 : s_man_d3;
    wire [23:0] small_man = large_is_prod ? s_man_d3 : p24;

    wire [10:0] large_exp = exp_diff_neg ? exp_s_eff : exp_p_eff;

    wire        large_sign = large_is_prod ? prod_sign_d3 : s_sign_d3;
    wire        small_sign = large_is_prod ? s_sign_d3 : prod_sign_d3;

    // 27-bit extended mantissas: 24-bit significand + 3 low bits (G/R/S)
    wire [26:0] large_ext = {large_man, 3'b000};
    wire [26:0] small_ext = {small_man, 3'b000};

    // op_add: 1 = add magnitudes (signs equal), 0 = subtract
    wire op_add = (large_sign == small_sign);

    // Result sign (non-special cases)
    wire sign_res_c = large_sign;

    // ============================================================
    // STAGE S4 registers (capture at N+4 edge, CE = en_d3)
    // ============================================================
    reg [26:0] large_ext_d4;
    reg [26:0] small_ext_d4;
    reg [10:0] large_exp_d4;
    reg [4:0]  shift_amt_d4;
    reg        shift_ge32_d4;
    reg        op_add_d4;
    reg        sign_res_d4;
    reg [2:0]  flags_d4;
    reg        s_inf_d4;
    reg        prod_sign_d4;
    reg        s_sign_d4;

    always @(posedge clk) begin
        if (reset) begin
            large_ext_d4  <= 27'd0;
            small_ext_d4  <= 27'd0;
            large_exp_d4  <= 11'd0;
            shift_amt_d4  <= 5'd0;
            shift_ge32_d4 <= 1'b0;
            op_add_d4     <= 1'b0;
            sign_res_d4   <= 1'b0;
            flags_d4      <= 3'b000;
            s_inf_d4      <= 1'b0;
            prod_sign_d4  <= 1'b0;
            s_sign_d4     <= 1'b0;
        end else if (en_d3) begin
            large_ext_d4  <= large_ext;
            small_ext_d4  <= small_ext;
            large_exp_d4  <= large_exp;
            shift_amt_d4  <= shift_amt;
            shift_ge32_d4 <= shift_ge32;
            op_add_d4     <= op_add;
            sign_res_d4   <= sign_res_c;
            flags_d4      <= flags_d3;
            s_inf_d4      <= s_inf_d3;
            prod_sign_d4  <= prod_sign_d3;
            s_sign_d4     <= s_sign_d3;
        end
    end

    // ============================================================
    // STAGE S5: sticky-bit tree; alignment shift of small mantissa
    //   Combinational during cycle N+4, captured at N+5 edge (CE = en_d4)
    // ============================================================

    // Sticky-inclusive right shift (same technique as FP32 adder)
    wire [26:0] sp1 = small_ext_d4 | (small_ext_d4 << 1);
    wire [26:0] sp2 = sp1 | (sp1 << 2);
    wire [26:0] sp3 = sp2 | (sp2 << 4);
    wire [26:0] sp4 = sp3 | (sp3 << 8);
    wire [26:0] sp5 = sp4 | (sp4 << 16);
    wire [31:0] spv = {{5{sp5[26]}}, sp5};
    wire [31:0] spv2 = {spv[30:0], 1'b0};

    wire [26:0] small_sh = (small_ext_d4 >> shift_amt_d4) | {26'd0, spv2[shift_amt_d4]};
    wire [26:0] small_al = shift_ge32_d4 ? {26'd0, |small_ext_d4} : small_sh;

    // ============================================================
    // STAGE S5 registers (capture at N+5 edge, CE = en_d4)
    // ============================================================
    reg [26:0] man_hi_al_d5;
    reg [26:0] man_lo_al_d5;
    reg [10:0] exp_large_d5;
    reg        sign_res_d5;
    reg        op_add_d5;
    reg [2:0]  flags_d5;
    reg        s_inf_d5;
    reg        prod_sign_d5;
    reg        s_sign_d5;

    always @(posedge clk) begin
        if (reset) begin
            man_hi_al_d5 <= 27'd0;
            man_lo_al_d5 <= 27'd0;
            exp_large_d5 <= 11'd0;
            sign_res_d5  <= 1'b0;
            op_add_d5    <= 1'b0;
            flags_d5     <= 3'b000;
            s_inf_d5     <= 1'b0;
            prod_sign_d5 <= 1'b0;
            s_sign_d5    <= 1'b0;
        end else if (en_d4) begin
            man_hi_al_d5 <= large_ext_d4;
            man_lo_al_d5 <= small_al;
            exp_large_d5 <= large_exp_d4;
            sign_res_d5  <= sign_res_d4;
            op_add_d5    <= op_add_d4;
            flags_d5     <= flags_d4;
            s_inf_d5     <= s_inf_d4;
            prod_sign_d5 <= prod_sign_d4;
            s_sign_d5    <= s_sign_d4;
        end
    end

    // ============================================================
    // STAGE S6: mantissa add/sub + carry fix-up + LZD precompute
    //   Combinational during cycle N+5, captured at N+6 edge (CE = en_d5)
    // ============================================================

    wire [27:0] man_raw_c = op_add_d5 ?
                            ({1'b0, man_hi_al_d5} + {1'b0, man_lo_al_d5}) :
                            ({1'b0, man_hi_al_d5} - {1'b0, man_lo_al_d5});

    // Carry fix-up and normalization (same technique as FP32 adder)
    wire        man_carry = man_raw_c[27];
    wire [26:0] man_norm0 = man_carry ?
                            ({1'b0, man_raw_c[27:1]} | {26'd0, man_raw_c[0]}) :
                            man_raw_c[26:0];
    wire [10:0] exp_adj   = exp_large_d5 + {9'd0, man_carry};

    // Leading-zero detect over 28-bit raw result
    wire [27:0] lz1   = man_raw_c | (man_raw_c >> 1);
    wire [27:0] lz2   = lz1 | (lz1 >> 2);
    wire [27:0] lz4   = lz2 | (lz2 >> 4);
    wire [27:0] lz8   = lz4 | (lz4 >> 8);
    wire [27:0] lz16  = lz8 | (lz8 >> 16);
    wire [27:0] lz_oh = lz16 & ~{1'b0, lz16[27:1]};

    wire [4:0] lzd_c;
    assign lzd_c[0] = |(lz_oh & 28'b0010101010101010101010101010);
    assign lzd_c[1] = |(lz_oh & 28'b0001100110011001100110011001);
    assign lzd_c[2] = |(lz_oh & 28'b0000011110000111100001111000);
    assign lzd_c[3] = |(lz_oh & 28'b0000000001111111100000000111);
    assign lzd_c[4] = |(lz_oh & 28'b0000000000000000011111111111);

    // Exact cancellation detection (result zero but not both inputs zero).
    // flags_d5 is aligned with man_raw_c.
    wire is_zero_c = (man_raw_c == 28'd0) && !flags_d5[0];

    // ============================================================
    // STAGE S6 registers (capture at N+6 edge, CE = en_d5)
    // ============================================================
    reg [26:0] man_norm0_d6;
    reg [10:0] exp_adj_d6;
    reg [4:0]  lzd_d6;
    reg        is_zero_d6;
    reg        sign_res_d6;
    reg [2:0]  flags_d6;
    reg        s_inf_d6;
    reg        prod_sign_d6;
    reg        s_sign_d6;

    always @(posedge clk) begin
        if (reset) begin
            man_norm0_d6 <= 27'd0;
            exp_adj_d6   <= 11'd0;
            lzd_d6       <= 5'd0;
            is_zero_d6   <= 1'b0;
            sign_res_d6  <= 1'b0;
            flags_d6     <= 3'b000;
            s_inf_d6     <= 1'b0;
            prod_sign_d6 <= 1'b0;
            s_sign_d6    <= 1'b0;
        end else if (en_d5) begin
            man_norm0_d6 <= man_norm0;
            exp_adj_d6   <= exp_adj;
            lzd_d6       <= lzd_c;
            is_zero_d6   <= is_zero_c;
            sign_res_d6  <= sign_res_d5;
            flags_d6     <= flags_d5;
            s_inf_d6     <= s_inf_d5;
            prod_sign_d6 <= prod_sign_d5;
            s_sign_d6    <= s_sign_d5;
        end
    end

    // ============================================================
    // STAGE S7: LZD normalization; exp_pre and grs_shift in parallel
    //   Combinational during cycle N+6, captured at N+7 edge (CE = en_d6)
    // ============================================================

    wire [26:0] man_norm_c = man_norm0_d6 << lzd_d6;

    // exp_pre     = exp_adj - lzd (11-bit signed, internal scale)
    // grs_shift   = -exp_pre = lzd - exp_adj
    // Both are computed by independent CARRY4 subtractors (no serial
    // negate stage).
    wire [10:0] exp_pre_c = exp_adj_d6 - {6'd0, lzd_d6};
    wire [10:0] grs_neg_c = {6'd0, lzd_d6} - exp_adj_d6;

    wire [4:0] grs_shift_c = grs_neg_c[4:0];
    wire       grs_shift_ovf_c = |grs_neg_c[10:5];  // true shift > 31 -> result 0

    // Precompute subnormal path in S7 (retiming from S8):
    // right barrel-shift + sticky, so S8 only does RNE + pack.
    wire [26:0] man_grs_c   = man_norm_c >> grs_shift_c;
    wire        g_sub_c     = man_grs_c[0];
    wire [26:0] sub_mask_c  = (27'd1 << grs_shift_c) - 27'd1;
    wire        s_sub_c     = |(man_norm_c & sub_mask_c);

    // ============================================================
    // STAGE S7 registers (capture at N+7 edge, CE = en_d6)
    // ============================================================
    reg [26:0] man_norm_d7;
    reg [10:0] exp_pre_d7;
    reg [4:0]  grs_shift_d7;
    reg        grs_shift_ovf_d7;
    reg [26:0] man_grs_d7;
    reg        g_sub_d7;
    reg        s_sub_d7;
    reg        is_zero_d7;
    reg        sign_res_d7;
    reg [2:0]  flags_d7;
    reg        s_inf_d7;
    reg        prod_sign_d7;
    reg        s_sign_d7;

    always @(posedge clk) begin
        if (reset) begin
            man_norm_d7       <= 27'd0;
            exp_pre_d7        <= 11'd0;
            grs_shift_d7      <= 5'd0;
            grs_shift_ovf_d7  <= 1'b0;
            man_grs_d7        <= 27'd0;
            g_sub_d7          <= 1'b0;
            s_sub_d7          <= 1'b0;
            is_zero_d7        <= 1'b0;
            sign_res_d7       <= 1'b0;
            flags_d7          <= 3'b000;
            s_inf_d7          <= 1'b0;
            prod_sign_d7      <= 1'b0;
            s_sign_d7         <= 1'b0;
        end else if (en_d6) begin
            man_norm_d7       <= man_norm_c;
            exp_pre_d7        <= exp_pre_c;
            grs_shift_d7      <= grs_shift_c;
            grs_shift_ovf_d7  <= grs_shift_ovf_c;
            man_grs_d7        <= man_grs_c;
            g_sub_d7          <= g_sub_c;
            s_sub_d7          <= s_sub_c;
            is_zero_d7        <= is_zero_d6;
            sign_res_d7       <= sign_res_d6;
            flags_d7          <= flags_d6;
            s_inf_d7          <= s_inf_d6;
            prod_sign_d7      <= prod_sign_d6;
            s_sign_d7         <= s_sign_d6;
        end
    end

    // ============================================================
    // STAGE S8: RNE rounding + F32 pack -> output register
    //   Combinational during cycle N+7, captured at N+8 edge (CE = en_d7)
    // ============================================================

    // Normal path: kept = man_norm[26:3] (24-bit significand)
    wire [23:0] kept     = man_norm_d7[26:3];
    wire        g_norm   = man_norm_d7[2];
    wire        r_norm   = man_norm_d7[1];
    wire        s_norm   = man_norm_d7[0];
    wire        rup_norm = g_norm && (r_norm | s_norm | kept[0]);

    wire [24:0] kept_inc = {1'b0, kept} + {24'd0, rup_norm};
    wire        ovf_norm = kept_inc[24];
    wire [23:0] kept_r   = ovf_norm ? 24'h800000 : kept_inc[23:0];

    // Subnormal path: use precomputed values from S7
    wire [26:0] man_grs   = man_grs_d7;
    wire        g_sub     = g_sub_d7;
    wire        s_sub     = s_sub_d7;
    wire [22:0] frac_raw  = man_grs[23:1];
    wire        rup_sub   = g_sub && (s_sub | frac_raw[0]);

    wire [23:0] frac_inc = {1'b0, frac_raw} + {23'd0, rup_sub};
    // True shift > 31: the value is far below 0.5 ulp, so round to signed zero.
    wire        ovf_sub  = grs_shift_ovf_d7 ? 1'b0 : frac_inc[23];
    wire [22:0] frac_sub = grs_shift_ovf_d7 ? 23'd0 : frac_inc[22:0];

    // FP32 biased exponent: E = exp_pre + 3 (internal scale -> FP32 biased)
    wire [10:0] exp_f32_biased = exp_pre_d7 + 11'd3;

    // Subnormal output: E <= 0  (biased exponent 0 or negative)
    wire sub_out    = exp_f32_biased[10] | (exp_f32_biased == 11'd0);
    wire [8:0]  exp_plus1  = exp_f32_biased[7:0] + 8'd1;
    // exp_f32_biased положителен, когда sub_out = 0, поэтому беззнаковое
    // сравнение корректно для проверки диапазона [255, ...)
    wire        exp_ge255  = !exp_f32_biased[10] && (exp_f32_biased[9:0] >= 10'd255);
    wire        exp_eq254  = !exp_f32_biased[10] && (exp_f32_biased[9:0] == 10'd254);
    wire        exp_ovf    = !sub_out && (exp_ge255 | (exp_eq254 & ovf_norm));
    wire [7:0]  exp_final  = sub_out ? (ovf_sub ? 8'd1 : 8'd0)
                                    : (ovf_norm ? exp_plus1[7:0] : exp_f32_biased[7:0]);
    wire [22:0] frac_final = sub_out ? (ovf_sub ? 23'd0 : frac_sub)
                                    : kept_r[22:0];

    // Output selection: NaN > Inf/overflow > zero > normal/subnormal
    wire [31:0] v_nan  = {1'b0, 8'hFF, 23'h400000};
    // Inf sign comes from the infinite operand (product or SUMM), not from
    // the larger aligned operand (which may be finite).
    wire [31:0] v_inf  = {(s_inf_d7 ? s_sign_d7 : prod_sign_d7), 8'hFF, 23'h000000};
    // Знак нуля: при точном вычитании (x + (-x) = +0) результат +0.
    // Если оба операнда нули — знак = sign_a & sign_b (IEEE: -0 + +0 = +0, -0 + -0 = -0).
    wire both_zero = flags_d7[0] && !is_zero_d7;  // both operands zero, not exact cancellation
    wire zero_sign = both_zero ? (prod_sign_d7 & s_sign_d7) : (is_zero_d7 ? 1'b0 : (flags_d7[0] & sign_res_d7));
    wire [31:0] v_zero = {zero_sign, 31'h00000000};
    wire [31:0] v_norm = {sign_res_d7, exp_final, frac_final};

    // Additional zero detection: if normalized mantissa is exactly zero,
    // force result to zero regardless of pipeline flag alignment.
    wire man_norm_zero = (man_norm_d7 == 27'd0);
    wire zero_detected = is_zero_d7 | flags_d7[0] | man_norm_zero;

    // No product-overflow hack: a finite product that exceeds the FP32 range
    // is still an exact intermediate in a fused FMA.  Only an actual Inf
    // operand participates in the Inf/NaN classification; final overflow is
    // handled by exp_ovf after the addition.
    wire        kind_hi = flags_d7[2] | flags_d7[1] | exp_ovf;
    wire        kind_lo = flags_d7[2] |
                          ((zero_detected) & ~(flags_d7[1] | exp_ovf));
    wire [31:0] c_hi   = kind_lo ? v_nan : v_inf;
    wire [31:0] c_lo   = kind_lo ? v_zero : v_norm;

    reg [31:0] c_next;

    always @(*) begin
        c_next = kind_hi ? c_hi : c_lo;
    end

    // Output register (cycle N+8), CE = en_d7.
    // reset has priority over en; en=0 holds the last value (HOLD).
    always @(posedge clk) begin
        if (reset) begin
            outfp32s <= 32'h0000_0000;
        end else if (en_d7) begin
            outfp32s <= c_next;
        end
        // else: HOLD (keep last value)
    end

endmodule
