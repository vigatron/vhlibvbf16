// =============================================================
// vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_tb.v
// Visual testbench для vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3
// - умножение BF16 чисел (FAST, RTZ, FTZ).
// Потоковая проверка: в такте k подаётся пара k,
// результат пары k-LAT проверяется в том же такте.
// После последней пары en=0: конвейер дорабатывает остаток
// (drain), последний результат выходит с задержкой и удерживается
// на выходе (HOLD), а не обнуляется.
// Векторы: testvalues/mul/test_values_mul_bf16_bf16_bf16/test_values_mul_bf16_bf16_fst_rtz.md
// =============================================================

`timescale 1ns/1ps

module vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_tb;

    // Частота тактового сигнала (для визуализации)
    localparam CLK_PERIOD = 10;

    localparam integer N         = 16;  // число тестовых пар
    localparam integer LAT       = 3;   // latency DUT, тактов
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно

    reg clk;
    reg reset;
    reg en;

    reg [15:0] a_in;
    reg [15:0] b_in;
    reg [15:0] c_out;

    // Массивы регистров для хранения входных и выходных данных
    reg [15:0] inarr_a [0:N-1];
    reg [15:0] inarr_b [0:N-1];
    reg [15:0] outarr_c [0:N-1];

    // Делитель частоты
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Подключение DUT
    vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3 uut (
    .clk(clk),
    .reset(reset),
    .en(en),
    .a(a_in),
    .b(b_in),
    .c(c_out)
    );

    // Счётчики и таск проверки
    integer k;
    integer checked;
    integer errors;

    // Проверка пары idx: сравнение c_out с ожидаемым значением
    task check(input integer idx);
        begin
            checked = checked + 1;

            $display("\nТест %0d: %h * %h = %h (expected)", idx, inarr_a[idx], inarr_b[idx], outarr_c[idx]);
            $display("  Expected C: %h", outarr_c[idx]);
            $display("  Actual   C: %h", c_out);

            if (c_out === outarr_c[idx]) begin
                $display(" + PASSED");
            end else begin
                errors = errors + 1;
                if (errors <= MAX_PRINT)
                    $display(" x FAILED");
            end
        end
    endtask

    // Тесты
    initial begin

        $dumpfile("build/vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3.vcd");
        $dumpvars(0, vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3_tb);

        $display("=== vhfastmulb16_mul_bf16_bf16_bf16_fst_lat3 Visual Testbench ===");
        $display("Тестирование умножения BF16 чисел (FAST, RTZ, FTZ)");
        $display("Векторы: test_values_mul_bf16_bf16_fst_rtz.md (16 базовых)");
        $display("-----------------------------------");

        checked = 0;
        errors  = 0;

        // ---- Тестовые векторы (test_values_mul_bf16_bf16_fst_rtz.md) ----

        // Тест 1: 1.0 * 1.0 = 1.0
        inarr_a[0]  = 16'h3F80;
        inarr_b[0]  = 16'h3F80;
        outarr_c[0] = 16'h3F80;

        // Тест 2: 2.0 * 3.5 = 7.0
        inarr_a[1]  = 16'h4000;
        inarr_b[1]  = 16'h4060;
        outarr_c[1] = 16'h40E0;

        // Тест 3: -1.5 * 4.0 = -6.0
        inarr_a[2]  = 16'hBFC0;
        inarr_b[2]  = 16'h4080;
        outarr_c[2] = 16'hC0C0;

        // Тест 4: 0.5 * 0.25 = 0.125
        inarr_a[3]  = 16'h3F00;
        inarr_b[3]  = 16'h3E80;
        outarr_c[3] = 16'h3E00;

        // Тест 5: 128.0 * 0.0078125 = 1.0
        inarr_a[4]  = 16'h4300;
        inarr_b[4]  = 16'h3C00;
        outarr_c[4] = 16'h3F80;

        // Тест 6: 3.140625 * 2.0 = 6.28125
        inarr_a[5]  = 16'h4049;
        inarr_b[5]  = 16'h4000;
        outarr_c[5] = 16'h40C9;

        // Тест 7: -100.0 * -0.10009765625 = 10.0 (RTZ)
        inarr_a[6]  = 16'hC2C8;
        inarr_b[6]  = 16'hBDCD;
        outarr_c[6] = 16'h4120;

        // Тест 8: 10.0 * 0.30078125 = 3.0 (RTZ)
        inarr_a[7]  = 16'h4120;
        inarr_b[7]  = 16'h3E9A;
        outarr_c[7] = 16'h4040;

        // Тест 9: 1.0 * 0.0 = 0.0
        inarr_a[8]  = 16'h3F80;
        inarr_b[8]  = 16'h0000;
        outarr_c[8] = 16'h0000;

        // Тест 10: +Inf * 2.0 = +Inf
        inarr_a[9]  = 16'h7F80;
        inarr_b[9]  = 16'h4000;
        outarr_c[9] = 16'h7F80;

        // Тест 11: -Inf * +Inf = -Inf
        inarr_a[10] = 16'hFF80;
        inarr_b[10] = 16'h7F80;
        outarr_c[10] = 16'hFF80;

        // Тест 12: +Inf * 0.0 = NaN (канонический qNaN)
        inarr_a[11] = 16'h7F80;
        inarr_b[11] = 16'h0000;
        outarr_c[11] = 16'h7FC0;

        // Тест 13: NaN * 5.0 = NaN
        inarr_a[12] = 16'h7FC0;
        inarr_b[12] = 16'h40A0;
        outarr_c[12] = 16'h7FC0;

        // Тест 14: NaN * +Inf = NaN
        inarr_a[13] = 16'h7FC0;
        inarr_b[13] = 16'h7F80;
        outarr_c[13] = 16'h7FC0;

        // Тест 15: 0.0 * 0.0 = 0.0
        inarr_a[14] = 16'h0000;
        inarr_b[14] = 16'h0000;
        outarr_c[14] = 16'h0000;

        // Тест 16: -Inf * -0.0 = NaN (канонический qNaN, без знака)
        inarr_a[15] = 16'hFF80;
        inarr_b[15] = 16'h8000;
        outarr_c[15] = 16'h7FC0;

        // ---- Сброс: 5 тактов ----
        reset = 1'b1; en = 1'b0;
        repeat (5) @(negedge clk);
            reset = 1'b0;

        repeat (5) @(negedge clk);
            @(posedge clk); #1;

        // ---- Потоковая подача пар и проверка в конвейере ----
        // В такте k защёлкивается пара k; результат виден через LAT тактов,
        // поэтому в такте k проверяется пара k-LAT.
        // После последней пары en=0: конвейер дорабатывает принятые данные
        // ещё LAT-1 тактов (drain), поэтому результаты последних пар
        // проверяются уже при en=0.
        for (k = 0; k < N + LAT; k = k + 1) begin

            @(posedge clk); #1;

            if (k < N) begin
                a_in = inarr_a[k];
                b_in = inarr_b[k];
                en   = 1'b1;
            end else begin
                // после последней пары: en=0, drain выталкивает остаток
                en = 1'b0;
            end

            if (k >= LAT)
                check(k - LAT);
        end

        // ---- Удержание результата при en=0 ----
        // Результат последнего умножения (NaN) должен оставаться на выходе,
        // а не обнуляться. Меняем входы: при en=0 они не принимаются.
        a_in = 16'h0000;
        b_in = 16'h3F80;
        repeat (3) @(posedge clk); #1;

        $display("\nУдержание при en=0: ожидается c=%h (результат теста %0d)", outarr_c[N-1], N-1);
        if (c_out !== outarr_c[N-1]) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold | exp: c=%h got: c=%h", $time, outarr_c[N-1], c_out);
        end else begin
            $display(" + PASSED");
        end

        // ---- reset имеет приоритет над en=0: выход обнуляется ----
        reset = 1'b1;
        @(posedge clk); #1;
        $display("\nСброс при en=0: ожидается c=0000");
        if (c_out !== 16'h0000) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | reset priority | exp: c=0000 got: c=%h", $time, c_out);
        end else begin
            $display(" + PASSED");
        end
        reset = 1'b0;

        repeat (5) @(posedge clk);

        // ---- Итог ----
        $display("\n=== Тесты завершены ===");
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

    // ---------------- Watchdog ----------------
    initial begin
        #1000000;
        $display("[ERROR] Testbench timeout!");
        $finish;
    end

endmodule