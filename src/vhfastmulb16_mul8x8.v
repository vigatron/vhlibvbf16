// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_mul8x8.v
// Module: vhfastmulb16_mul8x8
// Multiplication of two 8-bit numbers
// Uses 4 instances of vhfastmulb16_mul4x4
// Latency: 2 clk (fully pipelined)
// ----------------------------------------------

module vhfastmulb16_mul8x8 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    output reg  [15:0] c
);

    wire [3:0] a_high, b_high;
    wire [3:0] a_low,  b_low;

    assign a_high = a[7:4];
    assign b_high = b[7:4];
    assign a_low  = a[3:0];
    assign b_low  = b[3:0];

    // Частичные произведения от mul4x4 (latency 1)
    wire [7:0] p_hh, p_hl, p_lh, p_ll;

    vhfastmulb16_mul4x4 mul_hh (
        .clk(clk), .reset(reset), .en(en),
        .a(a_high), .b(b_high), .c(p_hh)
    );
    vhfastmulb16_mul4x4 mul_hl (
        .clk(clk), .reset(reset), .en(en),
        .a(a_high), .b(b_low),  .c(p_hl)
    );
    vhfastmulb16_mul4x4 mul_lh (
        .clk(clk), .reset(reset), .en(en),
        .a(a_low),  .b(b_high), .c(p_lh)
    );
    vhfastmulb16_mul4x4 mul_ll (
        .clk(clk), .reset(reset), .en(en),
        .a(a_low),  .b(b_low),  .c(p_ll)
    );

    // ---------------------------------------------------------
    // Комбинационный сумматор: CSA-дерево (2 уровня CSA 3:2 + CPA)
    // c = (p_hh << 8) + (p_hl << 4) + (p_lh << 4) + p_ll
    // Вместо трёх последовательных carry-цепочек — два уровня CSA
    // (только XOR/MAJ) и один финальный 16-битный CPA.
    // Входы уже зарегистрированы в mul4x4 (1 такт), сумма регистрируется здесь (+1 такт)
    // Итоговая латентность: 2 такта
    // ---------------------------------------------------------
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

    wire [15:0] sum_s2 = s2 + c2;

    // ---------------------------------------------------------
    // Выходной регистр: при en=0 удерживаем значение (hold)
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            c <= 16'h0000;
        end else if (en) begin
            c <= sum_s2;
        end
        // en == 0: hold last value (НЕ обнуляем!)
    end

endmodule