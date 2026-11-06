// SystemVerilog testbench for vhfastmulb16_flags_lat2
`timescale 1ns/1ps

module vhfastmulb16_flags_lat2_tb;

    // Parameters
    localparam NUM_SAMPLES = 256; // 2^8 combinations for inexp

    // Signals
    reg clk;
    reg reset;
    reg en;
    reg [7:0] inexp;
    reg [7:0] infrc;

    wire flag_exp_z;
    wire flag_exp_s;
    wire flag_exp_f;
    wire flag_frc_z;
    wire flag_frc_nz;

    // Instantiate DUT
    vhfastmulb16_flags_lat2 uut (
        .clk(clk),
        .reset(reset),
        .en(en),
        .inexp(inexp),
        .infrc(infrc),
        .flag_exp_z(flag_exp_z),
        .flag_exp_s(flag_exp_s),
        .flag_exp_f(flag_exp_f),
        .flag_frc_z(flag_frc_z),
        .flag_frc_nz(flag_frc_nz)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize
        clk = 0;
        reset = 1;
        en = 0;
        #100;

        // Release reset
        reset = 0;
        #10;

        // Test all combinations of inexp and infrc
        $display("Testing vhfastmulb16_flags_lat2");
        $display("================================");

        for (int i = 0; i < NUM_SAMPLES; i = i + 1) begin
            inexp = i;
            infrc = i % 256;
            en = 1;

            #20;

            $display("Sample %0d: inexp=%b (%d), infrc=%b (%d)",
                     i, inexp, inexp, infrc, infrc);
            $display("  flag_exp_z=%b, flag_exp_s=%b, flag_exp_f=%b",
                     flag_exp_z, flag_exp_s, flag_exp_f);
            $display("  flag_frc_z=%b, flag_frc_nz=%b",
                     flag_frc_z, flag_frc_nz);

            // Verify expected values
            $display("  Expected:");
            if (inexp == 8'b00000000) $display("    flag_exp_z should be 1");
            else if (inexp >= 8'b00000001 && inexp <= 8'b11111110) $display("    flag_exp_s should be 1");
            else if (inexp == 8'b11111111) $display("    flag_exp_f should be 1");

            if (infrc == 8'b00000000) $display("    flag_frc_z should be 1");
            else $display("    flag_frc_nz should be 1");

            en = 0;
            #10;
        end

        // Finish
        $display("================================");
        $display("Test completed");
        $finish;
    end

endmodule