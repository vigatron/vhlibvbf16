// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_add8x8_branch.v
// Module: vhfastmulb16_add8x8
// Addition of two 8-bit numbers and subtraction of 127
// Fully pipelined, latency 2 clk
// ----------------------------------------------

module vhfastmulb16_add8x8 (
    input wire clk,
    input wire reset,
    input wire en,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [8:0] c
    );

    // ============================================================================
    // Конвейер
    //   ступень 1: c_add <= a + b
    //   ступень 2: c     <= c_add - 127
    // valid маскирует результат пустого конвейера сразу после reset
    // ============================================================================

    reg [8:0] c_add;    // Регистр суммы (ступень 1)
    
    reg en_lat1;

    always @(posedge clk) begin
        if (reset) begin
            c_add       <= 9'd0;
            c           <= 9'd0;
            en_lat1     <= 1'b0;
        end else begin

            // Ступень 1: сложение двух 8-битных чисел
            if (en) begin
                c_add <= {1'b0, a} + {1'b0, b};
            end else begin
                c_add <= 9'd0;;
            end

            // Ступень 2: вычитание 127 из предыдущей суммы.
            // 9-битная беззнаковая арифметика: при a + b < 127
            // результат представляется по модулю 512.
            if (en_lat1) begin
                c <= c_add - 9'd127;
            end else begin
                c <= 9'd0;;
            end
            
            //
            en_lat1 <= en;
            
        end
    end

endmodule