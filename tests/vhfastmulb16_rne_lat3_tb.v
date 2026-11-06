// =============================================================
// vhfastmulb16_rne_lat3_tb.v
// Visual testbench для vhfastmulb16_rne_lat3 - умножение BF16 чисел (RNE)
// Потоковая проверка: в такте k подаётся пара k,
// результат пары k-LAT проверяется в том же такте.
// После 16-го числа en=0: конвейер дорабатывает остаток
// (drain), результат 16-го умножения (NaN) выходит с задержкой
// и удерживается на выходе, а не обнуляется.
// =============================================================

`timescale 1ns/1ps

module vhfastmulb16_rne_lat3_tb;

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
    vhfastmulb16_rne_lat3 uut (
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

        $dumpfile("build/vhfastmulb16_rne_lat3.vcd");
        $dumpvars(0, vhfastmulb16_rne_lat3_tb);
        
        $display("=== vhfastmulb16 Visual Testbench ===");
        $display("Тестирование умножения BF16 чисел");
        $display("Использование 16 тестов из таблицы test_values_details.md");
        $display("-----------------------------------");
        
        checked = 0;
        errors  = 0;


        // Инициализация значений массивов из таблицы тестов (Формат: BF16)
        
        // Тест 1: Multiplication by one (1.0 * 1.0 = 1.0)
        inarr_a[0]  = 16'h3F80;  // sign:0, exp:127(0x7F, 0b01111111), mant:0(0x00, 0b0000000) => 1.0
        inarr_b[0]  = 16'h3F80;  // sign:0, exp:127(0x7F, 0b01111111), mant:0(0x00, 0b0000000) => 1.0
        outarr_c[0] = 16'h3F80;  // Expected: sign:0, exp:127(0x7F, 0b01111111), mant:0(0x00, 0b0000000) => 1.0
        
        // Тест 2: Basic integers and fractions (2.0 * 3.5 = 7.0)
        inarr_a[1]  = 16'h4000;  // sign:0, exp:128(0x80, 0b10000000), mant:0(0x00, 0b0000000) => 2.0
        inarr_b[1]  = 16'h4060;  // sign:0, exp:128(0x80, 0b10000000), mant:96(0x60, 0b1100000) => 3.5
        outarr_c[1] = 16'h40E0;  // Expected: sign:0, exp:129(0x81, 0b10000001), mant:96(0x60, 0b1100000) => 7.0
        
        // Тест 3: Multiplying negative by positive (-1.5 * 4.0 = -6.0)
        inarr_a[2]  = 16'hBFC0;  // sign:1, exp:127(0x7F, 0b01111111), mant:64(0x40, 0b1000000) => -1.5
        inarr_b[2]  = 16'h4080;  // sign:0, exp:129(0x81, 0b10000001), mant:0(0x00, 0b0000000) => 4.0
        outarr_c[2] = 16'hC0C0;  // Expected: sign:1, exp:129(0x81, 0b10000001), mant:64(0x40, 0b1000000) => -6.0
        
        // Тест 4: Values less than one (0.5 * 0.25 = 0.125)
        inarr_a[3]  = 16'h3F00;  // sign:0, exp:126(0x7E, 0b01111110), mant:0(0x00, 0b0000000) => 0.5
        inarr_b[3]  = 16'h3E80;  // sign:0, exp:125(0x7D, 0b01111101), mant:0(0x00, 0b0000000) => 0.25
        outarr_c[3] = 16'h3E00;  // Expected: sign:0, exp:124(0x7C, 0b01111100), mant:0(0x00, 0b0000000) => 0.125
        
        // Тест 5: Reciprocal powers of two (128.0 * 0.0078125 = 1.0)
        inarr_a[4]  = 16'h4300;  // sign:0, exp:134(0x86, 0b10000110), mant:0(0x00, 0b0000000) => 128.0
        inarr_b[4]  = 16'h3C00;  // sign:0, exp:120(0x78, 0b01111000), mant:0(0x00, 0b0000000) => 0.0078125 (1/128)
        outarr_c[4] = 16'h3F80;  // Expected: sign:0, exp:127(0x7F, 0b01111111), mant:0(0x00, 0b0000000) => 1.0
        
        // Тест 6: Fractional value fitting BF16 precision (3.140625 * 2.0 = 6.28125)
        inarr_a[5]  = 16'h4049;  // sign:0, exp:128(0x80, 0b10000000), mant:73(0x49, 0b1001001) => 3.140625
        inarr_b[5]  = 16'h4000;  // sign:0, exp:128(0x80, 0b10000000), mant:0(0x00, 0b0000000) => 2.0
        outarr_c[5] = 16'h40C9;  // Expected: sign:0, exp:129(0x81, 0b10000001), mant:73(0x49, 0b1001001) => 6.28125
        
        // Тест 7: Two negative values (positive result) (-100.0 * -0.10009765625 = 10.01) -> Округление BF16 даст ровно 10.0
        inarr_a[6]  = 16'hC2C8;  // sign:1, exp:133(0x85, 0b10000101), mant:72(0x48, 0b1001000) => -100.0
        inarr_b[6]  = 16'hBDCD;  // sign:1, exp:123(0x7B, 0b01111011), mant:77(0x4D, 0b1001101) => -0.10009765625
        outarr_c[6] = 16'h4120;  // Expected: sign:0, exp:130(0x82, 0b10000010), mant:32(0x20, 0b0100000) => 10.0
        
        // Тест 8: Mantissa precision check (10.0 * 0.30078125 = 3.0078) -> Ближайшее представимое в BF16 это 3.0
        inarr_a[7]  = 16'h4120;  // sign:0, exp:130(0x82, 0b10000010), mant:32(0x20, 0b0100000) => 10.0
        inarr_b[7]  = 16'h3E9A;  // sign:0, exp:125(0x7D, 0b01111101), mant:26(0x1A, 0b0011010) => 0.30078125
        outarr_c[7] = 16'h4040;  // Expected: sign:0, exp:128(0x80, 0b10000000), mant:64(0x40, 0b1000000) => 3.0
        
        // Тест 9: Regular value multiplied by zero (1.0 * 0.0 = 0.0)
        inarr_a[8]  = 16'h3F80;  // sign:0, exp:127(0x7F, 0b01111111), mant:0(0x00, 0b0000000) => 1.0
        inarr_b[8]  = 16'h0000;  // sign:0, exp:0(0x00, 0b00000000), mant:0(0x00, 0b0000000) => +0.0
        outarr_c[8] = 16'h0000;  // Expected: sign:0, exp:0(0x00, 0b00000000), mant:0(0x00, 0b0000000) => +0.0
        
        // Тест 10: Infinity multiplied by positive value (+Inf * 2.0 = +Inf)
        inarr_a[9]  = 16'h7F80;  // sign:0, exp:255(0xFF, 0b11111111), mant:0(0x00, 0b0000000) => +Inf
        inarr_b[9]  = 16'h4000;  // sign:0, exp:128(0x80, 0b10000000), mant:0(0x00, 0b0000000) => 2.0
        outarr_c[9] = 16'h7F80;  // Expected: sign:0, exp:255(0xFF, 0b11111111), mant:0(0x00, 0b0000000) => +Inf
        
        // Тест 11: Multiplying different infinities (-Inf * +Inf = -Inf)
        inarr_a[10] = 16'hFF80;  // sign:1, exp:255(0xFF, 0b11111111), mant:0(0x00, 0b0000000) => -Inf
        inarr_b[10] = 16'h7F80;  // sign:0, exp:255(0xFF, 0b11111111), mant:0(0x00, 0b0000000) => +Inf
        outarr_c[10] = 16'hFF80;  // Expected: sign:1, exp:255(0xFF, 0b11111111), mant:0(0x00, 0b0000000) => -Inf
        
        // Тест 12: Indeterminacy (∞ × 0 = NaN)
        inarr_a[11] = 16'h7F80;  // sign:0, exp:255(0xFF, 0b11111111), mant:0(0x00, 0b0000000) => +Inf
        inarr_b[11] = 16'h0000;  // sign:0, exp:0(0x00, 0b00000000), mant:0(0x00, 0b0000000) => +0.0
        outarr_c[11] = 16'h7FC0;  // Expected: sign:0, exp:255(0xFF, 0b11111111), mant:64(0x40, 0b1000000) => NaN (канонический quiet NaN)
        
        // Тест 13: NaN propagated (NaN * 5.0 = NaN)
        inarr_a[12] = 16'h7FC0;  // sign:0, exp:255(0xFF, 0b11111111), mant:64(0x40, 0b1000000) => NaN
        inarr_b[12] = 16'h40A0;  // sign:0, exp:129(0x81, 0b10000001), mant:32(0x20, 0b0100000) => 5.0
        outarr_c[12] = 16'h7FC0;  // Expected: sign:0, exp:255(0xFF, 0b11111111), mant:64(0x40, 0b1000000) => NaN
        
        // Тест 14: NaN × Infinity (NaN * +Inf = NaN)
        inarr_a[13] = 16'h7FC0;  // sign:0, exp:255(0xFF, 0b11111111), mant:64(0x40, 0b1000000) => NaN
        inarr_b[13] = 16'h7F80;  // sign:0, exp:255(0xFF, 0b11111111), mant:0(0x00, 0b0000000) => +Inf
        outarr_c[13] = 16'h7FC0;  // Expected: sign:0, exp:255(0xFF, 0b11111111), mant:64(0x40, 0b1000000) => NaN
        
        // Тест 15: Zero multiplied by zero (0.0 * 0.0 = 0.0)
        inarr_a[14] = 16'h0000;  // sign:0, exp:0(0x00, 0b00000000), mant:0(0x00, 0b0000000) => +0.0
        inarr_b[14] = 16'h0000;  // sign:0, exp:0(0x00, 0b00000000), mant:0(0x00, 0b0000000) => +0.0
        outarr_c[14] = 16'h0000;  // Expected: sign:0, exp:0(0x00, 0b00000000), mant:0(0x00, 0b0000000) => +0.0
        
        // Тест 16: Negative infinity × negative zero (NaN)
        inarr_a[15] = 16'hFF80;  // sign:1, exp:255(0xFF, 0b11111111), mant:0(0x00, 0b0000000) => -Inf
        inarr_b[15] = 16'h8000;  // sign:1, exp:0(0x00, 0b00000000), mant:0(0x00, 0b0000000) => -0.0
        outarr_c[15] = 16'h7FC0;  // Expected: sign:0, exp:255(0xFF, 0b11111111), mant:64(0x40, 0b1000000) => NaN (канонический quiet NaN)


        // ---- Сброс: 5 тактов ----
        reset = 1'b1; en = 1'b0;
        repeat (5) @(negedge clk);
            reset = 1'b0;

        repeat (5) @(negedge clk);
            @(posedge clk); #1;
        
        // ---- Потоковая подача пар и проверка в конвейере ----
        // В такте k защёлкивается пара k; результат виден через LAT тактов,
        // поэтому в такте k проверяется пара k-LAT.
        // После 16-го числа en=0: конвейер дорабатывает принятые данные
        // ещё LAT-1 тактов (drain), поэтому результаты последних пар
        // (включая 16-й - NaN) проверяются уже при en=0.
        for (k = 0; k < N + LAT; k = k + 1) begin

            @(posedge clk); #1;

            if (k < N) begin
                a_in = inarr_a[k];
                b_in = inarr_b[k];
                en   = 1'b1;
            end else begin
                // после 16-го числа: en=0, drain выталкивает остаток
                en = 1'b0;
            end

            if (k >= LAT)
                check(k - LAT);
        end

        // ---- Удержание результата при en=0 ----
        // Результат 16-го умножения (NaN) должен оставаться на выходе,
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
