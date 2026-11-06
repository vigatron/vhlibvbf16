`timescale 1ns/1ps
// =============================================================
// Визуализационный тестбенч для vhfastmulb16_mul4x4
//   4 пары чисел подаются подряд, каждый такт новая пара
//   латентность результата 1 такт
// =============================================================

module vhfastmulb16_mul4x4_chk_tb;

    localparam MAX_PRINT = 10;      // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [3:0]  a;
    reg  [3:0]  b;
    wire [7:0]  c;

    vhfastmulb16_mul4x4 uut (
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

    // ---------------- Тестовые данные ----------------
    // c = a * b (4x4 -> 8)
    //   пара 0: 3  * 5  = 15
    //   пара 1: 7  * 9  = 63
    //   пара 2: 10 * 11 = 110
    //   пара 3: 15 * 15 = 225
    reg [3:0] a_vals [0:3];
    reg [3:0] b_vals [0:3];
    reg [7:0] exp    [0:3];

    integer k;
    integer errors;

    task check_c(input integer idx);
        begin
            if (c !== exp[idx]) begin
                errors = errors + 1;
                if (errors <= MAX_PRINT)
                    $display("[ERROR] t=%0t | pair %0d | exp=%h got=%h",
                             $time, idx, exp[idx], c);
            end
        end
    endtask

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_mul4x4_chk.vcd");
        $dumpvars(0, vhfastmulb16_mul4x4_chk_tb);

        errors = 0;

        a_vals[0] = 4'd3;  b_vals[0] = 4'd5;  exp[0] = 8'd15;
        a_vals[1] = 4'd7;  b_vals[1] = 4'd9;  exp[1] = 8'd63;
        a_vals[2] = 4'd10; b_vals[2] = 4'd11; exp[2] = 8'd110;
        a_vals[3] = 4'd15; b_vals[3] = 4'd15; exp[3] = 8'd225;

        // ---- Сброс: 5 тактов ----
        reset = 1'b1; en = 1'b0; a = 4'h0; b = 4'h0;
        repeat (5) @(negedge clk);
        reset = 1'b0;

        // ---- 4 пары подряд, каждая на своём такте ----
        // Результат пары k появляется через 1 такт, поэтому
        // при подаче пары k проверяется результат пары k-1.
        for (k = 0; k < 4; k = k + 1) begin
            @(negedge clk);
            a  = a_vals[k];
            b  = b_vals[k];
            en = 1'b1;
            $display("[%0t] drive pair %0d: a=%0d b=%0d", $time, k, a, b);

            if (k >= 1) begin
                check_c(k - 1);
                $display("[%0t] check pair %0d: c=%0d (exp %0d)",
                         $time, k - 1, c, exp[k - 1]);
            end
        end

        // ---- Последняя проверка ----
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
