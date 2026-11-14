// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_mul4x4.v
// Module: vhfastmulb16_mul4x4
// Multiplication of two 4-bit numbers
// Result latency: 1 clk
//
// Architecture:
//   - 4 aligned partial products (a[i] ? b : 0);
//   - carry-save tree (CSA, two 3:2 levels) reduces 4 rows to 2;
//   - final sum adder (CPA) produces 8-bit result.
// Operator '*' is not used.
// ----------------------------------------------

module vhfastmulb16_mul4x4 (
    input wire clk,
    input wire reset,
    input wire en,
    input wire [3:0] a,
    input wire [3:0] b,
    output reg [7:0] c
);

    // Выровненные частичные произведения, 10 бит
    // (старшие биты всегда нулевые, запас нужен под переносы CSA)
    wire [9:0] pp0 = {6'b000000, {4{a[0]}} & b};
    wire [9:0] pp1 = {5'b00000,  {4{a[1]}} & b, 1'b0};
    wire [9:0] pp2 = {4'b0000,   {4{a[2]}} & b, 2'b00};
    wire [9:0] pp3 = {3'b000,    {4{a[3]}} & b, 3'b000};

    // CSA 1: pp0 + pp1 + pp2 -> s1 + c1 (перенос сдвинут на 1 бит влево)
    wire [9:0] g1 = (pp0 & pp1) | (pp0 & pp2) | (pp1 & pp2);
    wire [9:0] s1 = pp0 ^ pp1 ^ pp2;
    wire [9:0] c1 = {g1[8:0], 1'b0};

    // CSA 2: s1 + c1 + pp3 -> s2 + c2
    wire [9:0] g2 = (s1 & c1) | (s1 & pp3) | (c1 & pp3);
    wire [9:0] s2 = s1 ^ c1 ^ pp3;
    wire [9:0] c2 = {g2[8:0], 1'b0};

    // Финальный сумматор: единственный CPA в критическом пути.
    // Максимальное произведение 15*15 = 225, поэтому sum[9:8] всегда 0.
    wire [9:0] sum = s2 + c2;
    wire [7:0] c_calc = sum[7:0];

    // Синхронная логика
    always @(posedge clk) begin
        if (reset) begin
            c <= 8'b0;
        end else if (en) begin
            c <= c_calc;
        end
    end

endmodule
