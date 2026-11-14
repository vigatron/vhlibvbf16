`timescale 1ns/1ps
// =============================================================
// Визуализационный тестбенч для vhfastmulb16_mul_u8_u8_u16_lat2
//   4 пары чисел подаются подряд, каждый такт новая пара
//   латентность результата 2 такта
// =============================================================

module vhfastmulb16_mul_u8_u8_u16_lat2_chk_tb;

    localparam MAX_PRINT = 10;      // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [7:0]  a;
    reg  [7:0]  b;
    wire [15:0] c;

    vhfastmulb16_mul_u8_u8_u16_lat2 uut (
    .clk   (clk),
    .reset (reset),
    .en    (en),
    .a     (a),
    .b     (b),
    .c     (c)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;          // 100 MHz
    end

    // ---------------- Ожидаемые результаты ----------------
    // c = a * b (8x8 -> 16)
    //   пара 0: 1 * 9   = 9
    //   пара 1: 3 * 11  = 33
    //   пара 2: 5 * 13  = 65
    //   пара 3: 7 * 15  = 105
    reg [15:0] exp [0:3];
    integer    k;
    integer    errors;

    task check_c(input integer idx);
        begin
            if (c !== exp[idx]) begin
                errors = errors + 1;
                if (errors <= MAX_PRINT)
                    $display("[ERROR] t=%0t | pair %0d | exp=%h got=%h", // a=%h * b=%h
                    $time, idx, exp[idx], c);
            end
        end
    endtask

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_mul_u8_u8_u16_lat2_chk.vcd");
        $dumpvars(0, vhfastmulb16_mul_u8_u8_u16_lat2_chk_tb);

        errors = 0;
        exp[0] = 16'd9;      // 1 * 9
        exp[1] = 16'd33;     // 3 * 11
        exp[2] = 16'd65;     // 5 * 13
        exp[3] = 16'd105;    // 7 * 15

        // ---- Сброс: 5 тактов ----
        reset = 1'b1; en = 1'b0; a = 8'h00; b = 8'h00;
        repeat (5) @(negedge clk);
            reset = 1'b0;

        // ---- 4 пары подряд, каждая на своём такте ----
        // Результат пары k появляется через 2 такта, поэтому
        // при подаче пары k проверяется результат пары k-2.
        for (k = 0; k < 4; k = k + 1) begin
            @(negedge clk);
            a  = 8'd1 + 2 * k;
            b  = 8'd9 + 2 * k;
            en = 1'b1;
            $display("[%0t] drive pair %0d: a=%0d b=%0d", $time, k, a, b);

            if (k >= 2) begin
                check_c(k - 2);
                $display("[%0t] check pair %0d: c=%0d (exp %0d)",
                $time, k - 2, c, exp[k - 2]);
            end
        end

        // ---- Две оставшиеся проверки ----
        @(negedge clk);
        check_c(2);
        $display("[%0t] check pair 2: c=%0d (exp %0d)", $time, c, exp[2]);

        @(negedge clk);
        check_c(3);
        $display("[%0t] check pair 3: c=%0d (exp %0d)", $time, c, exp[3]);

        // ---- Тест en=0: выход должен сохранить значение ----
        @(negedge clk);
        en = 1'b0;
        $display("[%0t] disable en, expect hold", $time);
        repeat (3) @(negedge clk);
            $display("[%0t] after 3 clk, c=%0d (should hold)", $time, c);
        if (c !== exp[3]) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold | exp=%h got=%h", $time, exp[3], c);
        end

        // ---- Итог ----
        $display("---------------------------------------------");
        $display("Errors: %0d", errors);
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
