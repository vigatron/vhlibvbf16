`timescale 1ns/1ps
// =============================================================
// Визуализационный тестбенч для vhfastmulb16_add8x8
// 16 пар чисел подаются подряд, каждый такт новая пара
// латентность результата 2 такта
// Данные из test_values_rnz.md - 8-бит экспоненты из BF16
// Блок 1: инициализация данных + drive цикл с проверкой
// Блок 2: проверка после wait(data_ready)
// =============================================================

module vhfastmulb16_add8x8_chk_tb;

    localparam MAX_PRINT = 10;

    // ---------- DUT ----------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [7:0]  a;
    reg  [7:0]  b;
    wire [8:0]  c;

    vhfastmulb16_add8x8_lat2 uut (
    .clk   (clk),
    .reset (reset),
    .en    (en),
    .a     (a),
    .b     (b),
    .c     (c)
    );

    // ---------- Синхронизация ----------
    reg         data_ready;

    // ---------- Массивы Drive (Block 1) ----------
    reg [7:0] a_vals [0:15];
    reg [7:0] b_vals [0:15];

    // ---------- Массив ожидаемых значений exp ----------
    // Объявлен на модульном уровне
    reg [8:0] exp [0:15];

    // ---------- Счетчики ----------
    integer k, k2, k3;
    integer errors;
    
    // ---------- Clock 100 MHz ----------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---------- BLOCK 1: Drive DUT + Init Data + Check ----------
    // Содержит инициализацию, drive цикл и проверку результатов
    // с учетом латентности 2 такта (check_c(k-2) для k >= 2)
    initial begin
        
        k=0;
        k2=0; k3=0;
        
        /* rewritten in hex */
        // Инициализация массивов 8-бит экспонент из test_values_rnz.md
        a_vals[0] = 8'h7F; b_vals[0] = 8'h7F;
        a_vals[1] = 8'h80; b_vals[1] = 8'h80;
        a_vals[2] = 8'h7F; b_vals[2] = 8'h81;
        a_vals[3] = 8'h7E; b_vals[3] = 8'h7D;
        a_vals[4] = 8'h86; b_vals[4] = 8'h78;
        a_vals[5] = 8'h80; b_vals[5] = 8'h80;
        a_vals[6] = 8'h85; b_vals[6] = 8'h7B;
        a_vals[7] = 8'h82; b_vals[7] = 8'h7D;
        a_vals[8] = 8'h7F; b_vals[8] = 8'h00;
        a_vals[9] = 8'hFF; b_vals[9] = 8'h80;
        a_vals[10] = 8'hFF; b_vals[10] = 8'hFF;
        a_vals[11] = 8'hFF; b_vals[11] = 8'h00;
        a_vals[12] = 8'hFF; b_vals[12] = 8'h81;
        a_vals[13] = 8'hFF; b_vals[13] = 8'hFF;
        a_vals[14] = 8'h00; b_vals[14] = 8'h00;
        a_vals[15] = 8'hFF; b_vals[15] = 8'h00;

        // Инициализация exp (c = a + b - 127, 9-bit unsigned modulo 512)
        exp[0] = 9'h7F;
        exp[1] = 9'h81;
        exp[2] = 9'h81;
        exp[3] = 9'h7C;
        exp[4] = 9'h7F;
        exp[5] = 9'h81;
        exp[6] = 9'h81;
        exp[7] = 9'h80;
        exp[8] = 9'h00;
        exp[9] = 9'h100;
        exp[10] = 9'h17F;
        exp[11] = 9'h80;
        exp[12] = 9'h101;
        exp[13] = 9'h17F;
        exp[14] = 9'h181;
        exp[15] = 9'h80;
        
        // Сигнал о готовности данных для Block 2
        data_ready = 1'b1;

        // --- Сброс DUT: 5 тактов ---
        reset = 1'b1; en = 1'b0; a = 8'h00; b = 8'h00;
        repeat (5) @(negedge clk);
            reset = 1'b0;

        // --- 16 пар подряд, каждая на своём такте ---
        // Блок drive: подаем пары (a, b) с en=1
        // с латентностью 2 такта: результат пары k появляется через 2 тика
        for (k = 0; k < 16; k = k + 1) begin
            if (k>1) k2 = k2+1;
                if (k2>1) k3 = k3+1;
                
                @(posedge clk); #1;
            
            a  = a_vals[k];
            b  = b_vals[k];
            en = 1'b1;
        end

        k2 = k2 + 1;
        k3 = k3 + 1;
        
        // Финализация
        
        // Сброс enable
        @(posedge clk); #1;
        en = 1'b0;

        k  = 0;
        k2 = k2 + 1;
        k3 = k3 + 1;

        @(posedge clk); #1;
        k2 = 0;
        k3 = k3 + 1;

        @(posedge clk); #1;
        k2 = 0;
        k3 = 0;

        @(posedge clk); #1;

        // ---- Итог ----
        $display("---------------------------------------------");
        $display("Errors: %0d", errors);
        
        if (errors == 0)
            $display("TEST PASSED");
    else
            $display("TEST FAILED");
        
        #1000;
        $finish;
    end

    
    // ---------- BLOCK 2: Supplementary check (wait data_ready) ----------
    // Можно использовать для дополнительной проверки или мониторинга
    initial begin
        // Ожидание готовности данных из Block 1
        wait(data_ready);

        $dumpfile("build/vhfastmulb16_add8x8_chk.vcd");
        $dumpvars(0, vhfastmulb16_add8x8_chk_tb);

        errors = 0;
        

        // 
        forever begin
            @(posedge clk);
            
            if (k3 > 0) begin
                $display("[%0t] # %0d: a=%h b=%h c=%h (exp %h)",
                $time, k3-1, a_vals[k3-1], b_vals[k3-1], exp[k3 - 1], c);
                
                if(exp[k3 - 1] !== c) begin
                    errors = errors + 1;
                    $display("FAILED !");
                end
            end
        end
    end
    
    
    // ---------- Watchdog ----------
    initial begin
        #1000000;
        $display("Timeout!");
        $finish;
    end

endmodule