`timescale 1ns/1ps
// =============================================================
// Тестбенч для vhfastmulb16_add_fp32_fp32_fp32_rne_lat4
//   FP32 + FP32 -> FP32 (RNE rounding, IEEE-754 default), latency = 4 такта
//
//   Фаза 1: конвейерная подача, en=1 непрерывно (каждый такт новое значение)
//   Фаза 2: пропуски en=0 (проверка drain + hold)
//   Фаза 3: hold-тест, en=0 на 8 тактов (выход удерживает последнее значение)
// =============================================================

module vhfastmulb16_add_fp32_fp32_fp32_rne_lat4_tb;

    localparam integer N         = 32;  // число тестовых векторов
    localparam integer LAT       = 4;   // latency DUT, тактов
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [31:0] inf32a;
    reg  [31:0] inf32b;

    wire [31:0] outf32c;

    vhfastmulb16_add_fp32_fp32_fp32_rne_lat4 uut (
        .clk     (clk),
        .reset   (reset),
        .en      (en),
        .inf32a  (inf32a),
        .inf32b  (inf32b),
        .outf32c (outf32c)
    );

    // ---------------- Тестовые векторы ----------------
    reg [31:0] va [0:N-1];
    reg [31:0] vb [0:N-1];
    reg [31:0] ve [0:N-1];

    // ---------------- Очередь ожидаемых выводов (сдвиговый регистр) ----------------
    reg [31:0] exp_shift [0:LAT-1];
    reg        exp_valid [0:LAT-1];

    integer j;
    integer send_idx;       // сколько векторов подано в конвейер
    integer check_idx;      // индекс вектора, который сейчас проверяется на выходе
    integer checked_count;  // сколько векторов уже проверено на выходе
    integer errors;
    integer max_print_cnt;

    // ---------- Фаза 2: переменные для паттерна en ----------
    reg [7:0] en_pattern;
    integer   pat_idx;

    // ---------------- Такт 100 МГц ----------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---------------- VCD дамп ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_add_fp32_fp32_fp32_rne_lat4.vcd");
        $dumpvars(0, vhfastmulb16_add_fp32_fp32_fp32_rne_lat4_tb);
    end

    // ---------------- Конвейерная проверка ----------------
    always @(posedge clk) begin
        if (reset) begin
            send_idx      = 0;
            check_idx     = 0;
            checked_count = 0;
            errors        = 0;
            max_print_cnt = 0;
            for (j = 0; j <= LAT-1; j = j + 1) begin
                exp_shift[j] = 32'd0;
                exp_valid[j] = 1'b0;
            end
        end else begin
            // В конвейер подаем ожидание только если en=1 и есть векторы
            if (en && send_idx < N * 2) begin
                exp_shift[0] <= ve[send_idx % N];
                exp_valid[0] <= 1'b1;
                send_idx     = send_idx + 1;
            end else begin
                exp_shift[0] <= 32'd0;
                exp_valid[0] <= 1'b0;
            end
            for (j = 1; j <= LAT-1; j = j + 1) begin
                exp_shift[j] <= exp_shift[j-1];
                exp_valid[j] <= exp_valid[j-1];
            end

            // Проверка выхода из последней стадии конвейера
            if (exp_valid[LAT-1]) begin
                checked_count = checked_count + 1;
                if (outf32c !== exp_shift[LAT-1]) begin
                    errors = errors + 1;
                    if (max_print_cnt < MAX_PRINT) begin
                        $display("[ERROR] vec=%0d a=%h b=%h",
                                 check_idx % N,
                                 va[check_idx % N],
                                 vb[check_idx % N]);
                        $display("        exp: outf32c=%h | got: outf32c=%h",
                                 exp_shift[LAT-1], outf32c);
                    end
                    max_print_cnt = max_print_cnt + 1;
                end
                check_idx = check_idx + 1;
            end
        end
    end

    // ---------------- Основная тестовая последовательность ----------------
    initial begin
        // Инициализация
        reset    = 1'b1;
        en       = 1'b0;
        inf32a   = 32'h00000000;
        inf32b   = 32'h00000000;

        // ---------- Сброс ----------
        repeat (5) @(posedge clk);
        #1;
        reset = 1'b0;
        repeat (2) @(posedge clk);
        #1;

        // ---------- Фаза 1: конвейерная подача, en=1 непрерывно ----------
        $display("--- Фаза 1: конвейер (en=1 непрерывно, %0d векторов) ---", N);
        en = 1'b1;
        while (send_idx < N) begin
            @(negedge clk);
            inf32a = va[send_idx];
            inf32b = vb[send_idx];
            @(posedge clk);
            #1;
        end
        en = 1'b0;

        // Дожидаемся прохождения всех поданных векторов через конвейер
        repeat (LAT + 2) @(posedge clk);
        #1;

        // ---------- Фаза 2: пропуски en=0 (паттерн с дырками) ----------
        $display("--- Фаза 2: пропуски en=0 (drain/hold) ---");
        en_pattern = 8'b11011101;
        pat_idx = 0;

        // Подаём ещё N векторов с пропусками en=0
        while (send_idx < N * 2) begin
            @(negedge clk);
            pat_idx = pat_idx + 1;
            if (en_pattern[pat_idx % 8] && send_idx < N * 2) begin
                en = 1'b1;
                inf32a = va[send_idx % N];
                inf32b = vb[send_idx % N];
            end else begin
                en = 1'b0;
            end
            @(posedge clk);
            #1;
        end
        en = 1'b0;

        // Дожидаемся прохождения через конвейер
        repeat (LAT + 2) @(posedge clk);
        #1;

        // ---------- Фаза 3: hold-тест, en=0 на 8 тактов ----------
        $display("--- Фаза 3: hold-тест (en=0 на 8 тактов) ---");
        repeat (8) @(posedge clk);
        #1;
        $display("[INFO] HOLD-тест: outf32c=%h (должен удерживать последнее значение)", outf32c);

        // ---------- Итог ----------
        if (errors == 0 && checked_count == N * 2) begin
            $display("TEST PASSED (%0d векторов, проверено %0d)", N * 2, checked_count);
        end else begin
            $display("TEST FAILED: %0d ошибок, проверено %0d из %0d",
                     errors, checked_count, N * 2);
        end
        $finish;
    end

    // ---------------- Заполнение тестовых векторов ----------------
    initial begin
        //  1:  1.0 + 1.0 = 2.0
        va[ 0] = 32'h3F800000; vb[ 0] = 32'h3F800000; ve[ 0] = 32'h40000000;
        //  2: -1.0 + 1.0 = +0
        va[ 1] = 32'hBF800000; vb[ 1] = 32'h3F800000; ve[ 1] = 32'h00000000;
        //  3: +Inf + 1.0 = +Inf
        va[ 2] = 32'h7F800000; vb[ 2] = 32'h3F800000; ve[ 2] = 32'h7F800000;
        //  4: NaN + 1.0 = qNaN
        va[ 3] = 32'h7FC00000; vb[ 3] = 32'h3F800000; ve[ 3] = 32'h7FC00000;
        //  5: min_subnormal + min_subnormal = 2^-148 (subnormal F32)
        va[ 4] = 32'h00000001; vb[ 4] = 32'h00000001; ve[ 4] = 32'h00000002;
        //  6: max_normal + 1.0 -> 1.0 слишком мало, результат = max_normal
        va[ 5] = 32'h7F7FFFFF; vb[ 5] = 32'h3F800000; ve[ 5] = 32'h7F7FFFFF;
        //  7: -Inf + -Inf = -Inf
        va[ 6] = 32'hFF800000; vb[ 6] = 32'hFF800000; ve[ 6] = 32'hFF800000;
        //  8: +Inf + (-Inf) = qNaN
        va[ 7] = 32'h7F800000; vb[ 7] = 32'hFF800000; ve[ 7] = 32'hFFC00000;
        //  9: -0 + -0 = -0
        va[ 8] = 32'h80000000; vb[ 8] = 32'h80000000; ve[ 8] = 32'h80000000;
        // 10: +0 + -0 = +0 (IEEE-754 default)
        va[ 9] = 32'h00000000; vb[ 9] = 32'h80000000; ve[ 9] = 32'h00000000;
        // 11: 3.5 + 2.5 = 6.0
        va[10] = 32'h40400000; vb[10] = 32'h40200000; ve[10] = 32'h40B00000;
        // 12: -100.0 + 100.0 = +0
        va[11] = 32'hC2C80000; vb[11] = 32'h42C80000; ve[11] = 32'h00000000;
        // 13: NaN + NaN = qNaN
        va[12] = 32'h7FC00000; vb[12] = 32'h7FC00000; ve[12] = 32'h7FC00000;
        // 14: subnormal + 1.0 -> RNE: 2^-126 + 1.0 округляется до 1.0
        va[13] = 32'h00800000; vb[13] = 32'h3F800000; ve[13] = 32'h3F800000;
        // 15: -3.0 + -4.0 = -7.0
        va[14] = 32'hC0400000; vb[14] = 32'hC0800000; ve[14] = 32'hC0E00000;
        // 16: 2^-149 + 2^-149 = 2^-148 (min subnormal F32 * 2)
        va[15] = 32'h00800000; vb[15] = 32'h00800000; ve[15] = 32'h01000000;
        // 17: -0 + 1.0 = 1.0
        va[16] = 32'h80000000; vb[16] = 32'h3F800000; ve[16] = 32'h3F800000;
        // 18: 1.0 + 2^-24 -> tie (ровно посередине), RNE к чётному -> 1.0 (LSB=0)
        va[17] = 32'h3F800000; vb[17] = 32'h33800000; ve[17] = 32'h3F800000;
        // 19: NaN с полем, сохранить payload
        va[18] = 32'h7FC01234; vb[18] = 32'h3F800000; ve[18] = 32'h7FC01234;
        // 20: signalling NaN -> quiet NaN (payload сохраняется: 0x200000 | 0x400000 = 0x600000)
        va[19] = 32'h7FA00000; vb[19] = 32'h3F800000; ve[19] = 32'h7FE00000;
        // 21: Inf + subnormal = Inf
        va[20] = 32'h7F800000; vb[20] = 32'h00800000; ve[20] = 32'h7F800000;
        // 22: subnormal + (-subnormal) = +0 (точная аннуляция)
        va[21] = 32'h00800000; vb[21] = 32'h80800000; ve[21] = 32'h00000000;
        // 23: +0 + +0 = +0
        va[22] = 32'h00000000; vb[22] = 32'h00000000; ve[22] = 32'h00000000;
        // 24: -0 + +0 = +0
        va[23] = 32'h80000000; vb[23] = 32'h00000000; ve[23] = 32'h00000000;
        // 25: 1.0 + -1.0 = +0
        va[24] = 32'h3F800000; vb[24] = 32'hBF800000; ve[24] = 32'h00000000;
        // 26: 2.0 + -1.0 = 1.0
        va[25] = 32'h40000000; vb[25] = 32'hBF800000; ve[25] = 32'h3F800000;
        // 27: max_normal + max_normal = +Inf
        va[26] = 32'h7F7FFFFF; vb[26] = 32'h7F7FFFFF; ve[26] = 32'h7F800000;
        // 28: -Inf + 1.0 = -Inf
        va[27] = 32'hFF800000; vb[27] = 32'h3F800000; ve[27] = 32'hFF800000;
        // 29: NaN + Inf = qNaN
        va[28] = 32'h7FC00000; vb[28] = 32'h7F800000; ve[28] = 32'h7FC00000;
        // 30: 1.0 + 3*2^-25 -> больше половины, RNE округляет вверх -> 1.0 + 2^-23
        va[29] = 32'h3F800000; vb[29] = 32'h34000000; ve[29] = 32'h3F800001;
        // 31: subnormal + subnormal = normal (2^-126 + 2^-126 = 2^-125)
        va[30] = 32'h00400000; vb[30] = 32'h00400000; ve[30] = 32'h00800000;
        // 32: -2.0 + 2.0 = +0
        va[31] = 32'hC0000000; vb[31] = 32'h40000000; ve[31] = 32'h00000000;
    end

endmodule
