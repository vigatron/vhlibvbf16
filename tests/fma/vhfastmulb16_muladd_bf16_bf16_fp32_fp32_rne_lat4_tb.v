`timescale 1ns/1ps
// =============================================================
// Тестбенч для vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4
//   RESULT = SUMM + (VALA_BF16 × VALB_BF16), FP32 output, RNE
//   N тройк чисел подаются подряд, каждый такт новая тройка
//   latency = LAT = 4 такта, проверка результата в потоке
//   Проверка hold/reset приоритетов.
// =============================================================

module vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_tb;

    localparam integer N         = 44;  // число тестовых троек
    localparam integer LAT       = 4;   // latency DUT, тактов
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно
    localparam integer EXP_CHECK = 1;   // 1 = проверять функцию

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [15:0] inbf16a;
    reg  [15:0] inbf16b;
    reg  [31:0] infp32s;

    wire [31:0] outfp32s;

    vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4 uut (
        .clk      (clk),
        .reset    (reset),
        .en       (en),
        .inbf16a  (inbf16a),
        .inbf16b  (inbf16b),
        .infp32s  (infp32s),
        .outfp32s (outfp32s)
    );

    // ---------------- Тестовые векторы ----------------
    // inbf16a = VALA (BF16), inbf16b = VALB (BF16), infp32s = SUMM (FP32)
    // ve[k] = ожидаемый результат FP32
    reg  [15:0] va [0:N-1];
    reg  [15:0] vb [0:N-1];
    reg  [31:0] vs [0:N-1];
    reg  [31:0] ve [0:N-1];

    initial begin
        //  1: 1.0 + (1.0 * 1.0) = 2.0
        va[ 0] = 16'h3F80; vb[ 0] = 16'h3F80; vs[ 0] = 32'h3F800000; ve[ 0] = 32'h40000000;
        //  2: 0.0 + (2.0 * 3.0) = 6.0
        va[ 1] = 16'h4000; vb[ 1] = 16'h4040; vs[ 1] = 32'h00000000; ve[ 1] = 32'h40C00000;
        //  3: 5.0 + (0.5 * 0.25) = 5.125
        va[ 2] = 16'h3F00; vb[ 2] = 16'h3E80; vs[ 2] = 32'h40A00000; ve[ 2] = 32'h40A40000;
        //  4: 0.0 + (-1.5 * 4.0) = -6.0
        va[ 3] = 16'hBFC0; vb[ 3] = 16'h4080; vs[ 3] = 32'h00000000; ve[ 3] = 32'hC0C00000;
        //  5: 10.0 + (0.0 * 3.0) = 10.0
        va[ 4] = 16'h0000; vb[ 4] = 16'h4040; vs[ 4] = 32'h41200000; ve[ 4] = 32'h41200000;
        //  6: 0.0 + (+Inf * 2.0) = +Inf
        va[ 5] = 16'h7F80; vb[ 5] = 16'h4000; vs[ 5] = 32'h00000000; ve[ 5] = 32'h7F800000;
        //  7: 0.0 + (+Inf * 0.0) = qNaN
        va[ 6] = 16'h7F80; vb[ 6] = 16'h0000; vs[ 6] = 32'h00000000; ve[ 6] = 32'h7FC00000;
        //  8: NaN + (1.0 * 1.0) = qNaN
        va[ 7] = 16'h3F80; vb[ 7] = 16'h3F80; vs[ 7] = 32'h7FC00000; ve[ 7] = 32'h7FC00000;
        //  9: -Inf + (+Inf * 1.0) = qNaN (Inf - Inf)
        va[ 8] = 16'h7F80; vb[ 8] = 16'h3F80; vs[ 8] = 32'hFF800000; ve[ 8] = 32'h7FC00000;
        // 10: +Inf + (+Inf * -1.0) = qNaN (Inf - Inf)
        va[ 9] = 16'h7F80; vb[ 9] = 16'hBF80; vs[ 9] = 32'h7F800000; ve[ 9] = 32'h7FC00000;
        // 11: 0.0 + (max_BF16 * 2.0) = +Inf (product overflow)
        va[10] = 16'h7F7F; vb[10] = 16'h4000; vs[10] = 32'h00000000; ve[10] = 32'h7F800000;
        // 12: 0.0 + (min_sub_BF16 * 1.0) = F32 subnormal 0x00010000
        va[11] = 16'h0001; vb[11] = 16'h3F80; vs[11] = 32'h00000000; ve[11] = 32'h00010000;
        // 13: 0x00010000 + (min_sub_BF16 * 1.0) = 0x00020000
        va[12] = 16'h0001; vb[12] = 16'h3F80; vs[12] = 32'h00010000; ve[12] = 32'h00020000;
        // 14: 1.0 + (1.0 * -1.0) = +0 (exact cancellation)
        va[13] = 16'h3F80; vb[13] = 16'hBF80; vs[13] = 32'h3F800000; ve[13] = 32'h00000000;
        // 15: -1.0 + (1.0 * 1.0) = +0 (exact cancellation)
        va[14] = 16'h3F80; vb[14] = 16'h3F80; vs[14] = 32'hBF800000; ve[14] = 32'h00000000;
        // 16: -0.0 + (-0.0 * 1.0) = -0
        va[15] = 16'h8000; vb[15] = 16'h3F80; vs[15] = 32'h80000000; ve[15] = 32'h80000000;
        // 17: 0.0 + (-Inf * 1.0) = -Inf
        va[16] = 16'hFF80; vb[16] = 16'h3F80; vs[16] = 32'h00000000; ve[16] = 32'hFF800000;
        // 18: 0.0 + (NaN * 1.0) = qNaN
        va[17] = 16'h7FC0; vb[17] = 16'h3F80; vs[17] = 32'h00000000; ve[17] = 32'h7FC00000;
        // 19: 0.0 + (1.0 * NaN) = qNaN
        va[18] = 16'h3F80; vb[18] = 16'h7FC0; vs[18] = 32'h00000000; ve[18] = 32'h7FC00000;
        // 20: 0.5 + (1.0 * 1.0) = 1.5
        va[19] = 16'h3F80; vb[19] = 16'h3F80; vs[19] = 32'h3F000000; ve[19] = 32'h3FC00000;
        // 21: 1.0 + 2^-24 — tie-to-even, round down to even
        va[20] = 16'h3F80; vb[20] = 16'h3380; vs[20] = 32'h3F800000; ve[20] = 32'h3F800000;
        // 22: (1+2^-23) + 2^-24 — tie-to-even, round up to even
        va[21] = 16'h3F80; vb[21] = 16'h3380; vs[21] = 32'h3F800001; ve[21] = 32'h3F800002;
        // 23: 1.0 + (2^-24 + 2^-31) — above tie, sticky=1
        va[22] = 16'h3F80; vb[22] = 16'h3381; vs[22] = 32'h3F800000; ve[22] = 32'h3F800001;
        // 24: 1.0 + (2^-25 + 2^-32) — below tie
        va[23] = 16'h3F80; vb[23] = 16'h3301; vs[23] = 32'h3F800000; ve[23] = 32'h3F800000;
        // 25: 1.0 − 3·2^-25 — tie at subtraction → even
        va[24] = 16'h3F80; vb[24] = 16'hB3C0; vs[24] = 32'h3F800000; ve[24] = 32'h3F7FFFFE;
        // 26: 2^-150 = 0.5 ulp sub — tie → +0
        va[25] = 16'h0001; vb[25] = 16'h3700; vs[25] = 32'h00000000; ve[25] = 32'h00000000;
        // 27: 2^-149 + 2^-150 → 2 ulp — fused≠unfused
        va[26] = 16'h0001; vb[26] = 16'h3700; vs[26] = 32'h00000001; ve[26] = 32'h00000002;
        // 28: 3 ulp + 0.5 ulp → 4 ulp — fused≠unfused
        va[27] = 16'h0001; vb[27] = 16'h3700; vs[27] = 32'h00000003; ve[27] = 32'h00000004;
        // 29: 1.5 ulp sub — tie → 2 ulp (no FTZ)
        va[28] = 16'h0003; vb[28] = 16'h3700; vs[28] = 32'h00000000; ve[28] = 32'h00000002;
        // 30: −2^-149 + 2^-150 → −0 — fused≠unfused
        va[29] = 16'h0001; vb[29] = 16'h3700; vs[29] = 32'h80000001; ve[29] = 32'h80000000;
        // 31: 2^-252 + 2^-149 — deep underflow, sticky
        va[30] = 16'h0080; vb[30] = 16'h0080; vs[30] = 32'h00000001; ve[30] = 32'h00000001;
        // 32: −Inf + (max×2): fused → −Inf, unfused → qNaN
        va[31] = 16'h7F7F; vb[31] = 16'h4000; vs[31] = 32'hFF800000; ve[31] = 32'hFF800000;
        // 33: FP32_max + 2^103 — overflow boundary → +Inf
        va[32] = 16'h7300; vb[32] = 16'h3F80; vs[32] = 32'h7F7FFFFF; ve[32] = 32'h7F800000;
        // 34: FP32_max + 2^102 — below boundary → max
        va[33] = 16'h7280; vb[33] = 16'h3F80; vs[33] = 32'h7F7FFFFF; ve[33] = 32'h7F7FFFFF;
        // 35: −FP32_max − 2^103 → −Inf
        va[34] = 16'hF300; vb[34] = 16'h3F80; vs[34] = 32'hFF7FFFFF; ve[34] = 32'hFF800000;
        // 36: (2^24−1) − (2^24−2^16) — 24-bit normalization
        va[35] = 16'hBFFF; vb[35] = 16'h4B00; vs[35] = 32'h4B7FFFFF; ve[35] = 32'h477FFF00;
        // 37: 2^-126 − (1−2^-8)·2^-126 = 2^-134 (subnormal)
        va[36] = 16'hBF7F; vb[36] = 16'h0080; vs[36] = 32'h00800000; ve[36] = 32'h00008000;
        // 38: sNaN(BF16) → canonical qNaN
        va[37] = 16'h7F81; vb[37] = 16'h3F80; vs[37] = 32'h00000000; ve[37] = 32'h7FC00000;
        // 39: two NaN with payload → canonical qNaN
        va[38] = 16'h7FC1; vb[38] = 16'h3F80; vs[38] = 32'h7FA00000; ve[38] = 32'h7FC00000;
        // 40: NaN-addend priority over Inf-product
        va[39] = 16'h7F80; vb[39] = 16'h4000; vs[39] = 32'h7FC00000; ve[39] = 32'h7FC00000;
        // 41: −Inf × 0 → qNaN
        va[40] = 16'hFF80; vb[40] = 16'h0000; vs[40] = 32'h00000000; ve[40] = 32'h7FC00000;
        // 42: −0 + (−0 × −1) = −0 + +0 → +0
        va[41] = 16'h8000; vb[41] = 16'hBF80; vs[41] = 32'h80000000; ve[41] = 32'h00000000;
        // 43: +0 + (−0 × 1) → +0
        va[42] = 16'h8000; vb[42] = 16'h3F80; vs[42] = 32'h00000000; ve[42] = 32'h00000000;
        // 44: tie across binade boundary → 1.0
        va[43] = 16'h3300; vb[43] = 16'h3F80; vs[43] = 32'h3F7FFFFF; ve[43] = 32'h3F800000;
    end

    integer k;
    integer checked;
    integer errors;
    reg [31:0] hold_val;

    task check(input integer idx);
        begin
            checked = checked + 1;
            if (outfp32s !== ve[idx]) begin
                errors = errors + 1;
                if (errors <= MAX_PRINT) begin
                    $display("[ERROR] t=%0t | triple %0d | a=%h b=%h s=%h",
                    $time, idx, va[idx], vb[idx], vs[idx]);
                    $display("        exp: outfp32s=%h | got: outfp32s=%h",
                    ve[idx], outfp32s);
                end
            end

            $display("[%0t] triple %0d: a=%h b=%h s=%h -> outfp32s=%h (exp %h)",
            $time, idx, va[idx], vb[idx], vs[idx], outfp32s, ve[idx]);
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
        inbf16a = 16'h0000;
        inbf16b = 16'h0000;
        infp32s = 32'h00000000;

        repeat (5) @(negedge clk);
            reset = 1'b0;
    end

    // ---------------- Основной сценарий ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4.vcd");
        $dumpvars(0, vhfastmulb16_muladd_bf16_bf16_fp32_fp32_rne_lat4_tb);

        checked = 0;
        errors  = 0;

        // Тесты начинаем после снятия reset + 10 тактов
        @(negedge reset);
        repeat (10) @(negedge clk);

        // ---- reset обнуляет outfp32s ----
        if (outfp32s !== 32'h0000_0000) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | после reset: exp outfp32s=00000000, got outfp32s=%h",
            $time, outfp32s);
        end

        // ---- Подача троек и проверка результата в конвейере ----
        // В такте k защёлкивается va[k]/vb[k]/vs[k]; результат виден через LAT
        // тактов, поэтому в такте k проверяется тройка k-LAT.
        // Последние LAT тактов выталкивают остаток из конвейера.
        for (k = 0; k < N + LAT; k = k + 1) begin
            @(posedge clk); #1;

            if (k < N) begin
                inbf16a = va[k];
                inbf16b = vb[k];
                infp32s = vs[k];
                en  = 1'b1;
            end else begin
                en  = 1'b0;  // Drain: explicitly deassert en after last vector
            end

            if (k >= LAT) begin
                if (EXP_CHECK)
                    check(k - LAT);
                else
                    $display("[%0t] triple %0d: a=%h b=%h s=%h -> outfp32s=%h (ожидание %h, проверка отключена EXP_CHECK=0)",
                    $time, k - LAT, va[k - LAT], vb[k - LAT], vs[k - LAT], outfp32s, ve[k - LAT]);
            end
        end

        // ---- en=0: HOLD (outfp32s сохраняет последнее значение) ----
        en = 1'b0;
        inbf16a = 16'h7FC0;  // NaN — при исправном en выход не должен измениться
        inbf16b = 16'h3F80;
        infp32s = 32'h7F800000;
        @(posedge clk); #1;
        hold_val = outfp32s;
        repeat (6) @(posedge clk); #1;
            $display("[%0t] en=0 hold: exp outfp32s=%h, got outfp32s=%h",
            $time, hold_val, outfp32s);
        if (outfp32s !== hold_val) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | en=0 hold нарушен: exp outfp32s=%h, got outfp32s=%h",
            $time, hold_val, outfp32s);
        end

        // ---- en=1: новый вектор должен пройти через конвейер ----
        // Вектор #7 (+Inf * 0.0 -> qNaN 7FC00000)
        en  = 1'b1;
        inbf16a = 16'h7F80;
        inbf16b = 16'h0000;
        infp32s = 32'h00000000;
        if (EXP_CHECK) begin
            repeat (LAT) @(posedge clk); #1;
            checked = checked + 1;
            if (outfp32s !== ve[6]) begin
                errors = errors + 1;
                $display("[ERROR] t=%0t | en=1 resume | exp: outfp32s=%h got: outfp32s=%h",
                $time, ve[6], outfp32s);
            end
        end

        // ---- reset имеет приоритет над en ----
        // en=1; reset должен обнулить выход.
        reset = 1'b1;
        @(posedge clk); #1;   // reset применён
        if (outfp32s !== 32'h0000_0000) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t | reset priority | exp: outfp32s=00000000 got: outfp32s=%h",
            $time, outfp32s);
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
