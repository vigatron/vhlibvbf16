// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_f32_lat4.v
// Module: vhfastmulb16_f32_lat4
// en=0: HOLD (keep last value)
// reset: synchronous, priority over en
// STUB: реализация умножения BF16 -> F32 (latency 4) пока не выполнена
// ----------------------------------------------

/// @brief  Конвейерный умножитель BF16 x BF16 с выдачей в формате F32 (latency 4).
///         Заглушка: содержательная реализация будет добавлена позже.
module vhfastmulb16_f32_lat4 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [15:0] ina,
    input  wire [15:0] inb,
    output reg  [31:0] outc
    );

    always @(posedge clk) begin
        if (reset) begin
            outc <= 32'h0000_0000;
        end else if (en) begin
            outc <= 32'h0000_0000;  // TODO: результат умножения (4 ступени конвейера)
        end
        // en=0: HOLD — сохраняем последнее значение
    end

endmodule
