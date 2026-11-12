`timescale 1ns/1ps
// =============================================================
// Визуализационный тестбенч для vhfastmulb16_except_lat2
//   N пар чисел подаются подряд, каждый такт новая пара
//   latency = LAT тактов, проверка результата в потоке
// =============================================================

module vhfastmulb16_except_lat2_tb;

    localparam integer N         = 24;  // число тестовых пар
    localparam integer LAT       = 2;   // latency DUT, тактов
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [15:0] a;
    reg  [15:0] b;

    wire [15:0] c;
    wire        exval;
    wire        ex_z;
    wire        ex_inf;
    wire        ex_nan;

    // Все выходные флаги одним вектором для компактной проверки
    wire [3:0] flags = {exval, ex_z, ex_inf, ex_nan};

    vhfastmulb16_except_lat2 uut (
    .clk    (clk),
    .reset  (reset),
    .en     (en),
    .a      (a),
    .b      (b),
    .c      (c),
    .exval  (exval),
    .ex_z   (ex_z),
    .ex_inf (ex_inf),
    .ex_nan (ex_nan)
    );

    // ---------------- Тестовые векторы ----------------
    reg [15:0] va [0:N-1];
    reg [15:0] vb [0:N-1];

    initial begin
        // normal
        va[ 0] = 16'h3F80; vb[ 0] = 16'h3F80; // 1.0 * 1.0
        va[ 1] = 16'h4000; vb[ 1] = 16'h4060; // 2.0 * 3.5
        // zero
        va[ 2] = 16'h3F80; vb[ 2] = 16'h0000; // 1.0 * +0
        va[ 3] = 16'h8000; vb[ 3] = 16'h3F80; // -0 * 1.0
        va[ 4] = 16'h0000; vb[ 4] = 16'h0000; // +0 * +0
        // infinity
        va[ 5] = 16'h7F80; vb[ 5] = 16'h4000; // +Inf * 2.0
        va[ 6] = 16'hFF80; vb[ 6] = 16'h4000; // -Inf * 2.0
        va[ 7] = 16'h7F80; vb[ 7] = 16'hFF80; // +Inf * -Inf
        // NaN
        va[ 8] = 16'h7FC0; vb[ 8] = 16'h40A0; // NaN * 5.0
        va[ 9] = 16'h7FC0; vb[ 9] = 16'h7F80; // NaN * +Inf
        // Inf * 0 -> NaN
        va[10] = 16'h7F80; vb[10] = 16'h0000; // +Inf * +0
        va[11] = 16'h0000; vb[11] = 16'hFF80; // +0 * -Inf
        // NaN с ненулевой дробной частью
        va[12] = 16'h7FFF; vb[12] = 16'h3F80; // NaN(frac=7F) * 1.0
        // минимальное нормальное число и субнормали (FTZ)
        va[13] = 16'h0080; vb[13] = 16'h3F80; // 2^-126 * 1.0
        va[14] = 16'h0001; vb[14] = 16'h3F80; // субнормаль * 1.0 -> 0 (FTZ)
        va[15] = 16'h0001; vb[15] = 16'h7F80; // субнормаль * Inf -> NaN (FTZ)
        // отрицательные normal
        va[16] = 16'h4080; vb[16] = 16'hBF80; // 4.0 * -1.0
        // Inf * 0 (отрицательный ноль)
        va[17] = 16'hFF80; vb[17] = 16'h0000; // -Inf * +0
        // Inf * Inf
        va[18] = 16'h7F80; vb[18] = 16'h7F80; // +Inf * +Inf
        // NaN * zero
        va[19] = 16'h7FC1; vb[19] = 16'h0000; // NaN * +0
        // normal: степени двойки
        va[20] = 16'h3C00; vb[20] = 16'h3C00; // 2^-7 * 2^-7 = 2^-14
        // максимальное конечное * 1.0
        va[21] = 16'h7F7F; vb[21] = 16'h3F80; // max finite * 1.0
        // Inf * NaN
        va[22] = 16'h7F80; vb[22] = 16'h7FC0; // +Inf * NaN
        // zero * NaN
        va[23] = 16'h0000; vb[23] = 16'h7FC0; // +0 * NaN
    end

    // Ожидаемые флаги по спецификации DUT:
    // {exval, ex_z, ex_inf, ex_nan}
    function [3:0] exp_flags(input [15:0] x, input [15:0] y);
        reg x_nan, x_inf, x_zero;
        reg y_nan, y_inf, y_zero;
        reg r_nan, r_inf, r_zero;
        begin
            x_nan  = (x[14:7] == 8'hFF) && (x[6:0] != 7'h00);
            x_inf  = (x[14:7] == 8'hFF) && (x[6:0] == 7'h00);
            x_zero = (x[14:7] == 8'h00);  // субнормали трактуются как 0 (FTZ)

            y_nan  = (y[14:7] == 8'hFF) && (y[6:0] != 7'h00);
            y_inf  = (y[14:7] == 8'hFF) && (y[6:0] == 7'h00);
            y_zero = (y[14:7] == 8'h00);

            r_nan  = x_nan || y_nan || (x_inf && y_zero) || (y_inf && x_zero);
            r_inf  = !r_nan && (x_inf || y_inf);
            r_zero = !r_nan && !r_inf && (x_zero || y_zero);

            exp_flags = {(r_nan | r_inf | r_zero),  // exval
                r_zero,                    // ex_z
                r_inf,                     // ex_inf
                r_nan};                    // ex_nan
        end
    endfunction

    // Ожидаемый c: только спецзначение, при normal — 0.
    // Знак всегда 0 (его формирует vhfastmulb16_mul_bf16_bf16_bf16).
    // NaN payload preservation: если x=NaN — берём payload из x, иначе из y
    // Quiet bit (bit 6) = 1
    function [15:0] exp_c(input [15:0] x, input [15:0] y);
        reg [3:0] f;
        begin
            f = exp_flags(x, y);
            if (f[0]) begin
                if ((x[14:7] == 8'hFF) && (x[6:0] != 7'h00))
                    exp_c = { 1'b0, 8'hFF, 1'b1, x[5:0] };  // x is NaN
                else
                    exp_c = { 1'b0, 8'hFF, 1'b1, y[5:0] };  // y is NaN
            end
            else if (f[1]) exp_c = 16'h7F80;  // +Inf
            else           exp_c = 16'h0000;  // normal или zero
        end
    endfunction

    integer k;
    integer checked;
    integer errors;

    task check(input integer idx);
        reg [3:0]  want_flags;
        reg [15:0] want_c;
        begin
            checked = checked + 1;
            want_flags = exp_flags(va[idx], vb[idx]);
            want_c     = exp_c(va[idx], vb[idx]);

            if ((flags !== want_flags) || (c !== want_c)) begin
                errors = errors + 1;
                if (errors <= MAX_PRINT) begin
                    $display("[ERROR] t=%0t | pair %0d | a=%h b=%h",
                    $time, idx, va[idx], vb[idx]);
                    $display("        exp: c=%h flags=%b | got: c=%h flags=%b",
                    want_c, want_flags, c, flags);
                end
            end

            $display("[%0t] pair %0d: a=%h b=%h -> c=%h exval=%b ex_z=%b ex_inf=%b ex_nan=%b",
            $time, idx, va[idx], vb[idx], c, exval, ex_z, ex_inf, ex_nan);
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
        a     = 16'h0000;
        b     = 16'h0000;

        repeat (5) @(negedge clk);
            reset = 1'b0;
    end

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_except_lat2.vcd");
        $dumpvars(0, vhfastmulb16_except_lat2_tb);

        checked = 0;
        errors  = 0;

        // Тесты начинаем после снятия reset + 10 тактов
        @(negedge reset);
        repeat (10) @(negedge clk);

        // ---- Подача пар и проверка в конвейере ----
        // В такте k защёлкивается ve[k]; результат виден через LAT тактов,
        // поэтому в такте k проверяется пара k-LAT.
        // Последние LAT тактов выталкивают остаток из конвейера.
        for (k = 0; k < N + LAT; k = k + 1) begin
            @(posedge clk); #1;

            if (k < N) begin
                a  = va[k];
                b  = vb[k];
                en = 1'b1;
            end

            if (k >= LAT)
                check(k - LAT);
        end

        // ---- en=0: конвейер и выходы должны замереть ----
        // Подаём новый NaN, который дал бы другой результат, если бы en
        // не блокировал обновление.
        en = 1'b0;
        a  = 16'h7FC0;  // NaN
        b  = 16'h3F80;
        repeat (4) @(posedge clk); #1;
            $display("[%0t] en=0 hold, expect pair %0d", $time, N-1);
        if ((flags !== exp_flags(va[N-1], vb[N-1])) ||
            (c !== exp_c(va[N-1], vb[N-1]))) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold | exp: c=%h flags=%b got: c=%h flags=%b",
            $time, exp_c(va[N-1], vb[N-1]),
            exp_flags(va[N-1], vb[N-1]), c, flags);
        end

        // ---- en=1: новый отсчёт должен пройти через конвейер ----
        en = 1'b1;
        repeat (LAT) @(posedge clk); #1;
            $display("[%0t] en=1 resume, expect NaN", $time);
        if ((flags !== exp_flags(16'h7FC0, 16'h3F80)) ||
            (c !== exp_c(16'h7FC0, 16'h3F80))) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=1 resume | exp: c=%h flags=%b got: c=%h flags=%b",
            $time, exp_c(16'h7FC0, 16'h3F80),
            exp_flags(16'h7FC0, 16'h3F80), c, flags);
        end

        // ---- reset имеет приоритет над en ----
        // На входах уже NaN, en=1; reset должен обнулить выходы.
        reset = 1'b1;
        @(posedge clk); #1;   // reset применён
        if ((flags !== 4'b0000) || (c !== 16'h0000)) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | reset priority | exp: c=0000 flags=0000 got: c=%h flags=%b",
            $time, c, flags);
        end
        reset = 1'b0;
        en    = 1'b0;

        // ---- 10 nop clocks в конце ----
        repeat (10) @(posedge clk);

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