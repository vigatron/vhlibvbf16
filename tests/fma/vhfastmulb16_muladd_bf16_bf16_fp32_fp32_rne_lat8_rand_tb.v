`timescale 1ns/1ps
// =============================================================
// Случайный тестбенч для vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8
//   RESULT = SUMM + (VALA_BF16 × VALB_BF16), FP32 output, RNE
//   Тестовые векторы из файла .hex (сгенерированного gen_fma_vectors.py)
//   Формат строки: VALA(16) VALB(16) SUMM(32) EXPECTED(32) = 96 бит
//   Проверка в потоке с LAT = 8 тактами
// =============================================================

module vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_rand_tb;

    localparam integer N         = 2048;  // число тестовых троек
    localparam integer LAT       = 8;     // latency DUT, тактов
    localparam integer MAX_PRINT = 10;    // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [15:0] inbf16a;
    reg  [15:0] inbf16b;
    reg  [31:0] infp32s;

    wire [31:0] outfp32s;

    vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8 uut (
        .clk      (clk),
        .reset    (reset),
        .en       (en),
        .inbf16a  (inbf16a),
        .inbf16b  (inbf16b),
        .infp32s  (infp32s),
        .outfp32s (outfp32s)
    );

    // ---------------- Тестовые векторы из .hex файла ----------------
    // Формат строки: VALA(16) VALB(16) SUMM(32) EXPECTED(32) = 96 бит
    reg [95:0] hex_vec [0:N-1];
    reg [15:0] va_arr [0:N-1];
    reg [15:0] vb_arr [0:N-1];
    reg [31:0] vs_arr [0:N-1];
    reg [31:0] ve_arr [0:N-1];

    integer i, k;
    integer checked, errors;
    reg [31:0] hold_val;

    initial begin
        // Загружаем hex-файл с эталонными векторами
        $readmemh("build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_rand.hex", hex_vec);

        for (i = 0; i < N; i = i + 1) begin
            va_arr[i] = hex_vec[i][95:80];
            vb_arr[i] = hex_vec[i][79:64];
            vs_arr[i] = hex_vec[i][63:32];
            ve_arr[i] = hex_vec[i][31:0];
        end
    end

    initial begin
        // Генерация тактового сигнала 100 MHz
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // RESET
        reset = 1'b1;
        en    = 1'b0;
        inbf16a = 16'h0000;
        inbf16b = 16'h0000;
        infp32s = 32'h00000000;

        repeat (5) @(negedge clk);
        reset = 1'b0;
    end

    initial begin
        $dumpfile("build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_rand.vcd");
        $dumpvars(0, vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat8_rand_tb);

        checked = 0;
        errors  = 0;

        @(negedge reset);
        repeat (10) @(negedge clk);

        for (k = 0; k < N + LAT; k = k + 1) begin
            @(posedge clk); #1;

            if (k < N) begin
                inbf16a = va_arr[k];
                inbf16b = vb_arr[k];
                infp32s = vs_arr[k];
                en = 1'b1;
            end

            if (k >= LAT) begin
                // Проверка: результат должен совпадать с эталоном
                if (uut.en_pipe) begin
                    checked = checked + 1;
                    if (outfp32s !== ve_arr[k-LAT]) begin
                        errors = errors + 1;
                        if (errors <= MAX_PRINT) begin
                            $display("[ERROR] t=%0t | triple %0d | a=%h b=%h s=%h -> out=%h exp=%h",
                                $time, k-LAT, va_arr[k-LAT], vb_arr[k-LAT], vs_arr[k-LAT],
                                outfp32s, ve_arr[k-LAT]);
                        end
                    end
                end
            end
        end

        // en=0 hold
        en = 1'b0;
        @(posedge clk); #1;
        hold_val = outfp32s;
        repeat (6) @(posedge clk); #1;
        if (outfp32s !== hold_val) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold нарушен: exp=%h got=%h",
                $time, hold_val, outfp32s);
        end

        // 10 nop clocks
        repeat (10) @(posedge clk);

        $display("---------------------------------------------");
        $display("Checked vectors: %0d", checked);
        $display("Errors:          %0d", errors);
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $display("---------------------------------------------");
        $finish;
    end

    // Watchdog
    initial begin
        #5000000;
        $display("[ERROR] Testbench timeout!");
        $finish;
    end

endmodule
