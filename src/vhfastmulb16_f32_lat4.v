// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_f32_lat4.v
// Module: vhfastmulb16_f32_lat4
// BF16 x BF16 -> Float32 exact product (no rounding)
// Operation takes 4 clk (latency 4), fully pipelined
// Pipeline balanced 2+2:
//   S1: 4x mul4x4_comb partial products + exponent sum (combinational, captured N+1)
//   S2: CSA-tree + CPA -> 16-bit mantissa product (captured N+2)
//   S3: leading-one + normalization + exp_unb -> register (captured N+3)
//   S4: F32 pack mux -> output register (captured N+4)
// BF16 subnormal inputs are treated as finite values (no FTZ)
// F32 subnormal results are truncated (RTZ), no rounding
// NaN -> canonical quiet NaN 0x7FC00000
// en=0: HOLD (drain accepted data, keep last value)
// reset: synchronous, priority over en
// ----------------------------------------------

/**
 * @brief  Pipelined BF16 x BF16 multiplier with Float32 output.
 *
 * The module computes the exact product of two BF16 operands and represents
 * the result as IEEE-754 binary32. Since an 8x8-bit mantissa product fits into
 * the 24-bit F32 significand, no rounding is required for normal results.
 * F32 subnormal results are produced by truncation (round toward zero).
 *
 * BF16 subnormal operands are not flushed to zero: they are normalized into
 * the F32 result, which allows exact representation of products such as
 * min_subnormal_BF16 * 1.0 = 0x00010000.
 *
 * Pipeline is balanced 2+2:
 *   S1: 4x mul4x4_comb partial products + exponent sum (combinational)
 *   S2: CSA-tree + CPA -> 16-bit mantissa product
 *   S3: leading-one + normalization + exp_unb -> register
 *   S4: F32 pack mux -> output register
 *
 * @param clk   Clock signal.
 * @param reset Synchronous reset, active high, priority over en.
 * @param en    Enable: accept a new sample when 1, hold when 0.
 * @param ina   First BF16 operand: [15] sign, [14:7] exp, [6:0] frac.
 * @param inb   Second BF16 operand: [15] sign, [14:7] exp, [6:0] frac.
 * @param outc  F32 result: [31] sign, [30:23] exp, [22:0] frac.
 */
