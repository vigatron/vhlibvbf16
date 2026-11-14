`timescale 1ns/1ps
// =============================================================
// Визуализационный тестбенч для vhfastmulb16_flags_lat1
//   N пар чисел подаются подряд, каждый такт новая пара
//   latency = LAT тактов, проверка результата в потоке
// =============================================================

module vhfastmulb16_flags_lat1_tb;

    localparam integer N         = 12;  // число тестовых пар
    localparam integer LAT       = 1;   // latency DUT, тактов
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [7:0]  inexp;
    reg  [7:0]  infrc;

    wire        flag_exp_z;
    wire        flag_exp_s;
    wire        flag_exp_f;
    wire        flag_frc_z;
    wire        flag_frc_nz;

    // Все выходные флаги одним вектором для компактной проверки
    wire [4:0] flags = {flag_exp_z, flag_exp_s, flag_exp_f,
                        flag_frc_z, flag_frc_nz};

    vhfastmulb16_flags_lat1 uut (
        .clk        (clk),
        .reset      (reset),
        .en         (en),
        .inexp      (inexp),
        .infrc      (infrc),
        .flag_exp_z (flag_exp_z),
        .flag_exp_s (flag_exp_s),
        .flag_exp_f (flag_exp_f),
        .flag_frc_z (flag_frc_z),
        .flag_frc_nz(flag_frc_nz)
    );

    // ---------------- Тестовые векторы ----------------
    // 0x00/0xFF — крайние позиции; 0x01/0x10/0x0F/0xF0
    // проверяют независимость старшего и младшего полубайта.
    reg [7:0] ve [0:N-1];
    reg [7:0] vf [0:N-1];

    initial begin
        ve[ 0] = 8'h00; vf[ 0] = 8'h00;
        ve[ 1] = 8'h00; vf[ 1] = 8'h01;
        ve[ 2] = 8'h00; vf[ 2] = 8'hFF;
        ve[ 3] = 8'h01; vf[ 3] = 8'h00;
        ve[ 4] = 8'h0F; vf[ 4] = 8'h0F;
        ve[ 5] = 8'h10; vf[ 5] = 8'h10;
        ve[ 6] = 8'h7F; vf[ 6] = 8'h80;
        ve[ 7] = 8'h80; vf[ 7] = 8'hF0;
        ve[ 8] = 8'hFE; vf[ 8] = 8'hFE;
        ve[ 9] = 8'hFF; vf[ 9] = 8'h00;
        ve[10] = 8'hFF; vf[10] = 8'hFF;
        ve[11] = 8'h01; vf[11] = 8'hFF;
    end

    // Ожидаемые флаги по спецификации DUT
    function [4:0] exp_flags(input [7:0] e, input [7:0] f);
        exp_flags = {(e == 8'd0),                  // exp == 0
                     (e >  8'd0) && (e < 8'd255),  // 1..254
                     (e == 8'd255),                // exp == 255
                     (f == 8'd0),                  // frac == 0
                     (f != 8'd0)};                 // frac != 0
    endfunction

    integer k;
    integer errors;

    task check(input integer idx);
        begin
            if (flags !== exp_flags(ve[idx], vf[idx])) begin
                errors = errors + 1;
                if (errors <= MAX_PRINT)
                    $display("[ERROR] t=%0t | pair %0d | inexp=%02h infrc=%02h | exp=%b got=%b",
                             $time, idx, ve[idx], vf[idx],
                             exp_flags(ve[idx], vf[idx]), flags);
            end
            $display("[%0t] pair %0d: inexp=%02h infrc=%02h -> exp_z=%b exp_s=%b exp_f=%b frc_z=%b frc_nz=%b",
                     $time, idx, ve[idx], vf[idx],
                     flag_exp_z, flag_exp_s, flag_exp_f, flag_frc_z, flag_frc_nz);
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
        inexp = 8'h00;
        infrc = 8'h00;

        repeat (5) @(negedge clk);
        reset = 1'b0;
    end

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_flags_lat1.vcd");
        $dumpvars(0, vhfastmulb16_flags_lat1_tb);

        errors = 0;

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
                inexp = ve[k];
                infrc = vf[k];
                en    = 1'b1;
                $display("[%0t] drive pair %0d: inexp=%02h infrc=%02h",
                         $time, k, ve[k], vf[k]);
            end

            if (k >= LAT)
                check(k - LAT);
        end

        // ---- en=0: выход должен сохранять значение ----
        en = 1'b0;
        repeat (3) @(posedge clk); #1;
        $display("[%0t] en=0 hold, expect pair %0d", $time, N-1);
        if (flags !== exp_flags(ve[N-1], vf[N-1])) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold | exp=%b got=%b",
                     $time, exp_flags(ve[N-1], vf[N-1]), flags);
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