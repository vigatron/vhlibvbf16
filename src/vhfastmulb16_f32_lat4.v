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
    // BF16 operand decomposition
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
    wire res_nan = a_nan || b_nan || (a_inf && b_zero) || (b_inf && a_zero);
    wire res_inf = !res_nan && (a_inf || b_inf);
    wire res_zero = !res_nan && !res_inf && (a_zero || b_zero);

    wire sign = a_sign ^ b_sign;

    // ---------------------------------------------------
    // Effective BF16 exponent and mantissa
    //   normal:    value = {1'b1, frac} * 2^(exp - 134)
    //   subnormal: value = {1'b0, frac} * 2^(1 - 134) = frac * 2^-133
    // No FTZ: subnormal operands are finite non-zero values.
    // ---------------------------------------------------
    wire [7:0] a_exp_eff = a_exp_z ? 8'd1 : a_exp;
    wire [7:0] b_exp_eff = b_exp_z ? 8'd1 : b_exp;
    wire [7:0] a_man = a_exp_z ? {1'b0, a_frac} : {1'b1, a_frac};
    wire [7:0] b_man = b_exp_z ? {1'b0, b_frac} : {1'b1, b_frac};

    // ---------------------------------------------------
    // Pipeline enable: after en=0 the pipeline drains for 3 more
    // cycles, then all stages hold their last values.
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

    wire en_pipe = en | en_d1 | en_d2 | en_d3;

    // ---------------------------------------------------
    // Sign pipeline (latency 3). sign_lat3 is aligned with
    // the mantissa product at cycle N+3.
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

    // ---------------------------------------------------
    // Exponent adder (latency 2). The module computes
    // a + b - 127 modulo 512. For F32 we need the raw
    // effective sum S = a_exp_eff + b_exp_eff, so the
    // negative (wrapped) values are reconstructed below.
    // ---------------------------------------------------
    wire [8:0] exp_add;

    vhfastmulb16_add8x8_lat2 add_exp (
        .clk(clk),
        .reset(reset),
        .en(en_pipe),
        .a(a_exp_eff),
        .b(b_exp_eff),
        .c(exp_add)
    );

    // S = a_exp_eff + b_exp_eff, 2..508.
    // exp_add = S - 127 (mod 512). For S < 127 the value is
    // represented as 512 + S - 127 = S + 385, i.e. 387..511.
    wire [8:0] exp_sum_eff = (exp_add > 9'd381)
                           ? (exp_add - 9'd385)
                           : (exp_add + 9'd127);

    // ---------------------------------------------------
    // Mantissa multiplier (latency 3)
    // ---------------------------------------------------
    wire [15:0] man_prod;

    vhfastmulb16_mul8x8_lat3 mul_man (
        .clk(clk),
        .reset(reset),
        .en(en_pipe),
        .a(a_man),
        .b(b_man),
        .c(man_prod)
    );

    // ---------------------------------------------------
    // Stage registers: sign is handled by vhfastmulb16_sign,
    // exponent by exp_s3, exception flags by flags_s1..s3.
    // ---------------------------------------------------
    reg [8:0] exp_s3;
    reg [2:0] flags_s1;  // {nan, inf, zero}
    reg [2:0] flags_s2;
    reg [2:0] flags_s3;

    always @(posedge clk) begin
        if (reset) begin
            exp_s3   <= 9'd0;
            flags_s1 <= 3'b000;
            flags_s2 <= 3'b000;
            flags_s3 <= 3'b000;
        end else if (en_pipe) begin
            exp_s3   <= exp_sum_eff;
            flags_s1 <= {res_nan, res_inf, res_zero};
            flags_s2 <= flags_s1;
            flags_s3 <= flags_s2;
        end
    end

    wire nan_s3  = flags_s3[2];
    wire inf_s3  = flags_s3[1];
    wire zero_s3 = flags_s3[0];

    // ---------------------------------------------------
    // Combinational F32 packing (executed on cycle N+3,
    // captured by the output register on cycle N+4).
    // ---------------------------------------------------
    reg [3:0]  k;          // leading-one index of man_prod
    reg [23:0] mant_norm;  // normalized 24-bit significand (normal path)
    reg [23:0] mant_sub;   // truncated significand for F32 subnormal
    reg [9:0]  exp_unb;    // S + k, 2..523
    reg [31:0] c_next;

    always @(*) begin
        // Leading-one detector for the 16-bit mantissa product.
        // k is the index of the highest set bit (0..15).
        casez (man_prod)
            16'b1???????????????: k = 4'd15;
            16'b01??????????????: k = 4'd14;
            16'b001?????????????: k = 4'd13;
            16'b0001????????????: k = 4'd12;
            16'b00001???????????: k = 4'd11;
            16'b000001??????????: k = 4'd10;
            16'b0000001?????????: k = 4'd9;
            16'b00000001????????: k = 4'd8;
            16'b000000001???????: k = 4'd7;
            16'b0000000001??????: k = 4'd6;
            16'b00000000001?????: k = 4'd5;
            16'b000000000001????: k = 4'd4;
            16'b0000000000001???: k = 4'd3;
            16'b00000000000001??: k = 4'd2;
            16'b000000000000001?: k = 4'd1;
            default:             k = 4'd0;
        endcase

        // Normalized significand: hidden one goes to bit 23.
        mant_norm = {8'd0, man_prod} << (8'd23 - {4'd0, k});

        // U = (a_exp_eff + b_exp_eff) + k.
        // F32 biased exponent = U - 141.
        exp_unb = {1'b0, exp_s3} + {6'd0, k};

        // Subnormal significand computed directly, WITHOUT k dependency.
        // Mathematically equivalent to mant_norm >> (142 - exp_unb)
        // but breaks the k -> mant_norm -> shift -> mant_sub cascade.
        //   S <= 119: man_prod >> (119 - S)
        //   S >  119: man_prod << (S - 119)
        if (exp_s3 <= 8'd119)
            mant_sub = {8'd0, man_prod} >> (8'd119 - exp_s3[7:0]);
        else
            mant_sub = {8'd0, man_prod} << (exp_s3[7:0] - 8'd119);

        if (nan_s3) begin
            // Canonical quiet NaN (per docs/test_values_bf16_bf16_f32.md).
            c_next = F32_QNAN;
        end else if (inf_s3) begin
            c_next = {sign_lat3, 8'hFF, 23'h000000};
        end else if (zero_s3) begin
            c_next = {sign_lat3, 31'h00000000};
        end else if (exp_unb >= 10'd396) begin
            // F32 overflow: result is outside the normal range.
            c_next = {sign_lat3, 8'hFF, 23'h000000};
        end else if (exp_unb >= 10'd142) begin
            // Normal F32 result: exact, no rounding.
            // exp_unb is 142..395 here. Subtracting in 8 bits (modulo 256)
            // gives the same 1..254 biased exponent as the full 10-bit math.
            c_next = {sign_lat3, (exp_unb[7:0] - 8'd141), mant_norm[22:0]};
        end else begin
            // F32 subnormal result: truncate (RTZ).
            // Zero when S <= 95 (equivalent to shift >= 24).
            if (exp_s3 <= 8'd95)
                c_next = {sign_lat3, 31'h00000000};
            else
                c_next = {sign_lat3, 8'h00, mant_sub[22:0]};
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
