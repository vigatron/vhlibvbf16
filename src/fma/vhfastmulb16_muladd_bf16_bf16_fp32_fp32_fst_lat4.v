// ----------------------------------------------
// vhlibvbf16 - Fused Multiply-Add BF16 x BF16 + FP32 -> FP32.
// FAST (max-Fmax) variant, RTZ rounding, FTZ inputs/output, no DSP.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4.v
// Module: vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4
// RESULT = SUMM + (VALA_BF16 x VALB_BF16), FP32 output, RTZ rounding.
// Latency 4 clk, fully pipelined.
//
// Same arithmetic contract as vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8
// (RTZ/FTZ), but the datapath is balanced over 4 stages:
//   S1: operand decode + FTZ + classification + mul4x4_comb partial
//       products + exponent bases exp_p0/exp_s0
//   S2: CSA tree (2 levels) + CPA -> 16-bit product; 1-bit normalization
//       (P[15]); exp_p/exp_s; direct exp_p - exp_s; large/small select;
//       alignment shift of the smaller mantissa (no sticky)
//   S3: mantissa add/sub (28-bit) + carry fix-up + full LZD (lz1..lz16) +
//       normalization + exp_f32
//   S4: RTZ pack + NaN/Inf/Zero select -> output register
//
// FTZ: BF16 exp==0 and FP32 exp==0 are treated as zero.
// RTZ: no G/R/S, no tie-to-even; low bits are discarded.
// NaN -> canonical quiet NaN 0x7FC00000.
// Overflow -> +/-Inf.
// Every zero result -> +0 (sign is not preserved).
// en=0: HOLD (drain accepted data, keep last value)
// reset: synchronous, priority over en
// ----------------------------------------------

/**
 * @brief  Fused Multiply-Add FAST: RESULT = SUMM + (VALA_BF16 x VALB_BF16),
 *         FP32 output, RTZ, FTZ, latency 4.
 *
 * Bit-exact with vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8: the same
 * frozen RTZ/FTZ contract, only the pipeline is rebalanced into 4 stages.
 *
 * Computes outfp32s = infp32s + (inbf16a x inbf16b) with round-to-zero
 * (truncation) and flush-to-zero on BF16/FP32 subnormals. No F32 subnormal
 * results are produced. NaN -> canonical 0x7FC00000; overflow -> +/-Inf;
 * every zero result -> +0.
 *
 * The BF16 x BF16 product is exact; the single final RTZ rounding is
 * applied only at the FMA result.
 *
 * @param clk      Clock signal.
 * @param reset    Synchronous reset, active high, priority over en.
 * @param en       Enable: accept a new sample when 1, hold when 0.
 * @param inbf16a  First BF16 operand VALA: [15] sign | [14:7] exp | [6:0] frac
 * @param inbf16b  Second BF16 operand VALB: [15] sign | [14:7] exp | [6:0] frac
 * @param infp32s  Third FP32 operand SUMM: [31] sign | [30:23] exp | [22:0] frac
 * @param outfp32s FP32 result: SUMM + (VALA x VALB)
 */
module vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat4 (
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
    // STAGE S1: operand decode + FTZ + classification + partial products
    //   Combinational during cycle N, captured at N+1 edge (CE = en)
    // ============================================================

    // BF16 operand decomposition (VALA / VALB)
    wire       a_sign = inbf16a[15];
    wire [7:0] a_exp  = inbf16a[14:7];
    wire [6:0] a_frac = inbf16a[6:0];

    wire       b_sign = inbf16b[15];
    wire [7:0] b_exp  = inbf16b[14:7];
    wire [6:0] b_frac = inbf16b[6:0];

    // FP32 operand decomposition (SUMM)
    wire       s_sign = infp32s[31];
    wire [7:0] s_exp  = infp32s[30:23];
    wire [22:0] s_frac = infp32s[22:0];

    // FTZ classification: exp==0 includes zero and subnormal.
    wire a_zero = (a_exp == 8'h00);
    wire b_zero = (b_exp == 8'h00);
    wire s_zero = (s_exp == 8'h00);

    wire a_inf  = (a_exp == 8'hFF) && (a_frac == 7'h00);
    wire b_inf  = (b_exp == 8'hFF) && (b_frac == 7'h00);
    wire s_inf  = (s_exp == 8'hFF) && (s_frac == 23'h000000);

    wire a_nan  = (a_exp == 8'hFF) && (a_frac != 7'h00);
    wire b_nan  = (b_exp == 8'hFF) && (b_frac != 7'h00);
    wire s_nan  = (s_exp == 8'hFF) && (s_frac != 23'h000000);

    // FTZ mantissas: exp==0 -> 0, else hidden one.
    wire [7:0]  a_man = a_zero ? 8'h00 : {1'b1, a_frac};
    wire [7:0]  b_man = b_zero ? 8'h00 : {1'b1, b_frac};
    wire [23:0] s_man = s_zero ? 24'h000000 : {1'b1, s_frac};

    // Product exceptions.
    wire prod_sign = a_sign ^ b_sign;
    wire prod_nan  = a_nan | b_nan | (a_inf & b_zero) | (b_inf & a_zero);
    wire prod_inf  = ~prod_nan & (a_inf | b_inf);
    wire prod_zero = ~prod_nan & ~prod_inf & (a_zero | b_zero);

    // FMA exception classification (priority: NaN > Inf > Zero).
    wire res_nan  = s_nan | prod_nan |
                    (prod_inf & s_inf & (prod_sign != s_sign));
    wire res_inf  = ~res_nan & (prod_inf | s_inf);
    wire res_zero = ~res_nan & ~res_inf & prod_zero & s_zero;

    // Exponent bases.
    // exp_p = a_exp + b_exp - 130 + (P[15] ? 1 : 0)  (add P[15] in S2).
    // exp_s = s_exp - 3.
    wire [8:0]  exp_sum_raw = {1'b0, a_exp} + {1'b0, b_exp};
    wire [10:0] exp_p0 = {2'b00, exp_sum_raw} - 11'd130;
    wire [10:0] exp_s0 = {3'b000, s_exp} - 11'd3;

    // Combinational partial products (during cycle N).
    wire [3:0] a_high = a_man[7:4];
    wire [3:0] a_low  = a_man[3:0];
    wire [3:0] b_high = b_man[7:4];
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

    // ---------------------------------------------------
    // Per-stage pipeline enable (clock enable of each stage)
    // ---------------------------------------------------
    reg en_d1;
    reg en_d2;
    reg en_d3;

    always @(posedge clk) begin
        if (reset) begin
            en_d1 <= 1'b0;
            en_d2 <= 1'b0;
            en_d3 <= 1'b0;
        end else begin
            en_d1 <= en;
            en_d2 <= en_d1;
            en_d3 <= en_d2;
        end
    end

    // Kept for testbench visibility (not used by the datapath).
    wire en_pipe = en | en_d1 | en_d2 | en_d3;

    // ============================================================
    // STAGE S1 registers (capture at N+1 edge, CE = en)
    // ============================================================
    reg [7:0]  p_hh_d1;
    reg [7:0]  p_hl_d1;
    reg [7:0]  p_lh_d1;
    reg [7:0]  p_ll_d1;
    reg [10:0] exp_p_d1;
    reg [10:0] exp_s_d1;
    reg [23:0] s_man_d1;
    reg        prod_sign_d1;
    reg        s_sign_d1;
    reg        prod_zero_d1;
    reg        s_zero_d1;
    reg        s_inf_d1;
    reg [2:0]  flags_d1;        // {res_nan, res_inf, res_zero}

    always @(posedge clk) begin
        if (reset) begin
            p_hh_d1      <= 8'd0;
            p_hl_d1      <= 8'd0;
            p_lh_d1      <= 8'd0;
            p_ll_d1      <= 8'd0;
            exp_p_d1     <= 11'd0;
            exp_s_d1     <= 11'd0;
            s_man_d1     <= 24'd0;
            prod_sign_d1 <= 1'b0;
            s_sign_d1    <= 1'b0;
            prod_zero_d1 <= 1'b0;
            s_zero_d1    <= 1'b0;
            s_inf_d1     <= 1'b0;
            flags_d1     <= 3'b000;
        end else if (en) begin
            p_hh_d1      <= p_hh_calc;
            p_hl_d1      <= p_hl_calc;
            p_lh_d1      <= p_lh_calc;
            p_ll_d1      <= p_ll_calc;
            exp_p_d1     <= exp_p0;
            exp_s_d1     <= exp_s0;
            s_man_d1     <= s_man;
            prod_sign_d1 <= prod_sign;
            s_sign_d1    <= s_sign;
            prod_zero_d1 <= prod_zero;
            s_zero_d1    <= s_zero;
            s_inf_d1     <= s_inf;
            flags_d1     <= {res_nan, res_inf, res_zero};
        end
    end

    // ============================================================
    // STAGE S2: CSA tree (2 levels) + CPA -> 16-bit product; 1-bit
    //           normalization; exp_p/exp_s; exp difference; large/small
    //           select; alignment shift (no sticky)
    //   Combinational during cycle N+1, captured at N+2 edge (CE = en_d1)
    // ============================================================

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

    // CPA -> 16-bit mantissa product.
    wire [15:0] man_prod = s2 + c2;
    wire        prod_msb = man_prod[15];

    // Normalize product: leading one at bit 15 if prod_msb, else at bit 14.
    wire [15:0] p_norm = prod_msb ? man_prod : {man_prod[14:0], 1'b0};
    wire [23:0] p24    = {p_norm, 8'h00};

    // exp_p = exp_p0 + P[15].
    wire [10:0] exp_p_calc = exp_p_d1 + {10'd0, prod_msb};

    // Zero-operand handling: zero mantissa -> very negative exponent.
    wire [10:0] exp_p_eff = prod_zero_d1 ? 11'h400 : exp_p_calc;  // -1024
    wire [10:0] exp_s_eff = s_zero_d1    ? 11'h400 : exp_s_d1;    // -1024

    // Direct signed exponent difference (12-bit sign-extended).
    wire [11:0] exp_diff     = {exp_p_eff[10], exp_p_eff} -
                               {exp_s_eff[10], exp_s_eff};
    wire        exp_diff_neg = exp_diff[11];
    wire [11:0] shift_abs    = exp_diff_neg ? (~exp_diff + 12'd1) : exp_diff;
    wire [4:0]  shift_amt    = shift_abs[4:0];
    wire        shift_ge32   = |shift_abs[11:5];

    wire exp_p_eq_exp_s = (exp_diff == 12'd0);

    // Deferred mantissa compare: only when exponents are equal.
    wire p24_ge_sman = exp_p_eq_exp_s ? (p24 >= s_man_d1) : 1'b0;

    // Large/small selection.
    wire large_is_prod = !exp_diff_neg && (!exp_p_eq_exp_s || p24_ge_sman);

    wire [23:0] large_man = large_is_prod ? p24 : s_man_d1;
    wire [23:0] small_man = large_is_prod ? s_man_d1 : p24;

    wire [10:0] large_exp = exp_diff_neg ? exp_s_eff : exp_p_eff;

    wire large_sign = large_is_prod ? prod_sign_d1 : s_sign_d1;
    wire small_sign = large_is_prod ? s_sign_d1 : prod_sign_d1;

    // 27-bit extended mantissas: 24-bit significand + 3 low bits.
    wire [26:0] large_ext = {large_man, 3'b000};
    wire [26:0] small_ext = {small_man, 3'b000};

    wire op_add     = (large_sign == small_sign);
    wire sign_res_c = large_sign;

    // Alignment shift without sticky: shifted-out bits are discarded.
    wire [26:0] small_sh = small_ext >> shift_amt;
    wire [26:0] small_al = shift_ge32 ? 27'd0 : small_sh;

    // ============================================================
    // STAGE S2 registers (capture at N+2 edge, CE = en_d1)
    // ============================================================
    reg [26:0] large_ext_d2;
    reg [26:0] small_ext_d2;
    reg [10:0] large_exp_d2;
    reg        op_add_d2;
    reg        sign_res_d2;
    reg [2:0]  flags_d2;
    reg        s_inf_d2;
    reg        prod_sign_d2;
    reg        s_sign_d2;

    always @(posedge clk) begin
        if (reset) begin
            large_ext_d2  <= 27'd0;
            small_ext_d2  <= 27'd0;
            large_exp_d2  <= 11'd0;
            op_add_d2     <= 1'b0;
            sign_res_d2   <= 1'b0;
            flags_d2      <= 3'b000;
            s_inf_d2      <= 1'b0;
            prod_sign_d2  <= 1'b0;
            s_sign_d2     <= 1'b0;
        end else if (en_d1) begin
            large_ext_d2  <= large_ext;
            small_ext_d2  <= small_al;
            large_exp_d2  <= large_exp;
            op_add_d2     <= op_add;
            sign_res_d2   <= sign_res_c;
            flags_d2      <= flags_d1;
            s_inf_d2      <= s_inf_d1;
            prod_sign_d2  <= prod_sign_d1;
            s_sign_d2     <= s_sign_d1;
        end
    end

    // ============================================================
    // STAGE S3: mantissa add/sub (28-bit) + carry fix-up + full LZD +
    //           normalization + exp_f32
    //   Combinational during cycle N+2, captured at N+3 edge (CE = en_d2)
    // ============================================================

    wire [27:0] man_raw_c = op_add_d2 ?
                            ({1'b0, large_ext_d2} + {1'b0, small_ext_d2}) :
                            ({1'b0, large_ext_d2} - {1'b0, small_ext_d2});

    // Carry fix-up (FAST: no OR of the discarded bit 0).
    wire        man_carry = man_raw_c[27];
    wire [26:0] man_norm0 = man_carry ? man_raw_c[27:1] : man_raw_c[26:0];
    wire [10:0] exp_adj   = large_exp_d2 + {10'd0, man_carry};

    // Leading-zero detect over the 28-bit raw result.
    wire [27:0] lz1   = man_raw_c | (man_raw_c >> 1);
    wire [27:0] lz2   = lz1 | (lz1 >> 2);
    wire [27:0] lz4   = lz2 | (lz2 >> 4);
    wire [27:0] lz8   = lz4 | (lz4 >> 8);
    wire [27:0] lz16  = lz8 | (lz8 >> 16);
    wire [27:0] lz_oh = lz16 & ~{1'b0, lz16[27:1]};

    // One-hot leading one -> 5-bit leading-zero count.
    wire [4:0] lzd_c;
    assign lzd_c[0] = |(lz_oh & 28'b0010101010101010101010101010);
    assign lzd_c[1] = |(lz_oh & 28'b0001100110011001100110011001);
    assign lzd_c[2] = |(lz_oh & 28'b0000011110000111100001111000);
    assign lzd_c[3] = |(lz_oh & 28'b0000000001111111100000000111);
    assign lzd_c[4] = |(lz_oh & 28'b0000000000000000011111111111);

    wire [26:0] man_norm_c = man_norm0 << lzd_c;

    // exp_f32 = exp_adj - lzd + 3, built from two parallel adders so the
    // "+3" (internal scale -> FP32 biased) is off the critical path.
    wire [10:0] exp_adj_p3 = exp_adj + 11'd3;
    wire [10:0] exp_f32_c  = exp_adj_p3 - {6'd0, lzd_c};

    // Exact cancellation: result zero but not both inputs zero.
    wire is_zero_c = (man_raw_c == 28'd0) && !flags_d2[0];

    // ============================================================
    // STAGE S3 registers (capture at N+3 edge, CE = en_d2)
    // ============================================================
    reg [26:0] man_norm_d3;
    reg [10:0] exp_f32_d3;
    reg        is_zero_d3;
    reg        sign_res_d3;
    reg [2:0]  flags_d3;
    reg        s_inf_d3;
    reg        prod_sign_d3;
    reg        s_sign_d3;

    always @(posedge clk) begin
        if (reset) begin
            man_norm_d3  <= 27'd0;
            exp_f32_d3   <= 11'd0;
            is_zero_d3   <= 1'b0;
            sign_res_d3  <= 1'b0;
            flags_d3     <= 3'b000;
            s_inf_d3     <= 1'b0;
            prod_sign_d3 <= 1'b0;
            s_sign_d3    <= 1'b0;
        end else if (en_d2) begin
            man_norm_d3  <= man_norm_c;
            exp_f32_d3   <= exp_f32_c;
            is_zero_d3   <= is_zero_c;
            sign_res_d3  <= sign_res_d2;
            flags_d3     <= flags_d2;
            s_inf_d3     <= s_inf_d2;
            prod_sign_d3 <= prod_sign_d2;
            s_sign_d3    <= s_sign_d2;
        end
    end

    // ============================================================
    // STAGE S4: RTZ pack + NaN/Inf/Zero select -> output register
    //   Combinational during cycle N+3, captured at N+4 edge (CE = en_d3)
    // ============================================================

    wire [10:0] exp_f32_biased = exp_f32_d3;
    wire        underflow = exp_f32_biased[10] | (exp_f32_biased == 11'd0);
    wire        overflow  = !underflow && (exp_f32_biased[9:0] >= 10'd255);

    // RTZ: truncate the low 3 bits of the normalized significand.
    wire [22:0] frac_final = man_norm_d3[25:3];
    wire [31:0] v_norm = {sign_res_d3, exp_f32_biased[7:0], frac_final};

    // Input Inf sign: prefer SUMM if it is the infinite operand.
    wire        inf_sign = s_inf_d3 ? s_sign_d3 : prod_sign_d3;
    wire [31:0] v_inf_in = {inf_sign, 8'hFF, 23'h000000};
    wire [31:0] v_inf_ovf = {sign_res_d3, 8'hFF, 23'h000000};

    wire [31:0] v_nan  = F32_QNAN;
    wire [31:0] v_zero = 32'h0000_0000;

    // Any zero result -> +0 (FAST zero rule).
    wire zero_result = flags_d3[0] | is_zero_d3 | underflow |
                       (man_norm_d3 == 27'd0);

    reg [31:0] c_next;

    always @(*) begin
        if (flags_d3[2]) begin
            c_next = v_nan;
        end else if (flags_d3[1]) begin
            c_next = v_inf_in;
        end else if (zero_result) begin
            c_next = v_zero;
        end else if (overflow) begin
            c_next = v_inf_ovf;
        end else begin
            c_next = v_norm;
        end
    end

    // Output register (cycle N+4), CE = en_d3.
    // reset has priority over en; en=0 holds the last value (HOLD).
    always @(posedge clk) begin
        if (reset) begin
            outfp32s <= 32'h0000_0000;
        end else if (en_d3) begin
            outfp32s <= c_next;
        end
        // else: HOLD (keep last value)
    end

endmodule
