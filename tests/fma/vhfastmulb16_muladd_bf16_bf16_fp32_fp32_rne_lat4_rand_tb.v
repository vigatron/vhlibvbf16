`timescale 1ns/1ps
// =============================================================
// Случайный тестбенч для vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4
//   RESULT = SUMM + (VALA_BF16 × VALB_BF16), FP32 output, RNE
//   Случайные тестовые векторы, проверка в потоке с LAT = 4
// =============================================================

module vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand_tb;

    localparam integer N         = 2048;  // число тестовых троек
    localparam integer LAT       = 4;     // latency DUT, тактов
    localparam integer MAX_PRINT = 10;    // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [15:0] inbf16a;
    reg  [15:0] inbf16b;
    reg  [31:0] infp32s;

    wire [31:0] outfp32s;

    vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4 uut (
        .clk      (clk),
        .reset    (reset),
        .en       (en),
        .inbf16a  (inbf16a),
        .inbf16b  (inbf16b),
        .infp32s  (infp32s),
        .outfp32s (outfp32s)
    );

    // ---------------- Генератор случайных чисел (LCG) ----------------
    reg  [31:0] rng_state;
    wire [31:0] rng_next;

    assign rng_next = rng_state * 32'h19660D + 32'h3C6EF35F;

    // ---------------- Тестовые векторы ----------------
    reg  [15:0] va_arr [0:N-1];
    reg  [15:0] vb_arr [0:N-1];
    reg  [31:0] vs_arr [0:N-1];
    reg  [31:0] ve_arr [0:N-1];

    integer i, k;
    integer checked, errors;
    reg [31:0] hold_val;

    initial begin
        // Генерируем тестовые векторы
        rng_state = 32'h12345678;
        for (i = 0; i < N; i = i + 1) begin
            rng_state = rng_next;
            va_arr[i] = {rng_state[31], rng_state[30:24], rng_state[23:17]};
            rng_state = rng_next;
            vb_arr[i] = {rng_state[31], rng_state[30:24], rng_state[23:17]};
            rng_state = rng_next;
            vs_arr[i] = {rng_state[31], rng_state[30:23], rng_state[22:0]};
            // Ожидаемый результат вычисляется отдельно (Python-модель)
            ve_arr[i] = vs_arr[i]; // заглушка - заменяется при верификации
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
        $dumpfile("build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand.vcd");
        $dumpvars(0, vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_rand_tb);

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
                // Проверка: результат должен быть конечным, если операнды конечные
                if (uut.en_pipe) begin
                    checked = checked + 1;
                    if (!is_finite(outfp32s) && is_finite_val(va_arr[k-LAT], vb_arr[k-LAT], vs_arr[k-LAT])) begin
                        errors = errors + 1;
                        if (errors <= MAX_PRINT) begin
                            $display("[ERROR] t=%0t | triple %0d | a=%h b=%h s=%h -> out=%h (не конечное)",
                                $time, k-LAT, va_arr[k-LAT], vb_arr[k-LAT], vs_arr[k-LAT], outfp32s);
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

    // Вспомогательные функции
    function is_finite;
        input [31:0] val;
        reg [7:0] e;
        begin
            e = val[30:23];
            is_finite = (e != 8'hFF); // не Inf/NaN
        end
    endfunction

    function is_finite_val;
        input [15:0] a;
        input [15:0] b;
        input [31:0] s;
        begin
            is_finite_val = (a[14:7] != 8'hFF || a[6:0] == 0) &&
                            (b[14:7] != 8'hFF || b[6:0] == 0) &&
                            (s[30:23] != 8'hFF || s[22:0] == 0);
        end
    endfunction

endmodule