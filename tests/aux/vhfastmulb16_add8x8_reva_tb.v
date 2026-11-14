`timescale 1ns/1ps
// =============================================================
// Testbench для vhfastmulb16_add8x8
//   c = a + b - 127 (9 бит, беззнаковая арифметика)
//   латентность 2 такта, синхронные en/reset
// =============================================================

module vhfastmulb16_add8x8_tb;

    localparam MAX_PRINT = 10;      // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [7:0]  a;
    reg  [7:0]  b;
    wire [8:0]  c;

    vhfastmulb16_add8x8_lat2 dut (
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

    // ---------------- Scoreboard ----------------
    integer   checked;
    integer   errors;
    integer   i, j;
    reg [8:0] exp_p1;                   // ожидание для входа, поданного 1 такт назад
    reg [8:0] exp_p2;                   // ожидание для текущего значения c
    reg [8:0] held;

    // c = a + b - 127 в 9-битной беззнаковой арифметике (mod 512)
    function [8:0] calc(input [7:0] na, input [7:0] nb);
        begin
            calc = {1'b0, na} + {1'b0, nb} - 9'd127;
        end
    endfunction

    task check_c(input [8:0] expct);
        begin
            checked = checked + 1;
            if (c !== expct) begin
                errors = errors + 1;
                if (errors <= MAX_PRINT)
                    $display("[ERROR] t=%0t | exp=%h got=%h", $time, expct, c);
            end
        end
    endtask

    // Один такт: проверить выход, сдвинуть ожидания, подать новый вектор
    task step(input [7:0] na, input [7:0] nb, input do_check);
        begin
            @(negedge clk);
            if (do_check) check_c(exp_p2);
            exp_p2 = exp_p1;
            exp_p1 = calc(na, nb);
            a  = na;
            b  = nb;
            en = 1'b1;
        end
    endtask

    // ---------------- Directed corner cases ----------------
    reg [7:0] dir_a [0:9];
    reg [7:0] dir_b [0:9];

    initial begin
        dir_a[0]=8'h00; dir_b[0]=8'h00;  // 385 (wrap)
        dir_a[1]=8'h00; dir_b[1]=8'hFF;  // 128
        dir_a[2]=8'hFF; dir_b[2]=8'h00;  // 128
        dir_a[3]=8'hFF; dir_b[3]=8'hFF;  // 383
        dir_a[4]=8'h7F; dir_b[4]=8'h7F;  // 127
        dir_a[5]=8'h80; dir_b[5]=8'h80;  // 129
        dir_a[6]=8'h01; dir_b[6]=8'h01;  // 387 (wrap)
        dir_a[7]=8'h7F; dir_b[7]=8'h00;  // 0
        dir_a[8]=8'h00; dir_b[8]=8'h7F;  // 0
        dir_a[9]=8'hFE; dir_b[9]=8'hFF;  // 382
    end

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_add8x8_reva.vcd");
        $dumpvars(0, vhfastmulb16_add8x8_tb);

        checked = 0;
        errors  = 0;
        exp_p1  = 9'd0;
        exp_p2  = 9'd0;

        // ---- Сброс: 5 тактов ----
        reset = 1'b1; en = 1'b0; a = 8'h00; b = 8'h00;
        repeat (5) @(negedge clk);
        reset = 1'b0;

        // ---- Тест 0: сразу после сброса c == 0 ----
        @(negedge clk);
        check_c(9'd0);

        // ---- Прогрев конвейера (2 такта) ----
        step(8'h00, 8'h00, 1'b0);
        step(8'h00, 8'h00, 1'b0);

        // ---- Тест 1: directed corner cases ----
        for (i = 0; i < 10; i = i + 1)
            step(dir_a[i], dir_b[i], 1'b1);

        // ---- Тест 2: исчерпывающий 256 x 256 = 65536 векторов ----
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1)
                step(i, j, 1'b1);

        // ---- Тест 3: en=0 -> выход держится ----
        step(8'h12, 8'h34, 1'b0);
        step(8'h00, 8'h00, 1'b0);
        en = 1'b0;        // отключить enable до следующего posedge, чтобы c держало значение
        @(negedge clk);
        held = c;
        a  = 8'hAA;
        b  = 8'h55;
        en = 1'b0;
        repeat (4) @(negedge clk);
        if (c !== held) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold | exp=%h got=%h", $time, held, c);
        end
        en = 1'b1;

        // ---- Тест 4: reset обнуляет выход (приоритет над en) ----
        step(8'h55, 8'h66, 1'b0);
        step(8'h77, 8'h88, 1'b0);
        @(negedge clk);
        reset = 1'b1;
        en    = 1'b1;
        a     = 8'h99;
        b     = 8'hBB;
        @(negedge clk);
        check_c(9'd0);
        @(negedge clk);
        check_c(9'd0);
        reset = 1'b0;
        en    = 1'b0;

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
        #5000000;
        $display("[ERROR] Testbench timeout!");
        $finish;
    end

endmodule
