`timescale 1ns/1ps

module vhfastmulb16_mul4x4_tb;

    // Входы DUT
    reg clk;
    reg reset;
    reg en;
    reg [3:0] a;
    reg [3:0] b;

    // Выход DUT
    wire [7:0] c;

    // Инстанцирование DUT по именам портов
    vhfastmulb16_mul4x4 dut (
        .clk(clk),
        .reset(reset),
        .en(en),
        .a(a),
        .b(b),
        .c(c)
    );

    // Генерация тактового сигнала 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Сброс DUT: удерживаем 5 тактов, затем снимаем
    initial begin
        reset = 1;
        en    = 0;
        a     = 4'h0;
        b     = 4'h0;

        repeat (5) @(negedge clk);
        reset = 0;
    end

    // Дамп waveforms
    initial begin
        $dumpfile("build/vhfastmulb16_mul4x4.vcd");
        $dumpvars(0, vhfastmulb16_mul4x4_tb);
    end

    // Тестовые значения a и b
    reg [3:0] a_vals [0:15];
    reg [3:0] b_vals [0:15];

    initial begin
        a_vals[0]  = 4'h0;
        a_vals[1]  = 4'h1;
        a_vals[2]  = 4'h2;
        a_vals[3]  = 4'h3;
        a_vals[4]  = 4'h4;
        a_vals[5]  = 4'h5;
        a_vals[6]  = 4'h6;
        a_vals[7]  = 4'h7;
        a_vals[8]  = 4'h8;
        a_vals[9]  = 4'h9;
        a_vals[10] = 4'hA;
        a_vals[11] = 4'hB;
        a_vals[12] = 4'hC;
        a_vals[13] = 4'hD;
        a_vals[14] = 4'hE;
        a_vals[15] = 4'hF;

        b_vals[0]  = 4'h0;
        b_vals[1]  = 4'h1;
        b_vals[2]  = 4'h2;
        b_vals[3]  = 4'h3;
        b_vals[4]  = 4'h4;
        b_vals[5]  = 4'h5;
        b_vals[6]  = 4'h6;
        b_vals[7]  = 4'h7;
        b_vals[8]  = 4'h8;
        b_vals[9]  = 4'h9;
        b_vals[10] = 4'hA;
        b_vals[11] = 4'hB;
        b_vals[12] = 4'hC;
        b_vals[13] = 4'hD;
        b_vals[14] = 4'hE;
        b_vals[15] = 4'hF;
    end

    // Счётчики и переменные проверки
    integer i;
    integer j;
    integer checked;
    integer errors;
    reg [7:0] expected;
    reg [7:0] held;

    initial begin
        checked = 0;
        errors  = 0;

        // Ждём снятия сброса
        wait (reset == 0);
        repeat (2) @(negedge clk);

        // 256 векторов: все пары a x b
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                @(negedge clk);
                a  <= a_vals[i];
                b  <= b_vals[j];
                en <= 1'b1;

                @(negedge clk);
                expected = a_vals[i] * b_vals[j];
                checked  = checked + 1;
                if (c !== expected) begin
                    errors = errors + 1;
                    if (errors <= 10) begin
                        $display("[ERROR] Time: %0t | a=%0d b=%0d | Expected: %h, Got: %h",
                                 $time, a_vals[i], b_vals[j], expected, c);
                    end
                end
            end
        end

        // Проверка en=0: выход должен сохранять значение
        @(negedge clk);
        held = c;
        en <= 1'b0;
        a  <= 4'h5;
        b  <= 4'h7;
        repeat (2) @(negedge clk);
        if (c !== held) begin
            errors = errors + 1;
            $display("[ERROR] Time: %0t | en=0 hold | Expected: %h, Got: %h",
                     $time, held, c);
        end

        // Проверка reset: выход должен обнулиться
        @(negedge clk);
        en    <= 1'b1;
        reset <= 1'b1;
        @(negedge clk);
        if (c !== 8'h00) begin
            errors = errors + 1;
            $display("[ERROR] Time: %0t | reset | Expected: 00, Got: %h", $time, c);
        end
        @(negedge clk);
        reset <= 1'b0;

        // Итог
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

    // Watchdog
    initial begin
        #100000;
        $display("[ERROR] Testbench timeout!");
        $finish;
    end

endmodule
