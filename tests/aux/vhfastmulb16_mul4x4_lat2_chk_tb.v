`timescale 1ns/1ps
// =============================================================
// Проверяющий тестбенч для vhfastmulb16_mul4x4_lat2
//   N пар чисел подаются подряд, каждый такт новая пара
//   latency = LAT тактов, проверка результата в потоке
//   Дополнительно: hold при en=0 и сброс
// =============================================================

module vhfastmulb16_mul4x4_lat2_chk_tb;

    localparam integer N         = 12;  // число тестовых пар
    localparam integer LAT       = 2;   // latency DUT, тактов
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [3:0]  a;
    reg  [3:0]  b;
    wire [7:0]  c;

    vhfastmulb16_mul4x4_lat2 uut (
        .clk   (clk),
        .reset (reset),
        .en    (en),
        .a     (a),
        .b     (b),
        .c     (c)
    );

    // ---------------- Тестовые векторы ----------------
    // Крайние значения (0, 1, 15) и типичные произведения 4x4.
    reg [3:0] va [0:N-1];
    reg [3:0] vb [0:N-1];

    initial begin
        va[ 0] = 4'd0;  vb[ 0] = 4'd0;   // 0
        va[ 1] = 4'd0;  vb[ 1] = 4'd15;  // 0
        va[ 2] = 4'd15; vb[ 2] = 4'd0;   // 0
        va[ 3] = 4'd1;  vb[ 3] = 4'd1;   // 1
        va[ 4] = 4'd3;  vb[ 4] = 4'd5;   // 15
        va[ 5] = 4'd7;  vb[ 5] = 4'd9;   // 63
        va[ 6] = 4'd10; vb[ 6] = 4'd11;  // 110
        va[ 7] = 4'd15; vb[ 7] = 4'd15;  // 225
        va[ 8] = 4'd2;  vb[ 8] = 4'd15;  // 30
        va[ 9] = 4'd8;  vb[ 9] = 4'd8;   // 64
        va[10] = 4'd5;  vb[10] = 4'd12;  // 60
        va[11] = 4'd13; vb[11] = 4'd7;   // 91
    end

    // Ожидаемое произведение (оператор '*' разрешён только в TB)
    function [7:0] exp_mul(input [3:0] x, input [3:0] y);
        exp_mul = {4'b0000, x} * {4'b0000, y};
    endfunction

    integer k;
    integer errors;

    task check(input integer idx);
        begin
            if (c !== exp_mul(va[idx], vb[idx])) begin
                errors = errors + 1;
                if (errors <= MAX_PRINT)
                    $display("[ERROR] t=%0t | pair %0d | a=%0d b=%0d | exp=%0d got=%0d",
                             $time, idx, va[idx], vb[idx],
                             exp_mul(va[idx], vb[idx]), c);
            end
            $display("[%0t] pair %0d: a=%0d b=%0d -> c=%0d (exp %0d)",
                     $time, idx, va[idx], vb[idx], c,
                     exp_mul(va[idx], vb[idx]));
        end
    endtask

    // ---------------- Clock generation 100 MHz ----------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---------------- RESET: удерживаем 5 тактов ----------------
    initial begin
        reset = 1'b1;
        en    = 1'b0;
        a     = 4'h0;
        b     = 4'h0;

        repeat (5) @(negedge clk);
        reset = 1'b0;
    end

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_mul4x4_lat2_chk.vcd");
        $dumpvars(0, vhfastmulb16_mul4x4_lat2_chk_tb);

        errors = 0;

        // Тесты начинаем после снятия reset + 10 тактов
        @(negedge reset);
        repeat (10) @(negedge clk);

        // ---- Подача пар и проверка в конвейере ----
        // В такте k защёлкивается va[k]/vb[k]; результат виден через LAT
        // тактов, поэтому в такте k проверяется пара k-LAT.
        // Последние LAT тактов выталкивают остаток из конвейера.
        for (k = 0; k < N + LAT; k = k + 1) begin
            @(posedge clk); #1;

            if (k < N) begin
                a  = va[k];
                b  = vb[k];
                en = 1'b1;
                $display("[%0t] drive pair %0d: a=%0d b=%0d",
                         $time, k, va[k], vb[k]);
            end

            if (k >= LAT)
                check(k - LAT);
        end

        // ---- en=0: выход должен сохранять значение ----
        en = 1'b0;
        repeat (3) @(posedge clk); #1;
        $display("[%0t] en=0 hold, expect pair %0d", $time, N-1);
        if (c !== exp_mul(va[N-1], vb[N-1])) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold | exp=%0d got=%0d",
                     $time, exp_mul(va[N-1], vb[N-1]), c);
        end

        // ---- reset: выход должен обнулиться ----
        reset = 1'b1;
        @(posedge clk); #1;
        $display("[%0t] reset, expect c=0", $time);
        if (c !== 8'h00) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | reset | exp=00 got=%h", $time, c);
        end
        reset = 1'b0;

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