module vhfastmulb16_f32_lat4 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [15:0] ina,
    input  wire [15:0] inb,
    output reg  [31:0] outc
);

    localparam [31:0] F32_QNAN = 32'h7FC0_0000;

    // ---------------------------------------------------
    // BF16 operand decomposition (combinational)
    // ---------------------------------------------------
    wire       a_sign = ina[15];
    wire       b_sign = inb[15];
    wire [7:0] a_exp  = ina[14:7];
    wire [7:0] b_exp  = inb[14:7];
    wire [6:0] a_frac = ina[6:0];
    wire [6:0] b_frac = inb[6:0];

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
    // Exception classification (priority: NaN > Inf > Zero)
    // ---------------------------------------------------
    wire res_nan  = a_nan || b_nan || (a_inf && b_zero) || (b_inf && a_zero);
    wire res_inf  = !res_nan && (a_inf || b_inf);
    wire res_zero = !res_nan && !res_inf && (a_zero || b_zero);

    wire sign = a_sign ^ b_sign;

    // ---------------------------------------------------
    // Effective BF16 exponent and mantissa (combinational)
    //   normal:    value = {1'b1, frac} * 2^(exp - 134)
    //   subnormal: value = {1'b0, frac} * 2^(1 - 134) = frac * 2^-133
    // No FTZ: subnormal operands are finite non-zero values.
    // ---------------------------------------------------
    wire [7:0] a_exp_eff = a_exp_z ? 8'd1 : a_exp;
    wire [7:0] b_exp_eff = b_exp_z ? 8'd1 : b_exp;
    wire [7:0] a_man = a_exp_z ? {1'b0, a_frac} : {1'b1, a_frac};
    wire [7:0] b_man = b_exp_z ? {1'b0, b_frac} : {1'b1, b_frac};

    // Raw exponent sum S = a_exp_eff + b_exp_eff (9-bit, 2..508)
    wire [8:0] exp_sum_raw = {1'b0, a_exp_eff} + {1'b0, b_exp_eff};

    // ---------------------------------------------------
    // Pipeline enable: 4 stages + output register.
    // After en=0 the pipeline drains 4 cycles, then holds.
    // ---------------------------------------------------
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

    // ---------------------------------------------------
    // Sign pipeline (latency 3). signc_lat3 aligned with
    // stage 3 output at cycle N+3.
    // ---------------------------------------------------
    wire sign_lat3;

    vhfastmulb16_sign sign_inst (
        .clk(clk),
        .reset(reset),
        .en(en_pipe),
        .signa(a_sign),
        .signb(b_sign),
        .signc_lat1(),
        .signc_lat2(),
        .signc_lat3(sign_lat3)
    );

    // ============================================================
    // STAGE 1: 4x mul4x4_comb partial products + exponent sum
    //   Combinational during cycle N, captured at N+1 edge
    // ============================================================
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

    // ---------------------------------------------------
    // STAGE 1 -> STAGE 2 registers (capture at N+1 edge)
    // ---------------------------------------------------
    reg [7:0] p_hh_d1;
    reg [7:0] p_hl_d1;
    reg [7:0] p_lh_d1;
    reg [7:0] p_ll_d1;
    reg [8:0] exp_sum_d1;   // S registered
    reg [2:0] flags_d1;     // {nan, inf, zero}
    reg       sign_d1;

    always @(posedge clk) begin
        if (reset) begin
            p_hh_d1   <= 8'd0;
            p_hl_d1   <= 8'd0;
            p_lh_d1   <= 8'd0;
            p_ll_d1   <= 8'd0;
            exp_sum_d1 <= 9'd0;
            flags_d1   <= 3'b000;
            sign_d1    <= 1'b0;
        end else if (en_pipe) begin
            p_hh_d1   <= p_hh_calc;
            p_hl_d1   <= p_hl_calc;
            p_lh_d1   <= p_lh_calc;
            p_ll_d1   <= p_ll_calc;
            exp_sum_d1 <= exp_sum_raw;
            flags_d1   <= {res_nan, res_inf, res_zero};
            sign_d1    <= sign;
        end
    end

    // ============================================================
    // STAGE 2: CSA-tree + CPA -> 16-bit mantissa product
    //   c = (p_hh<<8) + (p_hl<<4) + (p_lh<<4) + p_ll
    //   Implemented as 2-level CSA (XOR/MAJ) + one 16-bit CPA
    // ============================================================
    wire [15:0] P0 = {8'h00, p_hh_d1} << 8;
    wire [15:0] P1 = {8'h00, p_hl_d1} << 4;
    wire [15:0] P2 = {8'h00, p_lh_d1} << 4;
    wire [15:0] P3 = {8'h00, p_ll_d1};

    // CSA level 1: P0 + P1 + P2 -> s1 + c1
    wire [15:0] g1 = (P0 & P1) | (P0 & P2) | (P1 & P2);
    wire [15:0] s1 = P0 ^ P1 ^ P2;
    wire [15:0] c1 = {g1[14:0], 1'b0};

    // CSA level 2: s1 + c1 + P3 -> s2 + c2
    wire [15:0] g2 = (s1 & c1) | (s1 & P3) | (c1 & P3);
    wire [15:0] s2 = s1 ^ c1 ^ P3;
    wire [15:0] c2 = {g2[14:0], 1'b0};

    wire [15:0] man_prod = s2 + c2;

    // ---------------------------------------------------
    // STAGE 2 -> STAGE 3 registers (capture at N+2 edge)
    // ---------------------------------------------------
    reg [15:0] man_prod_d1;
    reg [8:0]  exp_s2;       // S registered
    reg [2:0]  flags_s2;     // {nan, inf, zero}
    reg        sign_s2;

    always @(posedge clk) begin
        if (reset) begin
            man_prod_d1 <= 16'd0;
            exp_s2      <= 9'd0;
            flags_s2    <= 3'b000;
            sign_s2     <= 1'b0;
        end else if (en_pipe) begin
            man_prod_d1 <= man_prod;
            exp_s2      <= exp_sum_d1;
            flags_s2    <= flags_d1;
            sign_s2     <= sign_d1;
        end
    end

    // ============================================================
    // STAGE 3: leading-one + normalization (combinational)
    //   Results registered at N+3 edge
    // ============================================================
    reg [3:0]  k_calc;       // leading-one index of man_prod_d1
    reg [23:0] mant_norm_calc; // normalized 24-bit significand (normal path)
    reg [23:0] mant_sub_calc;  // truncated significand for F32 subnormal
    reg [9:0]  exp_unb_calc;   // S + k, 2..523

    always @(*) begin
        // Leading-one detector for the 16-bit mantissa product.
        // k is the index of the highest set bit (0..15).
        casez (man_prod_d1)
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

        // Normalized significand: hidden one goes to bit 23.
        mant_norm_calc = {8'd0, man_prod_d1} << (8'd23 - {4'd0, k_calc});

        // U = S + k. F32 biased exponent = U - 141.
        exp_unb_calc = {1'b0, exp_s2} + {6'd0, k_calc};

        // Subnormal significand computed directly, WITHOUT k dependency.
        // Mathematically equivalent to mant_norm >> (142 - exp_unb)
        // but breaks the k -> mant_norm -> shift -> mant_sub cascade.
        //   S <= 119: man_prod >> (119 - S)
        //   S >  119: man_prod << (S - 119)
        if (exp_s2 <= 8'd119)
            mant_sub_calc = {8'd0, man_prod_d1} >> (8'd119 - exp_s2[7:0]);
        else
            mant_sub_calc = {8'd0, man_prod_d1} << (exp_s2[7:0] - 8'd119);
    end

    // ---------------------------------------------------
    // STAGE 3 -> STAGE 4 registers (capture at N+3 edge)
    // ---------------------------------------------------
    reg [3:0]  k;
    reg [23:0] mant_norm;  // normalized 24-bit significand (normal path)
    reg [23:0] mant_sub;   // truncated significand for F32 subnormal
    reg [9:0]  exp_unb;    // S + k, 2..523
    reg        sign_s3;
    reg        nan_s3;
    reg        inf_s3;
    reg        zero_s3;

    always @(posedge clk) begin
        if (reset) begin
            k        <= 4'd0;
            mant_norm <= 24'd0;
            mant_sub  <= 24'd0;
            exp_unb   <= 10'd0;
            sign_s3   <= 1'b0;
            nan_s3    <= 1'b0;
            inf_s3    <= 1'b0;
            zero_s3   <= 1'b0;
        end else if (en_pipe) begin
            k        <= k_calc;
            mant_norm <= mant_norm_calc;
            mant_sub  <= mant_sub_calc;
            exp_unb   <= exp_unb_calc;
            sign_s3   <= sign_s2;
            nan_s3    <= flags_s2[2];
            inf_s3    <= flags_s2[1];
            zero_s3   <= flags_s2[0];
        end
    end

    // ============================================================
    // STAGE 4: F32 pack (combinational) -> output register
    // ============================================================
    reg [31:0] c_next;

    always @(*) begin
        if (nan_s3) begin
            // Canonical quiet NaN (per docs/test_values_bf16_bf16_f32.md).
            c_next = F32_QNAN;
        end else if (inf_s3) begin
            c_next = {sign_s3, 8'hFF, 23'h000000};
        end else if (zero_s3) begin
            c_next = {sign_s3, 31'h00000000};
        end else if (exp_unb >= 10'd396) begin
            // F32 overflow: result is outside the normal range.
            c_next = {sign_s3, 8'hFF, 23'h000000};
        end else if (exp_unb >= 10'd142) begin
            // Normal F32 result: exact, no rounding.
            // exp_unb is 142..395 here. Subtracting in 8 bits (modulo 256)
            // gives the same 1..254 biased exponent as the full 10-bit math.
            c_next = {sign_s3, (exp_unb[7:0] - 8'd141), mant_norm[22:0]};
        end else begin
            // F32 subnormal result: truncate (RTZ).
            // Zero when exp_unb <= 118 (equivalent to shift >= 24).
            if (exp_unb <= 10'd118)
                c_next = {sign_s3, 31'h00000000};
            else
                c_next = {sign_s3, 8'h00, mant_sub[22:0]};
        end
    end

    // ---------------------------------------------------
    // Output register (cycle N+4)
    // reset has priority over en; en=0 holds the last value.
    // ---------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            outc <= 32'h0000_0000;
        end else if (en_pipe) begin
            outc <= c_next;
        end
        // else: HOLD (keep last value)
    end

endmodule
