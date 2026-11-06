// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_rtz_lat3.v
// Module: vhfastmulb16_rtz_lat3
// BF16 multiplication (RTZ rounding)
// Result is BF16 number
// Operation takes 3 clk (latency 3)
// Round Toward Zero (truncation), simple discard of lower bits
// Subnormal inputs: Flush To Zero (FTZ), treated as 0
// ----------------------------------------------

module vhfastmulb16_rtz_lat3 (
    input wire clk,
    input wire reset,
    input wire en,
    input wire [15:0] a,
    input wire [15:0] b,
    output reg [15:0] c
    );

    // Разбор BF16 на компоненты
    // BF16 формат: [1 бит знак | 8 бит экспонента | 7 бит мантисса]
    // Входные сигналы (16 бит)
    wire a_sign;       // a[15]
    wire [7:0] a_exp;  // a[14:7]
    wire [6:0] a_frac; // a[6:0]
    
    wire b_sign;       // b[15]
    wire [7:0] b_exp;  // b[14:7]
    wire [6:0] b_frac; // b[6:0]
    
    // ---------------------------------------------------
    // FTZ (Flush To Zero): субнормалы (exp=0, frac!=0) -> 0
    // Детектируем субнормалы и маскируем их до нуля ДО конвейеров
    // ---------------------------------------------------
    wire a_is_subnormal = (a_exp == 8'h00) && (a_frac != 7'h00);
    wire b_is_subnormal = (b_exp == 8'h00) && (b_frac != 7'h00);
    
    // Эффективные операнды после FTZ
    wire [7:0] a_exp_eff = a_is_subnormal ? 8'h00 : a_exp;
    wire [7:0] b_exp_eff = b_is_subnormal ? 8'h00 : b_exp;
    wire [6:0] a_frac_eff = a_is_subnormal ? 7'h00 : a_frac;
    wire [6:0] b_frac_eff = b_is_subnormal ? 7'h00 : b_frac;

    assign a_sign = a[15];
    assign b_sign = b[15];

    assign a_exp = a[14:7];
    assign b_exp = b[14:7];
    assign a_frac = a[6:0];
    assign b_frac = b[6:0];

    // vhfastmulb16_mul8x8 - умножение мантисс 8x8 -> 16 бит
    // Для нормальных: {1'b1, frac}, для субнормалов (после FTZ): {1'b0, 0} = 0
    wire [7:0] a_man = a_is_subnormal ? 8'h00 : { 1'b1, a_frac };
    wire [7:0] b_man = b_is_subnormal ? 8'h00 : { 1'b1, b_frac };

    // ---------------------------------------------------
    // Drain: после снятия en конвейер дорабатывает принятые
    // данные ещё 2 такта (ступень B + выходной регистр c),
    // после чего выход удерживает последний результат.
    // en=1 -> en_pipe=1 постоянно, поведение не меняется.
    // ---------------------------------------------------
    reg en_d1;
    reg en_d2;

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

    // vhfastmulb16_add8x8_lat2 - сложение экспонент 8x8 -> 9 бит
    // Используем эффективные экспоненты (после FTZ)
    wire [8:0] exp_sum;
    
    vhfastmulb16_add8x8_lat2 add_exp (
    .clk(clk),
    .reset(reset),
    .en(en_pipe),
    .a(a_exp_eff),
    .b(b_exp_eff),
    .c(exp_sum)
    );

    // Дробная часть для блока флагов: без скрытой единицы, infrc[7] = 0
    // Используем эффективные фракции (после FTZ)
    wire [7:0] a_frc;
    wire [7:0] b_frc;

    assign a_frc = { 1'b0, a_frac_eff };
    assign b_frc = { 1'b0, b_frac_eff };

    // ---------------------------------------------------
    // Sign pipeline (vhfastmulb16_sign, latency 3)
    // signc_lat2 на такте N+2 == signc_lat3 на такте N+3
    // ---------------------------------------------------
    wire signc_lat2;
    wire signc_lat3;

    vhfastmulb16_sign sign_inst (
    .clk(clk),
    .reset(reset),
    .en(en_pipe),
    .signa(a_sign),
    .signb(b_sign),
    .signc_lat1(),
    .signc_lat2(signc_lat2),
    .signc_lat3(signc_lat3)
    );

    // ---------------------------------------------------
    // Exception handling (vhfastmulb16_except_lat2, latency 2)
    // Выходы except_c_l2, ex_*_l2 готовы на такте N+2
    // Передаём эффективные операнды (после FTZ) для согласованности
    // ---------------------------------------------------
    wire [15:0] except_c_l2;
    wire        exval_l2, ex_z_l2, ex_inf_l2, ex_nan_l2;

    // Эффективные операнды после FTZ для exception path
    wire [15:0] a_eff = { a_sign, a_exp_eff, a_frac_eff };
    wire [15:0] b_eff = { b_sign, b_exp_eff, b_frac_eff };

    vhfastmulb16_except_lat2 except_inst (
    .clk(clk),
    .reset(reset),
    .en(en_pipe),
    .a(a_eff),
    .b(b_eff),
    .c(except_c_l2),
    .exval(exval_l2),
    .ex_z(ex_z_l2),
    .ex_inf(ex_inf_l2),
    .ex_nan(ex_nan_l2)
    );

    wire [15:0] c_man_mul;
    
    vhfastmulb16_mul8x8 mul_man (
    .clk(clk),
    .reset(reset),
    .en(en_pipe),
    .a(a_man),
    .b(b_man),
    .c(c_man_mul)
    );

    // Экспонента результата: exp_sum = a_exp + b_exp - 127 (9 бит, по модулю 512).
    // Для нормальных операндов exp_sum лежит в 0..381, а отрицательные значения
    // представляются как 387..511 (382..386 невозможны).
    wire [8:0] exp_norm = exp_sum + { 8'b0, c_man_mul[15] };
    wire exp_underflow = (exp_sum > 9'd381) || (exp_norm == 9'd0);
    wire exp_overflow  = (exp_sum <= 9'd381) && (exp_norm > 9'd254);

    // Мантисса нормализованного результата (усечение, без округления)
    wire [6:0] man_norm = c_man_mul[15] ? c_man_mul[14:8] : c_man_mul[13:7];

    // ---------------------------------------------------
    // Комбинационный выбор результата на такте N+2
    // Используем signc_lat2 (== signc_lat3 на следующем такте)
    // ---------------------------------------------------
    wire [15:0] c_next;

    assign c_next = ex_nan_l2 ? { signc_lat2, except_c_l2[14:0] } :
    ex_inf_l2 ? { signc_lat2, except_c_l2[14:0] } :
    ex_z_l2   ? { signc_lat2, except_c_l2[14:0] } :
    exp_underflow ? { signc_lat2, 15'h0000 } :
    exp_overflow  ? { signc_lat2, 8'hFF, 7'h00 } :
    { signc_lat2, exp_norm[7:0], man_norm };

    // c - выходное значение (регистр), обновляется на 3-м такте (N+3).
    // При en_pipe=0 (en=0 и drain завершён) - удержание последнего
    // результата, а не обнуление.
    always @(posedge clk) begin
        if (reset) begin
            c <= 16'b0;
        end else begin
            if (en_pipe) begin
                c <= c_next;
            end
        end
    end

endmodule