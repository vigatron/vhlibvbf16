// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// FAST (max-Fmax) variant, RTZ rounding, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3.v
// Module: vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3
// BF16 multiplication (RTZ rounding, FTZ inputs)
// Result is BF16 number
// Operation takes 3 clk (latency 3)
// Round Toward Zero (truncation), simple discard of lower bits
// Subnormal inputs: Flush To Zero (FTZ), treated as 0
// NaN: canonical quiet NaN 0x7FC0 (payload/sign not propagated)
// ----------------------------------------------

/**
 * @brief  Max-Fmax BF16 x BF16 -> BF16 multiplier, RTZ, FTZ, latency 3.
 *
 * Speed-optimized variant of vhfastmulb16_mul_bf16_bf16_bf16_rtz_lat3:
 * a single balanced 3-stage pipeline without nested latency modules.
 *
 * Pipeline:
 *   S1: operand decode + FTZ + 8x8 mantissa multiply + exp_sum (a_exp+b_exp-127)
 *       + sign + NaN/Inf/Zero classification
 *   S2: product normalization (7-bit RTZ mantissa) + exp_n (+msb) + overflow/underflow
 *   S3: exception select + output register
 *
 * Semantics (frozen contract, see
 * rules/mul/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3.md):
 *   - FTZ on inputs: exp==0 (zero or subnormal) -> operand treated as zero;
 *   - exact 16-bit product P = M_a * M_b;
 *   - biased exponent sum S = (exp_a + exp_b - 127) mod 512;
 *   - normalization: k = P[15], man = P[14:8] if P[15] else P[13:7],
 *     exp_n = (S + k) mod 512;
 *   - RTZ: 7-bit mantissa (low bits of the product are dropped);
 *   - underflow: (S > 381) || (exp_n == 0)  -> signed zero;
 *   - overflow:  (S <= 381) && (exp_n > 254) -> signed Inf;
 *   - NaN: canonical qNaN 0x7FC0 (no sign, no payload);
 *   - sign: sign_a XOR sign_b on Inf/zero/normal (not on NaN);
 *   - priority: NaN > Inf > Zero > Underflow > Overflow > Normal.
 *
 * The 8x8 mantissa multiply is built from four combinational 4x4 multipliers
 * (vhfastmulb16_mul4x4_comb) plus a CSA tree; no '*' operator is used
 * (see rules/dsp_prohibition.md).
 *
 * @param clk   Clock signal.
 * @param reset Synchronous reset, active high, priority over en.
 * @param en    Enable: accept a new sample when 1, hold when 0.
 * @param a     First BF16 operand: [15] sign | [14:7] exp | [6:0] frac.
 * @param b     Second BF16 operand.
 * @param c     BF16 result (valid 3 clk after the sample is accepted).
 */
module vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [15:0] c
);

    // ============================================================
    // S1 combinational: decode + FTZ + multiply + exp_sum + class
    // ============================================================

    wire       a_sign = a[15];
    wire       b_sign = b[15];
    wire [7:0] a_exp  = a[14:7];
    wire [7:0] b_exp  = b[14:7];
    wire [6:0] a_frac = a[6:0];
    wire [6:0] b_frac = b[6:0];

    // Operand classification (combinational, no flag modules)
    wire a_zero = (a_exp == 8'h00);                         // FTZ: zero + subnormal
    wire b_zero = (b_exp == 8'h00);
    wire a_inf  = (a_exp == 8'hFF) && (a_frac == 7'h00);
    wire b_inf  = (b_exp == 8'hFF) && (b_frac == 7'h00);
    wire a_nan  = (a_exp == 8'hFF) && (a_frac != 7'h00);
    wire b_nan  = (b_exp == 8'hFF) && (b_frac != 7'h00);

    // FTZ mantissas: exp==0 -> 0, else hidden one
    wire [7:0] a_man = a_zero ? 8'h00 : { 1'b1, a_frac };
    wire [7:0] b_man = b_zero ? 8'h00 : { 1'b1, b_frac };

    // Exception classification (priority resolved later in S3)
    wire res_nan  = a_nan | b_nan | (a_inf & b_zero) | (b_inf & a_zero);
    wire res_inf  = ~res_nan & (a_inf | b_inf);
    wire res_zero = ~res_nan & ~res_inf & (a_zero | b_zero);

    // ---- 8x8 unsigned multiply: 4x mul4x4_comb + CSA tree ----
    wire [3:0] a_hi = a_man[7:4];
    wire [3:0] a_lo = a_man[3:0];
    wire [3:0] b_hi = b_man[7:4];
    wire [3:0] b_lo = b_man[3:0];

    wire [7:0] p_hh, p_hl, p_lh, p_ll;

    vhfastmulb16_mul4x4_comb mul_hh (
        .a(a_hi), .b(b_hi), .c(p_hh)
    );
    vhfastmulb16_mul4x4_comb mul_hl (
        .a(a_hi), .b(b_lo), .c(p_hl)
    );
    vhfastmulb16_mul4x4_comb mul_lh (
        .a(a_lo), .b(b_hi), .c(p_lh)
    );
    vhfastmulb16_mul4x4_comb mul_ll (
        .a(a_lo), .b(b_lo), .c(p_ll)
    );

    // Aligned partial products
    //   p_hh weight 256, p_hl/p_lh weight 16, p_ll weight 1
    wire [15:0] P0 = { p_hh, 8'h00 };
    wire [15:0] P1 = { 4'h0, p_hl, 4'h0 };
    wire [15:0] P2 = { 4'h0, p_lh, 4'h0 };
    wire [15:0] P3 = { 8'h00, p_ll };

    // CSA level 1: P0 + P1 + P2 -> s1 + c1
    wire [15:0] csa_g1 = (P0 & P1) | (P0 & P2) | (P1 & P2);
    wire [15:0] csa_s1 = P0 ^ P1 ^ P2;
    wire [15:0] csa_c1 = { csa_g1[14:0], 1'b0 };

    // CSA level 2: s1 + c1 + P3 -> s2 + c2
    wire [15:0] csa_g2 = (csa_s1 & csa_c1) | (csa_s1 & P3) | (csa_c1 & P3);
    wire [15:0] csa_s2 = csa_s1 ^ csa_c1 ^ P3;
    wire [15:0] csa_c2 = { csa_g2[14:0], 1'b0 };

    wire [15:0] prod16 = csa_s2 + csa_c2;

    // Biased exponent sum S = (a_exp + b_exp - 127) mod 512
    wire [8:0] exp_sum = { 1'b0, a_exp } + { 1'b0, b_exp } - 9'd127;

    wire sign_xor = a_sign ^ b_sign;

    // ============================================================
    // Valid pipeline: v_s1/v_s2 with per-stage clock enables
    //   S1 latches when en, S2 when v_s1, output when v_s2.
    //   en=0 -> accepted samples drain, then c holds (HOLD).
    // ============================================================
    reg v_s1;
    reg v_s2;

    always @(posedge clk) begin
        if (reset) begin
            v_s1 <= 1'b0;
            v_s2 <= 1'b0;
        end else begin
            v_s1 <= en;
            v_s2 <= v_s1;
        end
    end

    // ============================================================
    // S1 registers (latch when en)
    // ============================================================
    reg [15:0] s1_prod;
    reg [8:0]  s1_exp_sum;
    reg        s1_sign;
    reg        s1_nan;
    reg        s1_inf;
    reg        s1_zero;

    always @(posedge clk) begin
        if (reset) begin
            s1_prod    <= 16'h0000;
            s1_exp_sum <= 9'd0;
            s1_sign    <= 1'b0;
            s1_nan     <= 1'b0;
            s1_inf     <= 1'b0;
            s1_zero    <= 1'b0;
        end else if (en) begin
            s1_prod    <= prod16;
            s1_exp_sum <= exp_sum;
            s1_sign    <= sign_xor;
            s1_nan     <= res_nan;
            s1_inf     <= res_inf;
            s1_zero    <= res_zero;
        end
    end

    // ============================================================
    // S2 combinational: normalize product + exponent adjust + bounds
    //   Leading one is at P[15] or P[14] (P >= 0x4000 for normal inputs).
    //   7-bit RTZ mantissa = P[14:8] if P[15] else P[13:7].
    // ============================================================
    wire       prod_msb = s1_prod[15];
    wire [6:0] man_norm = prod_msb ? s1_prod[14:8] : s1_prod[13:7];
    wire [8:0] exp_n    = s1_exp_sum + (prod_msb ? 9'd1 : 9'd0);

    wire exp_underflow = (s1_exp_sum > 9'd381) || (exp_n == 9'd0);
    wire exp_overflow  = (s1_exp_sum <= 9'd381) && (exp_n > 9'd254);

    // ============================================================
    // S2 registers (latch when v_s1)
    // ============================================================
    reg [6:0]  s2_man;
    reg [8:0]  s2_exp_n;
    reg        s2_sign;
    reg        s2_nan;
    reg        s2_inf;
    reg        s2_zero;
    reg        s2_under;
    reg        s2_over;

    always @(posedge clk) begin
        if (reset) begin
            s2_man   <= 7'd0;
            s2_exp_n <= 9'd0;
            s2_sign  <= 1'b0;
            s2_nan   <= 1'b0;
            s2_inf   <= 1'b0;
            s2_zero  <= 1'b0;
            s2_under <= 1'b0;
            s2_over  <= 1'b0;
        end else if (v_s1) begin
            s2_man   <= man_norm;
            s2_exp_n <= exp_n;
            s2_sign  <= s1_sign;
            s2_nan   <= s1_nan;
            s2_inf   <= s1_inf;
            s2_zero  <= s1_zero;
            s2_under <= exp_underflow;
            s2_over  <= exp_overflow;
        end
    end

    // ============================================================
    // S3 combinational: RTZ truncation + result select
    //   priority: NaN > Inf > Zero > Underflow > Overflow > Normal
    // ============================================================
    reg [15:0] c_next;

    always @(*) begin
        if (s2_nan) begin
            c_next = 16'h7FC0;                              // canonical qNaN, no sign
        end else if (s2_inf) begin
            c_next = { s2_sign, 8'hFF, 7'h00 };             // +/-Inf
        end else if (s2_zero) begin
            c_next = { s2_sign, 15'h0000 };                 // +/-0
        end else if (s2_under) begin
            c_next = { s2_sign, 15'h0000 };                 // underflow -> +/-0
        end else if (s2_over) begin
            c_next = { s2_sign, 8'hFF, 7'h00 };             // overflow -> +/-Inf
        end else begin
            c_next = { s2_sign, s2_exp_n[7:0], s2_man };  // RTZ
        end
    end

    // ============================================================
    // Output register (latch when v_s2); reset has priority; HOLD otherwise
    // ============================================================
    always @(posedge clk) begin
        if (reset) begin
            c <= 16'h0000;
        end else if (v_s2) begin
            c <= c_next;
        end
        // else: HOLD (keep last value)
    end

endmodule