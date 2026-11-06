// vhfastmulb16_sign.v
// Pipeline: signc_lat1 -> signc_lat2 -> signc_lat3 (1/2/3 clk latency)
// en=0: HOLD (уhalten последнее значение)
// reset: синхронный, приоритет над en

module vhfastmulb16_sign (
    input  wire clk,
    input  wire reset,
    input  wire en,

    input  wire signa,
    input  wire signb,

    output reg  signc_lat1,
    output reg  signc_lat2,
    output reg  signc_lat3
);

    // Комбинационный XOR
    wire signc_c = signa ^ signb;

    // Стадия 1: latency 1
    always @(posedge clk) begin
        if (reset)
            signc_lat1 <= 1'b0;
        else if (en)
            signc_lat1 <= signc_c;
        // else: HOLD (en=0 -> удерживаем значение)
    end

    // Стадия 2: latency 2 (пропуск через signc_lat1)
    always @(posedge clk) begin
        if (reset)
            signc_lat2 <= 1'b0;
        else if (en)
            signc_lat2 <= signc_lat1;
        // else: HOLD (en=0 -> удерживаем значение)
    end

    // Стадия 3: latency 3 (пропуск через signc_lat2)
    always @(posedge clk) begin
        if (reset)
            signc_lat3 <= 1'b0;
        else if (en)
            signc_lat3 <= signc_lat2;
        // else: HOLD (en=0 -> удерживаем значение)
    end

endmodule