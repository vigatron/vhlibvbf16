// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_rne_lat3.v
// Module: vhfastmulb16_rne_lat3
// BF16 multiplication (RNE rounding)
// Result is BF16 number
// Operation takes 3 clk (latency 3)
// Round to Nearest Even (IEEE 754 default)
// Subnormal inputs: Flush To Zero (FTZ), treated as 0
// ----------------------------------------------

module vhfastmulb16_rne_lat3 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [15:0] c
);

    // Разбор BF16 на компоненты
    wire a_sign = a[15];
    wire b_sign = b[15];

    wire [7:0] a_exp = a[14:7];
    wire [7:0] b_exp = b[14:7];
    wire [6:0] a_frac = a[6:0];
    wire [6:0] b_frac = b[6:0];

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

    // Мантиссы для умножителя: нормальные имеют hidden bit 1, субнормалы (после FTZ) -> 0
    wire [7:0] a_man = a_is_subnormal ? 8'h00 : { 1'b1, a_frac };
    wire [7:0] b_man = b_is_subnormal ? 8'h00 : { 1'b1, b_frac };

    // ---------------------------------------------------
    // Drain pipeline
    // ---------------------------------------------------
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

    // ---------------------------------------------------
    // Exponent adder (latency 2)
    // ---------------------------------------------------
    wire [8:0] exp_sum;

    vhfastmulb16_add8x8_lat2 add_exp (
        .clk(clk),
        .reset(reset),
        .en(en_pipe),
        .a(a_exp_eff),
        .b(b_exp_eff),
        .c(exp_sum)
    );

    // ---------------------------------------------------
    // Flags for exception handling
    // ---------------------------------------------------
    wire [7:0] a_frc = { 1'b0, a_frac_eff };
    wire [7:0] b_frc = { 1'b0, b_frac_eff };

    // ---------------------------------------------------
    // Sign pipeline (latency 3)
    // ---------------------------------------------------
    wire signc_lat2, signc_lat3;

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
    // Exception handling (latency 2)
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

    // ---------------------------------------------------
    // Mantissa multiplier (latency 2)
    // ---------------------------------------------------
    wire [15:0] c_man_mul;

    vhfastmulb16_mul8x8 mul_man (
        .clk(clk),
        .reset(reset),
        .en(en_pipe),
        .a(a_man),
        .b(b_man),
        .c(c_man_mul)
    );

    // ---------------------------------------------------
    // RNE Rounding Logic (combinational) - в always_comb
    // ---------------------------------------------------
    reg         man_msb;
    reg [7:0]   man_shifted;
    reg         G, R, S, LSB, round_up;
    reg [8:0]   exp_norm;
    reg [6:0]   man_norm;
    reg         exp_underflow, exp_overflow;

    // Временные переменные для always_comb
    reg [8:0]   exp_norm_pre;
    reg [7:0]   man_final;
    reg         man_round_carry;

    always @(*) begin
        man_msb     = c_man_mul[15];
        man_shifted = man_msb ? c_man_mul[15:8] : c_man_mul[14:7];

        G = man_msb ? c_man_mul[7]  : c_man_mul[6];
        R = man_msb ? c_man_mul[6]  : c_man_mul[5];
        S = man_msb ? (|c_man_mul[5:0]) : (|c_man_mul[4:0]);
        LSB = man_shifted[0];
        round_up = G & (R | S | LSB);

        // Экспонента до округления
        exp_norm_pre = exp_sum + { 8'b0, man_msb };

        // RNE округление мантиссы: инкремент на 1 если round_up=1
        // Реализуем инкремент через битовые операции (без +)
        if (round_up) begin
            // Инкремент 8-битного man_shifted
            man_final[0] = ~man_shifted[0];
            man_final[1] = man_shifted[1] ^ man_shifted[0];
            man_final[2] = man_shifted[2] ^ (man_shifted[1] & man_shifted[0]);
            man_final[3] = man_shifted[3] ^ (man_shifted[2] & man_shifted[1] & man_shifted[0]);
            man_final[4] = man_shifted[4] ^ (man_shifted[3] & man_shifted[2] & man_shifted[1] & man_shifted[0]);
            man_final[5] = man_shifted[5] ^ (man_shifted[4] & man_shifted[3] & man_shifted[2] & man_shifted[1] & man_shifted[0]);
            man_final[6] = man_shifted[6] ^ (man_shifted[5] & man_shifted[4] & man_shifted[3] & man_shifted[2] & man_shifted[1] & man_shifted[0]);
            man_final[7] = man_shifted[7] ^ (man_shifted[6] & man_shifted[5] & man_shifted[4] & man_shifted[3] & man_shifted[2] & man_shifted[1] & man_shifted[0]);
            man_round_carry = man_shifted[7] & man_shifted[6] & man_shifted[5] & man_shifted[4] & man_shifted[3] & man_shifted[2] & man_shifted[1] & man_shifted[0];
        end else begin
            man_final = man_shifted;
            man_round_carry = 1'b0;
        end

        // Финальная экспонента с переносом
        exp_norm = exp_norm_pre + { 8'b0, man_round_carry };

        exp_underflow = (exp_sum > 9'd381) || (exp_norm == 9'd0);
        exp_overflow  = (exp_sum <= 9'd381) && (exp_norm > 9'd254);

        man_norm = man_final[6:0];
    end

    // ---------------------------------------------------
    // Комбинационный выбор результата на такте N+2
    // ---------------------------------------------------
    wire [15:0] c_next;

    assign c_next = ex_nan_l2 ? { signc_lat2, except_c_l2[14:0] } :
                    ex_inf_l2 ? { signc_lat2, except_c_l2[14:0] } :
                    ex_z_l2   ? { signc_lat2, except_c_l2[14:0] } :
                    exp_underflow ? { signc_lat2, 15'h0000 } :
                    exp_overflow  ? { signc_lat2, 8'hFF, 7'h00 } :
                                    { signc_lat2, exp_norm[7:0], man_norm };

    // ---------------------------------------------------
    // Выходной регистр (такт N+3)
    // ---------------------------------------------------
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