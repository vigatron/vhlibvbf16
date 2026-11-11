`timescale 1ns/1ps
// =============================================================
// Тестбенч для vhfastmulb16_addf16_rne_lat4
//   FP16 + FP16 -> FP16 (RNE rounding, IEEE-754 default), latency = 4 такта
//
//   Фаза 1: конвейерная подача, en=1 непрерывно (каждый такт новое значение)
//   Фаза 2: пропуски en=0 (проверка drain + hold)
//   Фаза 3: hold-тест, en=0 на 8 тактов (выход удерживает последнее значение)
// =============================================================

module vhfastmulb16_addf16_rne_lat4_tb;

    localparam integer N         = 32;  // число тестовых векторов
    localparam integer LAT       = 4;   // latency DUT, тактов
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [15:0] inf16a;
    reg  [15:0] inf16b;

    wire [15:0] outf16c;

    vhfastmulb16_addf16_rne_lat4 uut (
        .clk     (clk),
        .reset   (reset),
        .en      (en),
        .inf16a  (inf16a),
        .inf16b  (inf16b),
        .outf16c (outf16c)
    );

    // ---------------- Тестовые векторы ----------------
    reg [15:0] va [0:N-1];
    reg [15:0] vb [0:N-1];
    reg [15:0] ve [0:N-1];

    // ---------------- Очередь ожидаемых выводов (сдвиговый регистр) ----------------
    reg [15:0] exp_shift [0:LAT-1];
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
        $dumpfile("build/vhfastmulb16_addf16_rne_lat4.vcd");
        $dumpvars(0, vhfastmulb16_addf16_rne_lat4_tb);
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
                exp_shift[j] = 16'd0;
                exp_valid[j] = 1'b0;
            end
        end else begin
            // В конвейер подаем ожидание только если en=1 и есть векторы
            if (en && send_idx < N * 2) begin
                exp_shift[0] <= ve[send_idx % N];
                exp_valid[0] <= 1'b1;
                send_idx     = send_idx + 1;
            end else begin
                exp_shift[0] <= 16'd0;
                exp_valid[0] <= 1'b0;
            end
            for (j = 1; j <= LAT-1; j = j + 1) begin
                exp_shift[j] <= exp_shift[j-1];
                exp_valid[j] <= exp_valid[j-1];
            end

            // Проверка выхода из последней стадии конвейера
            if (exp_valid[LAT-1]) begin
                checked_count = checked_count + 1;
                if (outf16c !== exp_shift[LAT-1]) begin
                    errors = errors + 1;
                    if (max_print_cnt < MAX_PRINT) begin
                        $display("[ERROR] vec=%0d a=%h b=%h",
                                 check_idx % N,
                                 va[check_idx % N],
                                 vb[check_idx % N]);
                        $display("        exp: outf16c=%h | got: outf16c=%h",
                                 exp_shift[LAT-1], outf16c);
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
        inf16a   = 16'h0000;
        inf16b   = 16'h0000;

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
            inf16a = va[send_idx];
            inf16b = vb[send_idx];
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
                inf16a = va[send_idx % N];
                inf16b = vb[send_idx % N];
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
        $display("[INFO] HOLD-тест: outf16c=%h (должен удерживать последнее значение)", outf16c);

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
        va[ 0] = 16'h3C00; vb[ 0] = 16'h3C00; ve[ 0] = 16'h4000;
        //  2: -1.0 + 1.0 = +0
        va[ 1] = 16'hBC00; vb[ 1] = 16'h3C00; ve[ 1] = 16'h0000;
        //  3: +Inf + 1.0 = +Inf
        va[ 2] = 16'h7C00; vb[ 2] = 16'h3C00; ve[ 2] = 16'h7C00;
        //  4: qNaN + 1.0 = qNaN
        va[ 3] = 16'h7E00; vb[ 3] = 16'h3C00; ve[ 3] = 16'h7E00;
        //  5: min_subnormal + min_subnormal = 2^-23
        va[ 4] = 16'h0001; vb[ 4] = 16'h0001; ve[ 4] = 16'h0002;
        //  6: max_normal + 1.0 -> RNE: 1.0 слишком мало (ulp=32), результат = max_normal
        va[ 5] = 16'h7BFF; vb[ 5] = 16'h3C00; ve[ 5] = 16'h7BFF;
        //  7: -Inf + -Inf = -Inf
        va[ 6] = 16'hFC00; vb[ 6] = 16'hFC00; ve[ 6] = 16'hFC00;
        //  8: +Inf + (-Inf) = qNaN (sign/payload от op B)
        va[ 7] = 16'h7C00; vb[ 7] = 16'hFC00; ve[ 7] = 16'hFE00;
        //  9: -0 + -0 = -0
        va[ 8] = 16'h8000; vb[ 8] = 16'h8000; ve[ 8] = 16'h8000;
        // 10: +0 + -0 = +0 (IEEE-754 default)
        va[ 9] = 16'h0000; vb[ 9] = 16'h8000; ve[ 9] = 16'h0000;
        // 11: 3.5 + 2.5 = 6.0
        va[10] = 16'h4300; vb[10] = 16'h4100; ve[10] = 16'h4600;
        // 12: -100.0 + 100.0 = +0
        va[11] = 16'hD640; vb[11] = 16'h5640; ve[11] = 16'h0000;
        // 13: NaN + NaN = qNaN
        va[12] = 16'h7E00; vb[12] = 16'h7E00; ve[12] = 16'h7E00;
        // 14: subnormal + 1.0 -> RNE: 2^-14 + 1.0 округляется до 1.0
        va[13] = 16'h0400; vb[13] = 16'h3C00; ve[13] = 16'h3C00;
        // 15: -3.0 + -4.0 = -7.0
        va[14] = 16'hC400; vb[14] = 16'hC800; ve[14] = 16'hCA00;
        // 16: 2^-24 + 2^-24 = 2^-23 (min subnormal F16 * 2)
        va[15] = 16'h0001; vb[15] = 16'h0001; ve[15] = 16'h0002;
        // 17: -0 + 1.0 = 1.0
        va[16] = 16'h8000; vb[16] = 16'h3C00; ve[16] = 16'h3C00;
        // 18: large + small (RNE: 1.0 + 2^-10 = 1 ULP)
        va[17] = 16'h5640; vb[17] = 16'h0001; ve[17] = 16'h5640;
        // 19: NaN с полем, сохранить payload
        va[18] = 16'h7E12; vb[18] = 16'h3C00; ve[18] = 16'h7E12;
        // 20: signalling NaN -> quiet NaN (payload сохраняется: 0x001 | 0x200 = 0x201)
        va[19] = 16'h7C01; vb[19] = 16'h3C00; ve[19] = 16'h7E01;
        // 21: Inf + subnormal = Inf
        va[20] = 16'h7C00; vb[20] = 16'h0400; ve[20] = 16'h7C00;
        // 22: subnormal + (-subnormal) = +0 (точная аннуляция)
        va[21] = 16'h0400; vb[21] = 16'h8400; ve[21] = 16'h0000;
        // 23: +0 + +0 = +0
        va[22] = 16'h0000; vb[22] = 16'h0000; ve[22] = 16'h0000;
        // 24: -0 + +0 = +0
        va[23] = 16'h8000; vb[23] = 16'h0000; ve[23] = 16'h0000;
        // 25: 1.0 + -1.0 = +0
        va[24] = 16'h3C00; vb[24] = 16'hBC00; ve[24] = 16'h0000;
        // 26: 2.0 + -1.0 = 1.0
        va[25] = 16'h4000; vb[25] = 16'hBC00; ve[25] = 16'h3C00;
        // 27: max_normal + max_normal = +Inf
        va[26] = 16'h7BFF; vb[26] = 16'h7BFF; ve[26] = 16'h7C00;
        // 28: -Inf + 1.0 = -Inf
        va[27] = 16'hFC00; vb[27] = 16'h3C00; ve[27] = 16'hFC00;
        // 29: NaN + Inf = qNaN
        va[28] = 16'h7E00; vb[28] = 16'h7C00; ve[28] = 16'h7E00;
        // 30: 1.0 + 2^-11 (half ULP, tie to even -> 1.0 since LSB=0)
        va[29] = 16'h3C00; vb[29] = 16'h0800; ve[29] = 16'h3C00;
        // 31: 1.0 + 2^-10 (exactly 1 ULP -> 1.0 + 2^-10)
        va[30] = 16'h3C00; vb[30] = 16'h1400; ve[30] = 16'h3C01;
        // 32: -2.0 + 2.0 = +0
        va[31] = 16'hC000; vb[31] = 16'h4000; ve[31] = 16'h0000;
    end

endmodule