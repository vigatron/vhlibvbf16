`timescale 1ns/1ps
// =============================================================
// Тестбенч для vhfastmulb16_add_bf16_bf16_bf16_rne_lat4
//   BF16 + BF16 -> BF16 (RNE rounding, IEEE-754 default), latency = 4
//
//   Фаза 1: конвейерная подача, en=1 непрерывно
//   Фаза 2: пропуски en=0 (проверка drain + hold)
//   Фаза 3: hold-тест, en=0 на 8 тактов
//
//   Данные выставляются по @(posedge clk); #1; в соответствии с
//   rules/rules_testbench.md. Ожидаемый результат сравнивается через
//   LAT тактов после выставления данных.
// =============================================================

module vhfastmulb16_add_bf16_bf16_bf16_rne_lat4_tb;

    localparam integer N         = 32;  // число directed-векторов
    localparam integer LAT       = 4;   // latency DUT
    localparam integer MAXC      = 256; // максимум тактов сценария
    localparam integer MAX_PRINT = 10;  // сколько ошибок печатать подробно

    // ---------------- DUT ----------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [15:0] ibf16a;
    reg  [15:0] ibf16b;

    wire [15:0] obf16c;

    vhfastmulb16_add_bf16_bf16_bf16_rne_lat4 uut (
        .clk     (clk),
        .reset   (reset),
        .en      (en),
        .ibf16a  (ibf16a),
        .ibf16b  (ibf16b),
        .obf16c  (obf16c)
    );

    // ---------------- Тестовые векторы ----------------
    reg [15:0] va [0:N-1];
    reg [15:0] vb [0:N-1];
    reg [15:0] ve [0:N-1];

    // ---------------- Журнал выставленных данных ----------------
    // drv_*[k] - данные, выставленные на такте k (после posedge #1).
    // Результат для них появляется на выходе на такте k+LAT.
    reg [15:0] drv_a   [0:MAXC-1];
    reg [15:0] drv_b   [0:MAXC-1];
    reg [15:0] drv_exp [0:MAXC-1];
    reg        drv_en  [0:MAXC-1];

    integer k;
    integer j;
    integer send_idx;
    integer checked;
    integer errors;
    integer max_print_cnt;
    reg [15:0] hold_val;

    // ---------------- Такт 100 МГц ----------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---------------- VCD дамп ----------------
    initial begin
        $dumpfile("build/vhfastmulb16_add_bf16_bf16_bf16_rne_lat4.vcd");
        $dumpvars(0, vhfastmulb16_add_bf16_bf16_bf16_rne_lat4_tb);
    end

    // ---------------- Проверка выхода ----------------
    task check_output;
        input integer idx;
        begin
            if (idx >= LAT && drv_en[idx-LAT]) begin
                checked = checked + 1;
                if (obf16c !== drv_exp[idx-LAT]) begin
                    errors = errors + 1;
                    if (max_print_cnt < MAX_PRINT) begin
                        $display("[ERROR] vec=%0d a=%h b=%h",
                                 idx-LAT, drv_a[idx-LAT], drv_b[idx-LAT]);
                        $display("        exp: obf16c=%h | got: obf16c=%h",
                                 drv_exp[idx-LAT], obf16c);
                    end
                    max_print_cnt = max_print_cnt + 1;
                end
            end
        end
    endtask

    // ---------------- Основная тестовая последовательность ----------------
    initial begin
        // Инициализация
        reset  = 1'b1;
        en     = 1'b0;
        ibf16a = 16'h0000;
        ibf16b = 16'h0000;

        // ---------- Сброс ----------
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (10) @(posedge clk);
        #1;

        checked       = 0;
        errors        = 0;
        max_print_cnt = 0;
        send_idx      = 0;

        if (obf16c !== 16'h0000) begin
            errors = errors + 1;
            $display("[ERROR] after reset: exp obf16c=0000, got obf16c=%h", obf16c);
        end

        // ---------- Фаза 1: конвейер (en=1 непрерывно) ----------
        $display("--- Фаза 1: конвейер (en=1 непрерывно, %0d векторов) ---", N);
        for (k = 0; k < N; k = k + 1) begin
            @(posedge clk);
            #1;
            en     = 1'b1;
            ibf16a = va[send_idx];
            ibf16b = vb[send_idx];
            drv_a[k]   = va[send_idx];
            drv_b[k]   = vb[send_idx];
            drv_exp[k] = ve[send_idx];
            drv_en[k]  = 1'b1;
            send_idx   = send_idx + 1;
            check_output(k);
        end

        // Дожидаемся прохождения последних векторов
        for (k = N; k < N + LAT; k = k + 1) begin
            @(posedge clk);
            #1;
            en = 1'b0;
            drv_en[k] = 1'b0;
            check_output(k);
        end

        // ---------- Фаза 2: пропуски en=0 ----------
        $display("--- Фаза 2: пропуски en=0 (drain/hold) ---");
        k = N + LAT;
        j = 0; // pat_idx
        while (send_idx < N * 2 && k < MAXC - 16) begin
            @(posedge clk);
            #1;
            j = j + 1;
            if (en_pattern_bit(j) && send_idx < N * 2) begin
                en     = 1'b1;
                ibf16a = va[send_idx % N];
                ibf16b = vb[send_idx % N];
                drv_a[k]   = va[send_idx % N];
                drv_b[k]   = vb[send_idx % N];
                drv_exp[k] = ve[send_idx % N];
                drv_en[k]  = 1'b1;
                send_idx   = send_idx + 1;
            end else begin
                en = 1'b0;
                drv_en[k] = 1'b0;
            end
            check_output(k);
            k = k + 1;
        end

        // Дожидаемся прохождения последних векторов
        for (j = 0; j < LAT; j = j + 1) begin
            @(posedge clk);
            #1;
            en = 1'b0;
            drv_en[k] = 1'b0;
            check_output(k);
            k = k + 1;
        end

        // ---------- Фаза 3: hold-тест ----------
        $display("--- Фаза 3: hold-тест (en=0 на 8 тактов) ---");
        en = 1'b0;
        hold_val = obf16c;
        repeat (8) @(posedge clk);
        #1;
        if (obf16c !== hold_val) begin
            errors = errors + 1;
            $display("[ERROR] hold: exp obf16c=%h, got obf16c=%h",
                     hold_val, obf16c);
        end

        // ---------- Финальные nop ----------
        en = 1'b0;
        repeat (10) @(posedge clk);
        #1;

        // ---------- Итог ----------
        if (errors == 0 && checked == N * 2) begin
            $display("TEST PASSED (%0d векторов, проверено %0d)", N * 2, checked);
        end else begin
            $display("TEST FAILED: %0d ошибок, проверено %0d из %0d",
                     errors, checked, N * 2);
        end
        $finish;
    end

    // Паттерн en для фазы 2: 1 1 0 1 1 1 0 1, повторяется.
    function en_pattern_bit;
        input integer idx;
        reg [7:0] pattern;
        begin
            pattern = 8'b11011101;
            en_pattern_bit = pattern[idx % 8];
        end
    endfunction

    // ---------------- Заполнение тестовых векторов ----------------
    initial begin
        va[ 0] = 16'h3F80; vb[ 0] = 16'h3F80; ve[ 0] = 16'h4000;
        va[ 1] = 16'h4000; vb[ 1] = 16'h4060; ve[ 1] = 16'h40B0;
        va[ 2] = 16'hBF80; vb[ 2] = 16'hBF80; ve[ 2] = 16'hC000;
        va[ 3] = 16'h3F80; vb[ 3] = 16'hBF80; ve[ 3] = 16'h0000;
        va[ 4] = 16'h0000; vb[ 4] = 16'h0000; ve[ 4] = 16'h0000;
        va[ 5] = 16'h8000; vb[ 5] = 16'h8000; ve[ 5] = 16'h8000;
        va[ 6] = 16'h0000; vb[ 6] = 16'h8000; ve[ 6] = 16'h0000;
        va[ 7] = 16'h0000; vb[ 7] = 16'h3F80; ve[ 7] = 16'h3F80;
        va[ 8] = 16'h7F80; vb[ 8] = 16'h3F80; ve[ 8] = 16'h7F80;
        va[ 9] = 16'h7F80; vb[ 9] = 16'h7F80; ve[ 9] = 16'h7F80;
        va[10] = 16'h7F80; vb[10] = 16'hFF80; ve[10] = 16'h7FC0;
        va[11] = 16'h7FC0; vb[11] = 16'h3F80; ve[11] = 16'h7FC0;
        va[12] = 16'h7F00; vb[12] = 16'h7F00; ve[12] = 16'h7F80;
        va[13] = 16'h0001; vb[13] = 16'h0001; ve[13] = 16'h0002;
        va[14] = 16'h0001; vb[14] = 16'h0000; ve[14] = 16'h0001;
        va[15] = 16'h3F00; vb[15] = 16'h3F00; ve[15] = 16'h3F80;
        va[16] = 16'h3F80; vb[16] = 16'h3F00; ve[16] = 16'h3FC0;
        va[17] = 16'h3F80; vb[17] = 16'h3E80; ve[17] = 16'h3FA0;
        va[18] = 16'hC000; vb[18] = 16'h3F80; ve[18] = 16'hBF80;
        va[19] = 16'h4040; vb[19] = 16'hBF80; ve[19] = 16'h4000;
        va[20] = 16'h3F40; vb[20] = 16'h3E80; ve[20] = 16'h3F80;
        va[21] = 16'h4080; vb[21] = 16'h4080; ve[21] = 16'h4100;
        va[22] = 16'hC040; vb[22] = 16'hBF00; ve[22] = 16'hC060;
        va[23] = 16'h42C8; vb[23] = 16'h3F80; ve[23] = 16'h42CA;
        va[24] = 16'h3F80; vb[24] = 16'h3B80; ve[24] = 16'h3F80;
        va[25] = 16'h3F81; vb[25] = 16'h3B80; ve[25] = 16'h3F82;
        va[26] = 16'hBF81; vb[26] = 16'h3B20; ve[26] = 16'hBF81;
        va[27] = 16'h7F7F; vb[27] = 16'h7B00; ve[27] = 16'h7F80;
        va[28] = 16'h007F; vb[28] = 16'h0001; ve[28] = 16'h0080;
        va[29] = 16'h3F80; vb[29] = 16'hBB00; ve[29] = 16'h3F80;
        va[30] = 16'h3E00; vb[30] = 16'h3E00; ve[30] = 16'h3E80;
        va[31] = 16'h3FC0; vb[31] = 16'hBF40; ve[31] = 16'h3F40;
    end

    // ---------------- Watchdog ----------------
    initial begin
        #10000000;
        $display("[ERROR] Testbench timeout!");
        $finish;
    end

endmodule
