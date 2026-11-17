`timescale 1ns/1ps
// =============================================================
// Тестбенч для vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8
//   RESULT = SUMM + (VALA_BF16 × VALB_BF16), FP32 output, RTZ/FTZ
//   N троек чисел подаются подряд, каждый такт новая тройка
//   latency = LAT = 8 тактов, проверка результата в потоке
//   Проверка hold/reset приоритетов.
// =============================================================

module vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8_tb;

    localparam integer N         = 57;  // число тестовых троек
    localparam integer LAT       = 8;   // latency DUT, тактов
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

    vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8 uut (
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
        //  1: 1.0 + (1.0 × 1.0) = 2.0
        va[ 0] = 16'h3F80; vb[ 0] = 16'h3F80; vs[ 0] = 32'h3F800000; ve[ 0] = 32'h40000000;
        //  2: 0.0 + (2.0 × 3.0) = 6.0
        va[ 1] = 16'h4000; vb[ 1] = 16'h4040; vs[ 1] = 32'h00000000; ve[ 1] = 32'h40C00000;
        //  3: 5.0 + (0.5 × 0.25) = 5.125
        va[ 2] = 16'h3F00; vb[ 2] = 16'h3E80; vs[ 2] = 32'h40A00000; ve[ 2] = 32'h40A40000;
        //  4: 0.0 + (-1.5 × 4.0) = -6.0
        va[ 3] = 16'hBFC0; vb[ 3] = 16'h4080; vs[ 3] = 32'h00000000; ve[ 3] = 32'hC0C00000;
        //  5: 10.0 + (0.0 × 3.0) = 10.0
        va[ 4] = 16'h0000; vb[ 4] = 16'h4040; vs[ 4] = 32'h41200000; ve[ 4] = 32'h41200000;
        //  6: 0.0 + (+Inf × 2.0) = +Inf
        va[ 5] = 16'h7F80; vb[ 5] = 16'h4000; vs[ 5] = 32'h00000000; ve[ 5] = 32'h7F800000;
        //  7: 0.0 + (+Inf × 0.0) = qNaN
        va[ 6] = 16'h7F80; vb[ 6] = 16'h0000; vs[ 6] = 32'h00000000; ve[ 6] = 32'h7FC00000;
        //  8: NaN + (1.0 × 1.0) = qNaN
        va[ 7] = 16'h3F80; vb[ 7] = 16'h3F80; vs[ 7] = 32'h7FC00000; ve[ 7] = 32'h7FC00000;
        //  9: -Inf + (+Inf × 1.0) = qNaN (Inf − Inf)
        va[ 8] = 16'h7F80; vb[ 8] = 16'h3F80; vs[ 8] = 32'hFF800000; ve[ 8] = 32'h7FC00000;
        // 10: +Inf + (+Inf × -1.0) = qNaN (Inf − Inf)
        va[ 9] = 16'h7F80; vb[ 9] = 16'hBF80; vs[ 9] = 32'h7F800000; ve[ 9] = 32'h7FC00000;
        // 11: +Inf + (+Inf × 1.0) = +Inf (same-sign Inf)
        va[10] = 16'h7F80; vb[10] = 16'h3F80; vs[10] = 32'h7F800000; ve[10] = 32'h7F800000;
        // 12: -Inf + (-Inf × 1.0) = -Inf (same-sign Inf)
        va[11] = 16'hFF80; vb[11] = 16'h3F80; vs[11] = 32'hFF800000; ve[11] = 32'hFF800000;
        // 13: 0.0 + (-Inf × 1.0) = -Inf
        va[12] = 16'hFF80; vb[12] = 16'h3F80; vs[12] = 32'h00000000; ve[12] = 32'hFF800000;
        // 14: 0.0 + (NaN × 1.0) = qNaN
        va[13] = 16'h7FC0; vb[13] = 16'h3F80; vs[13] = 32'h00000000; ve[13] = 32'h7FC00000;
        // 15: 0.0 + (1.0 × NaN) = qNaN
        va[14] = 16'h3F80; vb[14] = 16'h7FC0; vs[14] = 32'h00000000; ve[14] = 32'h7FC00000;
        // 16: sNaN(BF16) -> canonical qNaN
        va[15] = 16'h7F81; vb[15] = 16'h3F80; vs[15] = 32'h00000000; ve[15] = 32'h7FC00000;
        // 17: two NaN with payload -> canonical qNaN
        va[16] = 16'h7FC1; vb[16] = 16'h3F80; vs[16] = 32'h7FA00000; ve[16] = 32'h7FC00000;
        // 18: NaN-addend priority over Inf-product -> qNaN
        va[17] = 16'h7F80; vb[17] = 16'h4000; vs[17] = 32'h7FC00000; ve[17] = 32'h7FC00000;
        // 19: -Inf × 0 -> qNaN
        va[18] = 16'hFF80; vb[18] = 16'h0000; vs[18] = 32'h00000000; ve[18] = 32'h7FC00000;
        // 20: 0 × 0 + (-Inf) = -Inf
        va[19] = 16'h0000; vb[19] = 16'h0000; vs[19] = 32'hFF800000; ve[19] = 32'hFF800000;
        // 21: NaN × 1.0 + (-Inf) = qNaN (NaN priority)
        va[20] = 16'h7FC0; vb[20] = 16'h3F80; vs[20] = 32'hFF800000; ve[20] = 32'h7FC00000;
        // 22: 0.0 + (min_normal_BF16 × min_normal_BF16) = +0 (underflow)
        va[21] = 16'h0080; vb[21] = 16'h0080; vs[21] = 32'h00000000; ve[21] = 32'h00000000;
        // 23: 0.0 + (min_subnormal_BF16 × 1.0) = +0 (FTZ input)
        va[22] = 16'h0001; vb[22] = 16'h3F80; vs[22] = 32'h00000000; ve[22] = 32'h00000000;
        // 24: 1.0 + (min_subnormal_BF16 × 1.0) = 1.0 (FTZ input)
        va[23] = 16'h0001; vb[23] = 16'h3F80; vs[23] = 32'h3F800000; ve[23] = 32'h3F800000;
        // 25: 1.0 × 1.0 + min_subnormal_FP32 = 1.0 (FTZ SUMM)
        va[24] = 16'h3F80; vb[24] = 16'h3F80; vs[24] = 32'h00000001; ve[24] = 32'h3F800000;
        // 26: 0.0 + (2^-133 × 2^-17) = +0 (FTZ underflow)
        va[25] = 16'h0001; vb[25] = 16'h3700; vs[25] = 32'h00000000; ve[25] = 32'h00000000;
        // 27: 2^-149 + 2^-150 -> +0 (FTZ SUMM and product)
        va[26] = 16'h0001; vb[26] = 16'h3700; vs[26] = 32'h00000001; ve[26] = 32'h00000000;
        // 28: 3·2^-150 -> +0 (FTZ underflow)
        va[27] = 16'h0003; vb[27] = 16'h3700; vs[27] = 32'h00000000; ve[27] = 32'h00000000;
        // 29: -2^-149 + 2^-150 -> +0 (FAST zero rule)
        va[28] = 16'h0001; vb[28] = 16'h3700; vs[28] = 32'h80000001; ve[28] = 32'h00000000;
        // 30: 2^-252 + 2^-149 -> +0 (FTZ SUMM and product)
        va[29] = 16'h0080; vb[29] = 16'h0080; vs[29] = 32'h00000001; ve[29] = 32'h00000000;
        // 31: min_subnormal × max_BF16 -> +0 (FTZ)
        va[30] = 16'h0001; vb[30] = 16'h7F7F; vs[30] = 32'h00000000; ve[30] = 32'h00000000;
        // 32: max_BF16 × 1.0 + min_subnormal_FP32 = max_BF16 (SUMM FTZ)
        va[31] = 16'h7F7F; vb[31] = 16'h3F80; vs[31] = 32'h00000001; ve[31] = 32'h7F7F0000;
        // 33: 1.0 + (1.0 × -1.0) = +0 (exact cancellation)
        va[32] = 16'h3F80; vb[32] = 16'hBF80; vs[32] = 32'h3F800000; ve[32] = 32'h00000000;
        // 34: -1.0 + (1.0 × 1.0) = +0 (exact cancellation)
        va[33] = 16'h3F80; vb[33] = 16'h3F80; vs[33] = 32'hBF800000; ve[33] = 32'h00000000;
        // 35: -0.0 + (-0.0 × 1.0) = +0 (FAST zero rule)
        va[34] = 16'h8000; vb[34] = 16'h3F80; vs[34] = 32'h80000000; ve[34] = 32'h00000000;
        // 36: -0.0 + (-0.0 × -1.0) = +0 (FAST zero rule)
        va[35] = 16'h8000; vb[35] = 16'hBF80; vs[35] = 32'h80000000; ve[35] = 32'h00000000;
        // 37: +0.0 + (+0.0 × 1.0) = +0 (FAST zero rule)
        va[36] = 16'h0000; vb[36] = 16'h3F80; vs[36] = 32'h80000000; ve[36] = 32'h00000000;
        // 38: 1.0 + (1.0 × 2^-24) — RTZ half-ulp -> 1.0
        va[37] = 16'h3F80; vb[37] = 16'h3380; vs[37] = 32'h3F800000; ve[37] = 32'h3F800000;
        // 39: 1.0 + (1.0 × (2^-24 + 2^-31)) — RTZ above half-ulp -> 1.0
        va[38] = 16'h3F80; vb[38] = 16'h3381; vs[38] = 32'h3F800000; ve[38] = 32'h3F800000;
        // 40: 1.0 + (1.0 × (2^-25 + 2^-32)) — RTZ below half-ulp -> 1.0
        va[39] = 16'h3F80; vb[39] = 16'h3301; vs[39] = 32'h3F800000; ve[39] = 32'h3F800000;
        // 41: 1.0 - (1.0 × 3·2^-25) — RTZ subtraction
        va[40] = 16'h3F80; vb[40] = 16'hB3C0; vs[40] = 32'h3F800000; ve[40] = 32'h3F7FFFFE;
        // 42: tie across binade boundary — RTZ -> 1−2^-24
        va[41] = 16'h3300; vb[41] = 16'h3F80; vs[41] = 32'h3F7FFFFF; ve[41] = 32'h3F7FFFFF;
        // 43: 0.0 + (max_BF16 × 2.0) = +Inf (product overflow)
        va[42] = 16'h7F7F; vb[42] = 16'h4000; vs[42] = 32'h00000000; ve[42] = 32'h7F800000;
        // 44: FP32_max + 2^103 — RTZ overflow boundary -> FP32_max
        va[43] = 16'h7300; vb[43] = 16'h3F80; vs[43] = 32'h7F7FFFFF; ve[43] = 32'h7F7FFFFF;
        // 45: FP32_max + 2^102 — RTZ below boundary -> FP32_max
        va[44] = 16'h7280; vb[44] = 16'h3F80; vs[44] = 32'h7F7FFFFF; ve[44] = 32'h7F7FFFFF;
        // 46: -FP32_max - 2^103 — RTZ overflow boundary -> -FP32_max
        va[45] = 16'hF300; vb[45] = 16'h3F80; vs[45] = 32'hFF7FFFFF; ve[45] = 32'hFF7FFFFF;
        // 47: FP32_max + max_BF16 -> +Inf (overflow)
        va[46] = 16'h7F7F; vb[46] = 16'h3F80; vs[46] = 32'h7F7FFFFF; ve[46] = 32'h7F800000;
        // 48: -FP32_max + (1.0 × 1.0) = -FP32_max (absorbed)
        va[47] = 16'h3F80; vb[47] = 16'h3F80; vs[47] = 32'hFF7FFFFF; ve[47] = 32'hFF7FFFFF;
        // 49: max_BF16 × max_BF16 -> +Inf (product overflow)
        va[48] = 16'h7F7F; vb[48] = 16'h7F7F; vs[48] = 32'h00000000; ve[48] = 32'h7F800000;
        // 50: -max_BF16 × max_BF16 -> -Inf (product overflow)
        va[49] = 16'hFF7F; vb[49] = 16'h7F7F; vs[49] = 32'h00000000; ve[49] = 32'hFF800000;
        // 51: 1.5 × 1.5 + 0.75 = 3.0 (carry)
        va[50] = 16'h3FC0; vb[50] = 16'h3FC0; vs[50] = 32'h3F400000; ve[50] = 32'h40400000;
        // 52: 1.5 + (1.0 × 1.0) = 2.5 (p24 < s_man)
        va[51] = 16'h3F80; vb[51] = 16'h3F80; vs[51] = 32'h3FC00000; ve[51] = 32'h40200000;
        // 53: 0.75 + (1.0 × -1.0) = -0.25 (large = SUMM)
        va[52] = 16'h3F80; vb[52] = 16'hBF80; vs[52] = 32'h3F400000; ve[52] = 32'hBE800000;
        // 54: 2^-100 + (1.0 × 1.0) = 1.0 (shift saturation)
        va[53] = 16'h3F80; vb[53] = 16'h3F80; vs[53] = 32'h0D800000; ve[53] = 32'h3F800000;
        // 55: 2^-200 + 1.0 = 1.0 (tiny product)
        va[54] = 16'h0D80; vb[54] = 16'h0D80; vs[54] = 32'h3F800000; ve[54] = 32'h3F800000;
        // 56: (2^24−1) − (2^24−2^16) — 24-bit normalization
        va[55] = 16'hBFFF; vb[55] = 16'h4B00; vs[55] = 32'h4B7FFFFF; ve[55] = 32'h477FFF00;
        // 57: 2^-126 − (1−2^-8)·2^-126 = 2^-134 -> +0 (FTZ)
        va[56] = 16'hBF7F; vb[56] = 16'h0080; vs[56] = 32'h00800000; ve[56] = 32'h00000000;
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
        $dumpfile("build/vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8.vcd");
        $dumpvars(0, vhfastmulb16_muladd_bf16_bf16_fp32_fp32_fst_lat8_tb);

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
