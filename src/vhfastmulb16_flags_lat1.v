// vhfastmulb16_flags_lat1.v
// Result latency 1 clk
// en=0: HOLD (удерживает последнее значение)
// reset: синхронный, приоритет над en

module vhfastmulb16_flags_lat1 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,

    input  wire [7:0]  inexp,
    input  wire [7:0]  infrc,

    output reg         flag_exp_z,
    output reg         flag_exp_s,
    output reg         flag_exp_f,

    output reg         flag_frc_z,
    output reg         flag_frc_nz
);

    // Комбинационные термы
    wire exp_h0 = (inexp[7:4] == 4'h0);
    wire exp_l0 = (inexp[3:0] == 4'h0);
    wire exp_h1 = (inexp[7:4] == 4'hF);
    wire exp_l1 = (inexp[3:0] == 4'hF);

    wire frc_h0 = (infrc[7:4] == 4'h0);
    wire frc_l0 = (infrc[3:0] == 4'h0);

    // Флаги экспоненты
    wire exp_z_c =  exp_h0 & exp_l0;
    wire exp_f_c =  exp_h1 & exp_l1;
    wire exp_s_c = ~exp_z_c & ~exp_f_c;

    // Флаги фракции
    wire frc_z_c  =  frc_h0 & frc_l0;
    wire frc_nz_c = ~frc_z_c;

    // 1-clk pipeline register
    always @(posedge clk) begin
        if (reset) begin
            flag_exp_z  <= 1'b0;
            flag_exp_s  <= 1'b0;
            flag_exp_f  <= 1'b0;
            flag_frc_z  <= 1'b0;
            flag_frc_nz <= 1'b0;
        end else if (en) begin
            flag_exp_z  <= exp_z_c;
            flag_exp_s  <= exp_s_c;
            flag_exp_f  <= exp_f_c;
            flag_frc_z  <= frc_z_c;
            flag_frc_nz <= frc_nz_c;
        end
        // else: HOLD (en=0 -> удерживаем значения)
    end

endmodule