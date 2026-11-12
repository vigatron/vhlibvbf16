// ----------------------------------------------
// vhlibvbf16 - Compact pipelined BFloat16 multiplier.
// RTZ/RNE, no DSP required.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_except_lat2.v
// Module: vhfastmulb16_except_lat2
// iverilog -g2012 -o build/vhfastmulb16_except_lat2.vpp src/vhfastmulb16_except_lat2.v src/vhfastmulb16_flags_lat1.v
// en=0: HOLD (keep last value)
// reset: synchronous, priority over en
// NaN payload preservation per IEEE 754
// ----------------------------------------------

module vhfastmulb16_except_lat2 (
    input wire clk,
    input wire reset,
    input wire en,
    input wire [15:0] a,
    input wire [15:0] b,
    output reg [15:0] c,
    output reg exval,
    output reg ex_z,
    output reg ex_inf,
    output reg ex_nan
    );

    // Канонические значения BF16 (знак всегда 0;
    // знак результата формируется в vhfastmulb16_mul_bf16_bf16_bf16)
    localparam [15:0] BF16_ZERO = 16'h0000;  // +0
    localparam [15:0] BF16_INF  = 16'h7F80;  // +Infinity
    // BF16_NAN больше не используется как константа — payload берётся из входа

    // Разбор операнда A: [15] sign | [14:7] exp | [6:0] frac
    wire [7:0] a_exp = a[14:7];
    wire [7:0] a_frc = { 1'b0, a[6:0] };

    // Разбор операнда B: [15] sign | [14:7] exp | [6:0] frac
    wire [7:0] b_exp = b[14:7];
    wire [7:0] b_frc = { 1'b0, b[6:0] };

    // -----------------------------------------------------------
    // Pipeline registers для синхронизации операндов с флагами
    // flags_lat1 имеет latency 1, поэтому задерживаем a,b на 1 такт
    // -----------------------------------------------------------
    reg [15:0] a_d1, b_d1;
    reg        en_d1;

    always @(posedge clk) begin
        if (reset) begin
            a_d1  <= 16'h0000;
            b_d1  <= 16'h0000;
            en_d1 <= 1'b0;
        end else begin
            a_d1  <= a;
            b_d1  <= b;
            en_d1 <= en;
        end
    end

    // Флаги операнда A (latency 1)
    wire a_exp_z;
    wire a_exp_s;
    wire a_exp_f;
    wire a_frc_z;
    wire a_frc_nz;

    // vhfastmulb16_flags_lat1 - флаги экспоненты и дробной части операнда A
    vhfastmulb16_flags_lat1 flags_a (
    .clk(clk),
    .reset(reset),
    .en(en),
    .inexp(a_exp),
    .infrc(a_frc),
    .flag_exp_z(a_exp_z),
    .flag_exp_s(a_exp_s),
    .flag_exp_f(a_exp_f),
    .flag_frc_z(a_frc_z),
    .flag_frc_nz(a_frc_nz)
    );

    // Флаги операнда B (latency 1)
    wire b_exp_z;
    wire b_exp_s;
    wire b_exp_f;
    wire b_frc_z;
    wire b_frc_nz;

    // vhfastmulb16_flags_lat1 - флаги экспоненты и дробной части операнда B
    vhfastmulb16_flags_lat1 flags_b (
    .clk(clk),
    .reset(reset),
    .en(en),
    .inexp(b_exp),
    .infrc(b_frc),
    .flag_exp_z(b_exp_z),
    .flag_exp_s(b_exp_s),
    .flag_exp_f(b_exp_f),
    .flag_frc_z(b_frc_z),
    .flag_frc_nz(b_frc_nz)
    );

    // -----------------------------------------------------------------------
    // Pipe2: классификация операндов и обработка 0 / Inf / NaN.
    // Флаги flags имеют latency 1, а выходной регистр добавляет ещё 1 такт,
    // итоговая latency модуля — 2 такта.
    // -----------------------------------------------------------------------

    // Классификация операндов (используем флаги с latency 1)
    wire a_is_nan  = a_exp_f && a_frc_nz;   // exp = 255, frac != 0
    wire a_is_inf  = a_exp_f && a_frc_z;    // exp = 255, frac == 0
    wire a_is_zero = a_exp_z;               // exp = 0 (включая субнормали, FTZ)

    wire b_is_nan  = b_exp_f && b_frc_nz;
    wire b_is_inf  = b_exp_f && b_frc_z;
    wire b_is_zero = b_exp_z;

    // Итоговые особые случаи (приоритет: NaN > Inf > Zero)
    wire res_nan  = a_is_nan || b_is_nan ||
    (a_is_inf && b_is_zero) || (b_is_inf && a_is_zero);
    wire res_inf  = !res_nan && (a_is_inf || b_is_inf);
    wire res_zero = !res_nan && !res_inf && (a_is_zero || b_is_zero);

    // NaN payload selection: приоритет A > B
    // Используем задержанные операнды a_d1, b_d1 (синхронизированы с флагами)
    wire [15:0] nan_result = a_is_nan ? 
        { 1'b0, 8'hFF, 1'b1, a_d1[5:0] } :  // A is NaN: sign=0, exp=FF, quiet=1, payload=a_d1[5:0]
        { 1'b0, 8'hFF, 1'b1, b_d1[5:0] };   // B is NaN: sign=0, exp=FF, quiet=1, payload=b_d1[5:0]

    always @(posedge clk) begin
        if (reset) begin
            c      <= BF16_ZERO;
            exval  <= 1'b0;
            ex_z   <= 1'b0;
            ex_inf <= 1'b0;
            ex_nan <= 1'b0;
        end else if (en_d1) begin
            c      <= res_nan ? nan_result : res_inf ? BF16_INF : BF16_ZERO;
            ex_nan <= res_nan;
            ex_inf <= res_inf;
            ex_z   <= res_zero;
            exval  <= res_nan | res_inf | res_zero;
        end
        // else: HOLD (en=0 -> удерживаем значения)
    end

endmodule