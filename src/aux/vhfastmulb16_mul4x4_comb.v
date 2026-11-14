// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// File: vhfastmulb16_mul4x4_comb.v
// Module: vhfastmulb16_mul4x4_comb
// Combinational 4x4 multiplication (CSA tree + CPA, no output register)
// Latency: 0 clk (purely combinational)
// ----------------------------------------------

module vhfastmulb16_mul4x4_comb (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [7:0] c
);

    // Выровненные частичные произведения, 10 бит
    wire [9:0] pp0 = {6'b000000, {4{a[0]}} & b};
    wire [9:0] pp1 = {5'b00000,  {4{a[1]}} & b, 1'b0};
    wire [9:0] pp2 = {4'b0000,   {4{a[2]}} & b, 2'b00};
    wire [9:0] pp3 = {3'b000,    {4{a[3]}} & b, 3'b000};

    // CSA 1: pp0 + pp1 + pp2 -> s1 + c1
    wire [9:0] g1 = (pp0 & pp1) | (pp0 & pp2) | (pp1 & pp2);
    wire [9:0] s1 = pp0 ^ pp1 ^ pp2;
    wire [9:0] c1 = {g1[8:0], 1'b0};

    // CSA 2: s1 + c1 + pp3 -> s2 + c2
    wire [9:0] g2 = (s1 & c1) | (s1 & pp3) | (c1 & pp3);
    wire [9:0] s2 = s1 ^ c1 ^ pp3;
    wire [9:0] c2 = {g2[8:0], 1'b0};

    // Финальный CPA
    wire [9:0] sum = s2 + c2;
    assign c = sum[7:0];

endmodule
