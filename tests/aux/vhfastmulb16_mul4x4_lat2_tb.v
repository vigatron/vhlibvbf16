`timescale 1ns/1ps
// =============================================================
// Отладочный тестбенч для vhfastmulb16_mul4x4_lat2
//   Перебор всех 16 x 16 = 256 пар (a, b)
//   Конвейер на 2 такта: проверка результата в потоке (LAT = 2)
//   Дополнительно: hold при en=0 и сброс через конвейер
// =============================================================

module vhfastmulb16_mul4x4_lat2_tb;

    localparam integer N   = 256;  // число тестовых пар
    localparam integer LAT = 2;    // latency DUT, тактов

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [3:0]  a;
    reg  [3:0]  b;
    wire [7:0]  c;

    vhfastmulb16_mul4x4_lat2 dut (
        .clk   (clk),
        .reset (reset),
        .en    (en),
        .a     (a),
        .b     (b),
        .c     (c)
    );

    // ---------------- Генерация тактового сигнала 100MHz ----------------
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

    // ---------------- Дамп waveforms ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_mul4x4_lat2.vcd");
        $dumpvars(0, vhfastmulb16_mul4x4_lat2_tb);
    end

    // ---------------- Ожидаемый результат ----------------
    // В тестбенче оператор '*' разрешён (только в DUT он запрещён).
    function [7:0] expected_of(input integer idx);
        expected_of = (idx / 16) * (idx % 16);
    endfunction

    // ---------------- Проверка пары ----------------
    task check_pair(input integer idx);
        begin
            if (c !== expected_of(idx)) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("[ERROR] t=%0t | a=%0d b=%0d | exp=%0d got=%0d",
                             $time, idx / 16, idx % 16, expected_of(idx), c);
            end
            checked = checked + 1;
        end
    endtask

    integer k;
    integer errors;
    integer checked;
    reg [7:0] held;

    // ---------------- Основной сценарий ----------------
    initial begin
        errors  = 0;
        checked = 0;

        // Тесты начинаем после снятия reset + 10 тактов
        @(negedge reset);
        repeat (10) @(negedge clk);

        // ---- Потоковая подача и проверка ----
        // Пара, поданная в такте k, появляется на выходе через LAT тактов,
        // поэтому в такте k проверяется пара k-LAT.
        // Последние LAT тактов выталкивают остаток из конвейера.
        for (k = 0; k < N + LAT; k = k + 1) begin
            @(posedge clk); #1;

            if (k < N) begin
                a  = k / 16;
                b  = k % 16;
                en = 1'b1;
            end

            if (k >= LAT)
                check_pair(k - LAT);
        end

        // ---- en=0: выход должен сохранять значение ----
        held = c;
        en   = 1'b0;
        repeat (3) @(posedge clk); #1;
        if (c !== held) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold | exp=%0d got=%0d",
                     $time, held, c);
        end

        // ---- reset: выход должен обнулиться (в т.ч. через конвейер) ----
        reset = 1'b1;
        @(posedge clk); #1;
        if (c !== 8'h00) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | reset | exp=00 got=%h", $time, c);
        end
        reset = 1'b0;

        // ---- Итог ----
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
