// vhfastmulb16_flags_lat2.v
// Result latency 2 clk
// en=0: HOLD (удерживает последнее значение)
// reset: синхронный, приоритет над en

module vhfastmulb16_flags_lat2 (
    input wire clk,
    input wire reset,
    input wire en,

    input wire [7:0] inexp,
    input wire [7:0] infrc,

    output reg flag_exp_z,
    output reg flag_exp_s,
    output reg flag_exp_f,

    output reg flag_frc_z,
    output reg flag_frc_nz
    );

    // -------------------------------
    // 1 clk pipeline (промежуточные термы)
    // -------------------------------

    reg exp_h0; // High 4-bits all `0`
    reg exp_h1; // High 4-bits all `1'

    reg exp_l0; // Low part all `0`
    reg exp_l1; // Low part all `1`
    
    reg frc_h0;
    reg frc_l0;

    
    // Вычисление флагов экспоненты (стадия 1)
    always @(posedge clk) begin
        if (reset) begin
            exp_h0   <= 1'b0;
            exp_l0   <= 1'b0;
            exp_h1   <= 1'b0;
            exp_l1   <= 1'b0;
        end else if (en) begin
            exp_h0   <= inexp[7:4] == 4'b0000;
            exp_l0   <= inexp[3:0] == 4'b0000;
            exp_h1   <= inexp[7:4] == 4'b1111;
            exp_l1   <= inexp[3:0] == 4'b1111;
        end
        // else: HOLD (en=0 -> конвейер заморожен, термы удерживаются)
    end

    // Вычисление флагов фракции (стадия 1)
    always @(posedge clk) begin
        if (reset) begin
            frc_h0   <= 1'b0;
            frc_l0   <= 1'b0;
        end else if (en) begin
            frc_h0   <= (infrc[7:4] == 4'b0000);
            frc_l0   <= (infrc[3:0] == 4'b0000);
        end
        // else: HOLD (en=0 -> удерживаем значения)
    end
    
    // -------------------------------
    // -- 2 clk pipeline (выходные флаги)
    // -------------------------------

    // Вычисление флагов экспоненты (стадия 2)
    always @(posedge clk) begin
        if (reset) begin
            flag_exp_z   <= 1'b0;
            flag_exp_s   <= 1'b0;
            flag_exp_f   <= 1'b0;
        end else if (en) begin
            flag_exp_z   <= exp_h0 && exp_l0;
            flag_exp_s   <= !(exp_h0 && exp_l0) && !(exp_h1 && exp_l1);
            flag_exp_f   <= exp_h1 && exp_l1;
        end
        // else: HOLD (en=0 -> удерживаем значения)
    end

    // Вычисление флагов фракции (стадия 2)
    always @(posedge clk) begin
        if (reset) begin
            flag_frc_z   <= 1'b0;
            flag_frc_nz  <= 1'b0;
        end else if (en) begin
            flag_frc_z   <= frc_h0 && frc_l0;
            flag_frc_nz  <= !(frc_h0 && frc_l0);
        end
        // else: HOLD (en=0 -> удерживаем значения)
    end
    
endmodule