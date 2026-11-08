`timescale 1ns/1ps
// =============================================================
// Тестбенч для vhfastmulb16_f32_lat4
//   N пар чисел подаются подряд, каждый такт новая пара
//   latency = LAT = 4 такта, проверка результата в потоке
//   Тестовые векторы: docs/test_values_bf16_bf16_f32.json
//   (BF16 x BF16 -> F32 exact product, 16 основных + 4 extended)
//   + 12 directed-векторов для F32 subnormal/RTZ и граничных случаев.
//   Ожидаемый результат = колонка F32 (exact product).
//   Проверка NaN/Inf/Zero: NaN in -> qNaN 0x7FC00000;
//   Inf*0 -> qNaN; Inf*finite -> Inf (XOR sign);
//   zero*finite -> zero (XOR sign).
//   F32 subnormal результаты усекаются (RTZ, без округления).
//   BF16 subnormal входы НЕ flush-ятся в ноль.
// =============================================================

module vhfastmulb16_f32_lat4_tb;

    localparam integer N         = 32;  // число тестовых пар (16 + 4 extended + 12 directed)
    localparam integer LAT       = 4;   // latency DUT, тактов
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно
    localparam integer EXP_CHECK = 1;   // 1 = проверять функцию

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [15:0] ina;
    reg  [15:0] inb;

    wire [31:0] outc;

    vhfastmulb16_f32_lat4 uut (
        .clk   (clk),
        .reset (reset),
        .en    (en),
        .ina   (ina),
        .inb   (inb),
        .outc  (outc)
    );

    // ---------------- Тестовые векторы ----------------
    // Источник: docs/test_values_bf16_bf16_f32.json
    // ve[k] = ожидаемый результат (колонка F32, exact product)
    reg [15:0] va [0:N-1];
    reg [15:0] vb [0:N-1];
    reg [31:0] ve [0:N-1];

    initial begin
        // ---- test_vectors 1..16 ----
        va[ 0] = 16'h3F80; vb[ 0] = 16'h3F80; ve[ 0] = 32'h3F800000; //  1: 1.0 * 1.0 = 1.0
        va[ 1] = 16'h4000; vb[ 1] = 16'h4060; ve[ 1] = 32'h40E00000; //  2: 2.0 * 3.5 = 7.0
        va[ 2] = 16'hBFC0; vb[ 2] = 16'h4080; ve[ 2] = 32'hC0C00000; //  3: -1.5 * 4.0 = -6.0
        va[ 3] = 16'h3F00; vb[ 3] = 16'h3E80; ve[ 3] = 32'h3E000000; //  4: 0.5 * 0.25 = 0.125
        va[ 4] = 16'h4300; vb[ 4] = 16'h3C00; ve[ 4] = 32'h3F800000; //  5: 128.0 * 0.0078125 = 1.0
        va[ 5] = 16'h4049; vb[ 5] = 16'h4000; ve[ 5] = 32'h40C90000; //  6: 3.140625 * 2.0 = 6.28125
        va[ 6] = 16'hC2C8; vb[ 6] = 16'hBDCD; ve[ 6] = 32'h41202800; //  7: -100.0 * -0.10009765625 = 10.009765625
        va[ 7] = 16'h4120; vb[ 7] = 16'h3E9A; ve[ 7] = 32'h40408000; //  8: 10.0 * 0.30078125 = 3.0078125
        va[ 8] = 16'h3F80; vb[ 8] = 16'h0000; ve[ 8] = 32'h00000000; //  9: 1.0 * 0.0 = +0.0
        va[ 9] = 16'h7F80; vb[ 9] = 16'h4000; ve[ 9] = 32'h7F800000; // 10: +Inf * 2.0 = +Inf
        va[10] = 16'hFF80; vb[10] = 16'h7F80; ve[10] = 32'hFF800000; // 11: -Inf * +Inf = -Inf
        va[11] = 16'h7F80; vb[11] = 16'h0000; ve[11] = 32'h7FC00000; // 12: +Inf * 0.0 = qNaN
        va[12] = 16'h7FC0; vb[12] = 16'h40A0; ve[12] = 32'h7FC00000; // 13: NaN * 5.0 = qNaN
        va[13] = 16'h7FC0; vb[13] = 16'h7F80; ve[13] = 32'h7FC00000; // 14: NaN * +Inf = qNaN
        va[14] = 16'h0000; vb[14] = 16'h0000; ve[14] = 32'h00000000; // 15: 0.0 * 0.0 = +0.0
        va[15] = 16'hFF80; vb[15] = 16'h8000; ve[15] = 32'h7FC00000; // 16: -Inf * -0.0 = qNaN
        // ---- extended_vectors 17..20 ----
        va[16] = 16'h7F7F; vb[16] = 16'h7F7F; ve[16] = 32'h7F800000; // 17: max_BF16 * max_BF16 = +Inf (overflow)
        va[17] = 16'h0001; vb[17] = 16'h0001; ve[17] = 32'h00000000; // 18: min_subnorm * min_subnorm = +0.0 (underflow)
        va[18] = 16'h0001; vb[18] = 16'h3F80; ve[18] = 32'h00010000; // 19: min_subnorm * 1.0 -> F32 subnormal
        va[19] = 16'h8000; vb[19] = 16'h3F80; ve[19] = 32'h80000000; // 20: -0.0 * 1.0 = -0.0
        // ---- directed F32 subnormal / RTZ vectors 21..32 ----
        va[20] = 16'h0003; vb[20] = 16'h3700; ve[20] = 32'h00000001; // 21: 3*2^-150 -> 1*2^-149 (RTZ)
        va[21] = 16'h0001; vb[21] = 16'h3700; ve[21] = 32'h00000000; // 22: 2^-150 -> 0 (underflow)
        va[22] = 16'h0001; vb[22] = 16'h3780; ve[22] = 32'h00000001; // 23: 2^-149 -> min F32 subnormal
        va[23] = 16'h0003; vb[23] = 16'h3780; ve[23] = 32'h00000003; // 24: 3*2^-149 -> F32 subnormal
        va[24] = 16'h0001; vb[24] = 16'h7F80; ve[24] = 32'h7F800000; // 25: subnormal * +Inf -> +Inf
        va[25] = 16'h8001; vb[25] = 16'h0000; ve[25] = 32'h80000000; // 26: -subnormal * +0 -> -0
        va[26] = 16'h0001; vb[26] = 16'h7FC0; ve[26] = 32'h7FC00000; // 27: subnormal * NaN -> qNaN
        va[27] = 16'h7F7F; vb[27] = 16'h3F80; ve[27] = 32'h7F7F0000; // 28: max_BF16 * 1.0 -> max F32-range value
        va[28] = 16'h7F7F; vb[28] = 16'h4000; ve[28] = 32'h7F800000; // 29: max_BF16 * 2.0 -> +Inf
        va[29] = 16'h0080; vb[29] = 16'h0080; ve[29] = 32'h00000000; // 30: min_normal^2 = 2^-252 -> 0
        va[30] = 16'h8003; vb[30] = 16'h3700; ve[30] = 32'h80000001; // 31: -3*2^-150 -> -1*2^-149 (RTZ)
        va[31] = 16'h7FC1; vb[31] = 16'h3F80; ve[31] = 32'h7FC00000; // 32: NaN payload -> canonical qNaN
    end

    integer k;
    integer checked;
    integer errors;
    reg [31:0] hold_val;

    task check(input integer idx);
        begin
            checked = checked + 1;
            if (outc !== ve[idx]) begin
                errors = errors + 1;
                if (errors <= MAX_PRINT) begin
                    $display("[ERROR] t=%0t | pair %0d | a=%h b=%h",
                    $time, idx, va[idx], vb[idx]);
                    $display("        exp: outc=%h | got: outc=%h",
                    ve[idx], outc);
                end
            end

            $display("[%0t] pair %0d: a=%h b=%h -> outc=%h",
            $time, idx, va[idx], vb[idx], outc);
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
        ina   = 16'h0000;
        inb   = 16'h0000;

        repeat (5) @(negedge clk);
            reset = 1'b0;
    end

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_f32_lat4.vcd");
        $dumpvars(0, vhfastmulb16_f32_lat4_tb);

        checked = 0;
        errors  = 0;

        // Тесты начинаем после снятия reset + 10 тактов
        @(negedge reset);
        repeat (10) @(negedge clk);

        // ---- reset обнуляет outc ----
        if (outc !== 32'h0000_0000) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | после reset: exp outc=00000000, got outc=%h",
            $time, outc);
        end

        // ---- Подача пар и проверка результата в конвейере ----
        // В такте k защёлкивается va[k]/vb[k]; результат виден через LAT
        // тактов, поэтому в такте k проверяется пара k-LAT.
        // Последние LAT тактов выталкивают остаток из конвейера.
        for (k = 0; k < N + LAT; k = k + 1) begin
            @(posedge clk); #1;

            if (k < N) begin
                ina = va[k];
                inb = vb[k];
                en  = 1'b1;
            end

            if (k >= LAT) begin
                if (EXP_CHECK)
                    check(k - LAT);
                else
                    $display("[%0t] pair %0d: a=%h b=%h -> outc=%h (ожидание %h, проверка отключена EXP_CHECK=0)",
                    $time, k - LAT, va[k - LAT], vb[k - LAT], outc, ve[k - LAT]);
            end
        end

        // ---- en=0: HOLD (outc сохраняет последнее значение) ----
        // Запоминаем значение до подачи нового вектора с en=0:
        // если en корректно блокирует обновление, outc не изменится.
        en = 1'b0;
        ina = 16'h7FC0;  // NaN — при исправном en выход не должен измениться
        inb = 16'h3F80;
        @(posedge clk); #1;
        hold_val = outc;
        repeat (6) @(posedge clk); #1;
            $display("[%0t] en=0 hold: exp outc=%h, got outc=%h",
            $time, hold_val, outc);
        if (outc !== hold_val) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold нарушен: exp outc=%h, got outc=%h",
            $time, hold_val, outc);
        end

        // ---- en=1: новый вектор должен пройти через конвейер ----
        // Вектор #12 (+Inf * 0.0 -> qNaN 7FC00000)
        en  = 1'b1;
        ina = 16'h7F80;
        inb = 16'h0000;
        if (EXP_CHECK) begin
            repeat (LAT) @(posedge clk); #1;
            // после LAT тактов на выходе должен появиться результат
            // последнего принятого вектора (маскируется потоком — просто
            // сверяем с ve[11], повторная проверка вектора 12)
            checked = checked + 1;
            if (outc !== ve[11]) begin
                errors = errors + 1;
                $display("[ERROR] t=%0t | en=1 resume | exp: outc=%h got: outc=%h",
                $time, ve[11], outc);
            end
        end

        // ---- reset имеет приоритет над en ----
        // en=1; reset должен обнулить выход.
        reset = 1'b1;
        @(posedge clk); #1;   // reset применён
        if (outc !== 32'h0000_0000) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | reset priority | exp: outc=00000000 got: outc=%h",
            $time, outc);
        end
        reset = 1'b0;
        en    = 1'b0;

        // ---- 10 nop clocks в конце ----
        repeat (10) @(posedge clk);

        // ---- Итог ----
        $display("---------------------------------------------");
        $display("Checked vectors: %0d", (EXP_CHECK) ? checked : 0);
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
