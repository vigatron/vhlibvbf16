// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_mul_u8_u8_u16_lat3.v
// Module: vhfastmulb16_mul_u8_u8_u16_lat3
// Multiplication of two 8-bit numbers using vhfastmulb16_mul4x4_lat2
// Result latency: 3 clk (fully pipelined)
// ----------------------------------------------

/**
 * @brief 8x8 bit multiplier with 3-cycle latency using 4x4 multipliers.
 *
 * This module multiplies two 8-bit numbers by splitting them into 4-bit nibbles
 * and using four instances of vhfastmulb16_mul4x4_lat2 (2-cycle latency each).
 * The partial products are then summed in a third pipeline stage.
 *
 * @param clk   Clock signal
 * @param reset Synchronous reset, active high
 * @param en    Enable: accept new inputs when 1, hold when 0
 * @param a     First 8-bit operand
 * @param b     Second 8-bit operand
 * @param c     16-bit product (valid after 3 cycles)
 */
module vhfastmulb16_mul_u8_u8_u16_lat3 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    output reg  [15:0] c
);

    // -------------------------------------------------------------------------
    // Operand decomposition: split 8-bit inputs into high/low 4-bit nibbles
    // -------------------------------------------------------------------------
    wire [3:0] a_high, b_high;
    wire [3:0] a_low,  b_low;

    assign a_high = a[7:4];
    assign b_high = b[7:4];
    assign a_low  = a[3:0];
    assign b_low  = b[3:0];

    // -------------------------------------------------------------------------
    // Enable pipeline for submodules: keep enabled for 2 cycles after en=0
    // to allow pipeline to drain (matches mul4x4_lat2 latency of 2)
    // -------------------------------------------------------------------------
    reg en_d1, en_d2;

    always @(posedge clk) begin
        if (reset) begin
            en_d1 <= 1'b0;
            en_d2 <= 1'b0;
        end else begin
            en_d1 <= en;
            en_d2 <= en_d1;
        end
    end

    wire en_pipe = en | en_d1 | en_d2;

    // -------------------------------------------------------------------------
    // Stage 1-2: Four parallel 4x4 multiplications (latency 2 each)
    //   p_hh = a_high * b_high  (weight 256 = <<8)
    //   p_hl = a_high * b_low   (weight 16  = <<4)
    //   p_lh = a_low  * b_high  (weight 16  = <<4)
    //   p_ll = a_low  * b_low   (weight 1)
    // -------------------------------------------------------------------------
    wire [7:0] p_hh, p_hl, p_lh, p_ll;

    vhfastmulb16_mul4x4_lat2 mul_hh (
        .clk   (clk),
        .reset (reset),
        .en    (en_pipe),
        .a     (a_high),
        .b     (b_high),
        .c     (p_hh)
    );

    vhfastmulb16_mul4x4_lat2 mul_hl (
        .clk   (clk),
        .reset (reset),
        .en    (en_pipe),
        .a     (a_high),
        .b     (b_low),
        .c     (p_hl)
    );

    vhfastmulb16_mul4x4_lat2 mul_lh (
        .clk   (clk),
        .reset (reset),
        .en    (en_pipe),
        .a     (a_low),
        .b     (b_high),
        .c     (p_lh)
    );

    vhfastmulb16_mul4x4_lat2 mul_ll (
        .clk   (clk),
        .reset (reset),
        .en    (en_pipe),
        .a     (a_low),
        .b     (b_low),
        .c     (p_ll)
    );

    // -------------------------------------------------------------------------
    // Enable pipeline for output stage: 2 cycles to match mul4x4_lat2 latency
    // en_s1 = en delayed by 1, en_s2 = en delayed by 2
    // -------------------------------------------------------------------------
    reg en_s1, en_s2;

    always @(posedge clk) begin
        if (reset) begin
            en_s1 <= 1'b0;
            en_s2 <= 1'b0;
        end else begin
            en_s1 <= en;
            en_s2 <= en_s1;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 3: Carry-Propagate Adder (combinational)
    // c = (p_hh << 8) + (p_hl << 4) + (p_lh << 4) + p_ll
    // Вместо трёх последовательных carry-цепочек — два уровня CSA
    // (только XOR/MAJ) и один финальный 16-битный CPA.
    // Max value: 225*256 + 225*16 + 225*16 + 225 = 65025 < 65536 (fits in 16 bits)
    // -------------------------------------------------------------------------
    wire [15:0] P0 = {8'h00, p_hh} << 8;
    wire [15:0] P1 = {8'h00, p_hl} << 4;
    wire [15:0] P2 = {8'h00, p_lh} << 4;
    wire [15:0] P3 = {8'h00, p_ll};

    // CSA уровень 1: P0 + P1 + P2 -> s1 + c1
    wire [15:0] g1 = (P0 & P1) | (P0 & P2) | (P1 & P2);
    wire [15:0] s1 = P0 ^ P1 ^ P2;
    wire [15:0] c1 = {g1[14:0], 1'b0};

    // CSA уровень 2: s1 + c1 + P3 -> s2 + c2
    wire [15:0] g2 = (s1 & c1) | (s1 & P3) | (c1 & P3);
    wire [15:0] s2 = s1 ^ c1 ^ P3;
    wire [15:0] c2 = {g2[14:0], 1'b0};

    wire [15:0] sum_s3 = s2 + c2;

    // -------------------------------------------------------------------------
    // Output register: updated when en_s2=1 (data from 2 cycles ago is valid)
    // reset has priority; en=0 holds last value (no clearing)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            c <= 16'h0000;
        end else if (en_s2) begin
            c <= sum_s3;
        end
        // en_s2 == 0: hold last value
    end

endmodule