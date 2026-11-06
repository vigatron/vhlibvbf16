`timescale 1ns/1ps
// =============================================================
// Визуализационный тестбенч для vhfastmulb16_sign
// Проверка каскадного конвейера latency 1/2/3
// =============================================================

module vhfastmulb16_sign_tb;

    localparam integer N         = 16;  // число тестовых векторов
    localparam integer MAX_LAT   = 3;   // максимальная latency
    localparam integer MAX_PRINT = 10;

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg         signa;
    reg         signb;

    wire        signc_lat1;
    wire        signc_lat2;
    wire        signc_lat3;

    vhfastmulb16_sign uut (
        .clk        (clk),
        .reset      (reset),
        .en         (en),
        .signa      (signa),
        .signb      (signb),
        .signc_lat1 (signc_lat1),
        .signc_lat2 (signc_lat2),
        .signc_lat3 (signc_lat3)
    );

    // ---------------- Тестовые векторы ----------------
    // Перебор всех комбинаций signa/signb + смены знаков
    reg sa [0:N-1];
    reg sb [0:N-1];

    initial begin
        // Базовые комбинации
        sa[ 0] = 0; sb[ 0] = 0;  // 0^0=0
        sa[ 1] = 0; sb[ 1] = 1;  // 0^1=1
        sa[ 2] = 1; sb[ 2] = 0;  // 1^0=1
        sa[ 3] = 1; sb[ 3] = 1;  // 1^1=0
        // Повтор для проверки конвейера
        sa[ 4] = 0; sb[ 4] = 0;
        sa[ 5] = 1; sb[ 5] = 1;
        sa[ 6] = 0; sb[ 6] = 1;
        sa[ 7] = 1; sb[ 7] = 0;
        // Смена знаков по одному
        sa[ 8] = 0; sb[ 8] = 0;
        sa[ 9] = 1; sb[ 9] = 0;
        sa[10] = 1; sb[10] = 1;
        sa[11] = 0; sb[11] = 1;
        sa[12] = 0; sb[12] = 0;
        // Длинная последовательность
        sa[13] = 1; sb[13] = 0;
        sa[14] = 1; sb[14] = 1;
        sa[15] = 0; sb[15] = 1;
    end

    // Ожидаемый XOR
    function exp_sign(input a, input b);
        exp_sign = a ^ b;
    endfunction

    integer k;
    integer errors;

    task check_lat1(input integer idx);
        reg exp;
        begin
            if (idx >= 0 && idx < N) begin
                exp = exp_sign(sa[idx], sb[idx]);
                if (signc_lat1 !== exp) begin
                    errors = errors + 1;
                    if (errors <= MAX_PRINT)
                        $display("[ERROR LAT1] t=%0t | idx=%0d | sa=%b sb=%b | exp=%b got=%b",
                                 $time, idx, sa[idx], sb[idx], exp, signc_lat1);
                end
            end
        end
    endtask

    task check_lat2(input integer idx);
        reg exp;
        begin
            if (idx >= 0 && idx < N) begin
                exp = exp_sign(sa[idx], sb[idx]);
                if (signc_lat2 !== exp) begin
                    errors = errors + 1;
                    if (errors <= MAX_PRINT)
                        $display("[ERROR LAT2] t=%0t | idx=%0d | sa=%b sb=%b | exp=%b got=%b",
                                 $time, idx, sa[idx], sb[idx], exp, signc_lat2);
                end
            end
        end
    endtask

    task check_lat3(input integer idx);
        reg exp;
        begin
            if (idx >= 0 && idx < N) begin
                exp = exp_sign(sa[idx], sb[idx]);
                if (signc_lat3 !== exp) begin
                    errors = errors + 1;
                    if (errors <= MAX_PRINT)
                        $display("[ERROR LAT3] t=%0t | idx=%0d | sa=%b sb=%b | exp=%b got=%b",
                                 $time, idx, sa[idx], sb[idx], exp, signc_lat3);
                end
            end
        end
    endtask

    // ---------------- Clock 100 MHz ----------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---------------- RESET ----------------
    initial begin
        reset = 1'b1;
        en    = 1'b0;
        signa = 1'b0;
        signb = 1'b0;
        repeat (5) @(negedge clk);
        reset = 1'b0;
    end

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_sign.vcd");
        $dumpvars(0, vhfastmulb16_sign_tb);

        errors = 0;

        @(negedge reset);
        repeat (5) @(negedge clk);

        // Подача векторов и проверка в конвейере
        // k = 0..N+MAX_LAT-1
        for (k = 0; k < N + MAX_LAT; k = k + 1) begin
            @(posedge clk); #1;

            if (k < N) begin
                signa = sa[k];
                signb = sb[k];
                en    = 1'b1;
                $display("[%0t] drive %0d: signa=%b signb=%b -> exp=%b",
                         $time, k, sa[k], sb[k], exp_sign(sa[k], sb[k]));
            end else begin
                // Flush phase: en=1 чтобы допрогнать хвост конвейера,
                // но входы не меняем
                en = 1'b1;
            end

            // Проверки с учётом latency
            if (k >= 1) check_lat1(k - 1);
            if (k >= 2) check_lat2(k - 2);
            if (k >= 3) check_lat3(k - 3);
        end

        // ---- en=0 hold: выходы должны сохранять последние значения ----
        en = 1'b0;
        repeat (4) @(posedge clk); #1;
        $display("[%0t] en=0 hold check", $time);
        // Последний вектор был k=N-1, его latency3 проверяется на k=N+2
        // На этом моменте все выходы должны держать значение последнего вектора
        if (signc_lat1 !== exp_sign(sa[N-1], sb[N-1])) begin
            errors = errors + 1;
            $display("[ERROR HOLD LAT1] t=%0t exp=%b got=%b", $time, exp_sign(sa[N-1], sb[N-1]), signc_lat1);
        end
        if (signc_lat2 !== exp_sign(sa[N-1], sb[N-1])) begin
            errors = errors + 1;
            $display("[ERROR HOLD LAT2] t=%0t exp=%b got=%b", $time, exp_sign(sa[N-1], sb[N-1]), signc_lat2);
        end
        if (signc_lat3 !== exp_sign(sa[N-1], sb[N-1])) begin
            errors = errors + 1;
            $display("[ERROR HOLD LAT3] t=%0t exp=%b got=%b", $time, exp_sign(sa[N-1], sb[N-1]), signc_lat3);
        end

        // ---- Reset в работе ----
        $display("[%0t] asserting reset", $time);
        reset = 1'b1;
        en    = 1'b1; // en игнорируется при reset
        signa = 1'b1;
        signb = 1'b1;
        repeat (3) @(posedge clk); #1;
        if (signc_lat1 !== 1'b0 || signc_lat2 !== 1'b0 || signc_lat3 !== 1'b0) begin
            errors = errors + 1;
            $display("[ERROR RESET] t=%0t lat1=%b lat2=%b lat3=%b", $time, signc_lat1, signc_lat2, signc_lat3);
        end
        reset = 1'b0;
        repeat (2) @(posedge clk); #1;

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
        #2000000;
        $display("[ERROR] Testbench timeout!");
        $finish;
    end

endmodule