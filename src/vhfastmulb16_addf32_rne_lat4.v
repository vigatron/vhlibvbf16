// ----------------------------------------------
// vhlibvbf16 - Pipelined FP32 adder with RNE rounding.
// RNE = round-to-nearest-even (IEEE-754 default), без DSP.
// Author: Viktor Glebov / V01G04A81
// License: MIT
// https://github.com/vigatron/vhlibvbf16
// File: vhfastmulb16_addf32_rne_lat4.v
// Module: vhfastmulb16_addf32_rne_lat4
// FP32 + FP32 -> FP32 (round-to-nearest-even)
// Latency 4 clk, fully pipelined
// Subnormal inputs are treated as finite values (no FTZ).
// NaN payload: sign and mantissa fields preserved from the NaN operand.
// Zero sign: per IEEE-754 default (+0 + (-0) = +0; exact cancellation -> +0).
// en=0: HOLD (drain accepted data, keep last value)
// reset: synchronous, priority over en
// ----------------------------------------------

/**
 * @brief  Pipelined FP32 adder with round-to-nearest-even (RNE) rounding.
 *
 * Computes outf32c = inf32a + inf32b per IEEE-754 binary32 with default
 * rounding mode (round-to-nearest, ties to even).
 *
 * Rounding uses guard (G), round (R), sticky (S) bits obtained from the
 * normalized 27-bit mantissa (24-bit significand + G/R/S):
 *   G=0   -> truncate
 *   G=1, R|S=1 -> round up (increment significand)
 *   G=1, R=0, S=0 -> tie: round to even (increment if LSB of kept part = 1)
 *
 * Sticky bit is computed during mantissa alignment (S1) to capture bits
 * lost when the smaller operand is right-shifted for exponent matching.
 * Since the alignment shift is performed on a 27-bit extended value
 * (24 significand bits + 3 zero bits), a non-zero sticky implies that the
 * result is almost equal to the larger operand, hence the normalization
 * shift is at most 1 and the sticky stays in the G/R/S field.
 *
 * Subnormal operands are not flushed to zero: they are normalized into
 * the F32 result.
 *
 * NaN handling: sign and mantissa (payload) fields are preserved from
 * the NaN operand; the quiet bit (frac[22]) is forced to 1.
 *
 * Zero sign: per IEEE-754 default — (+0)+(-0) = +0, (-0)+(-0) = -0,
 * and exact cancellation of non-zero operands yields +0.
 *
 * Pipeline is balanced 4 stages:
 *   S1: operand unpack, class flags, exponent compare, mantissa alignment (with sticky)
 *   S2: mantissa add/sub (28-bit raw result, bit 27 = carry)
 *   S3: carry fix-up, normalization (LZD), 9-bit signed exponent
 *   S4: RNE rounding, subnormal shift, F32 pack -> output register
 *
 * @param clk     Clock signal.
 * @param reset   Synchronous reset, active high, priority over en.
 * @param en      Enable: accept a new sample when 1, hold when 0.
 * @param inf32a  First FP32 operand: [31] sign, [30:23] exp, [22:0] frac.
 * @param inf32b  Second FP32 operand: [31] sign, [30:23] exp, [22:0] frac.
 * @param outf32c FP32 result: [31] sign, [30:23] exp, [22:0] frac.
 */
module vhfastmulb16_addf32_rne_lat4 (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire [31:0] inf32a,
    input  wire [31:0] inf32b,
    output reg  [31:0] outf32c
);

    // ------------------------------------------------------------------
    // Operand unpack (combinational, stage S1)
    // ------------------------------------------------------------------
    wire       a_sign = inf32a[31];
    wire       b_sign = inf32b[31];
    wire [7:0] a_exp  = inf32a[30:23];
    wire [7:0] b_exp  = inf32b[30:23];
    wire [22:0] a_frac = inf32a[22:0];
    wire [22:0] b_frac = inf32b[22:0];

    wire a_exp_z  = (a_exp == 8'h00);
    wire b_exp_z  = (b_exp == 8'h00);
    wire a_frac_z = (a_frac == 23'h000000);
    wire b_frac_z = (b_frac == 23'h000000);

    wire a_zero = a_exp_z && a_frac_z;
    wire b_zero = b_exp_z && b_frac_z;
    wire a_sub  = a_exp_z && !a_frac_z;
    wire b_sub  = b_exp_z && !b_frac_z;
    wire a_inf  = (a_exp == 8'hFF) && a_frac_z;
    wire b_inf  = (b_exp == 8'hFF) && b_frac_z;
    wire a_nan  = (a_exp == 8'hFF) && !a_frac_z;
    wire b_nan  = (b_exp == 8'hFF) && !b_frac_z;

    // ------------------------------------------------------------------
    // Exception classification (combinational, stage S1)
    // ------------------------------------------------------------------
    wire res_nan  = a_nan || b_nan || (a_inf && b_inf && (a_sign != b_sign));
    wire res_inf  = !res_nan && (a_inf || b_inf);
    wire res_zero = !res_nan && !res_inf && (a_zero && b_zero);
    wire op_add   = (a_sign == b_sign);   // 1: add magnitudes, 0: subtract

    // ------------------------------------------------------------------
    // Effective exponent and mantissa (no FTZ for subnormals)
    //   normal:    value = {1'b1, frac} * 2^(exp - 127)
    //   subnormal: value = {1'b0, frac} * 2^(1 - 127) = frac * 2^-149
    // ------------------------------------------------------------------
    wire [7:0] a_exp_eff = a_exp_z ? 8'd1 : a_exp;
    wire [7:0] b_exp_eff = b_exp_z ? 8'd1 : b_exp;
    wire [23:0] a_man = a_exp_z ? {1'b0, a_frac} : {1'b1, a_frac};
    wire [23:0] b_man = b_exp_z ? {1'b0, b_frac} : {1'b1, b_frac};

    // NaN result: preserve sign and payload from the NaN operand, force quiet bit
    wire        nan_sign_c = a_nan ? a_sign : b_sign;
    wire [22:0] nan_frac_c = a_nan ? (a_frac | 23'h400000) : (b_frac | 23'h400000);

    // ------------------------------------------------------------------
    // Pipeline enable: 4 stages + output register.
    // After en=0 the pipeline drains 4 cycles, then holds.
    // ------------------------------------------------------------------
    reg en_d1;
    reg en_d2;
    reg en_d3;
    reg en_d4;

    always @(posedge clk) begin
        if (reset) begin
            en_d1 <= 1'b0;
            en_d2 <= 1'b0;
            en_d3 <= 1'b0;
            en_d4 <= 1'b0;
        end else begin
            en_d1 <= en;
            en_d2 <= en_d1;
            en_d3 <= en_d2;
            en_d4 <= en_d3;
        end
    end

    wire en_pipe = en | en_d1 | en_d2 | en_d3 | en_d4;

    // ------------------------------------------------------------------
    // Stage S1: exponent compare, mantissa alignment with sticky bit
    //   Combinational during cycle N, captured at N+1 edge
    // ------------------------------------------------------------------
    wire [7:0] exp_diff = (a_exp_eff >= b_exp_eff) ? (a_exp_eff - b_exp_eff) : (b_exp_eff - a_exp_eff);

    // Which operand has larger magnitude?
    wire a_larger = (a_exp_eff > b_exp_eff) ||
                    ((a_exp_eff == b_exp_eff) && (a_man >= b_man));

    // Sign of result (NaN and both-zero handled separately below)
    wire sign_res_c = res_nan ? nan_sign_c :
                      res_zero ? (a_sign & b_sign) :      // IEEE-754: (-0)+(-0)=-0
                      op_add ? a_sign : (a_larger ? a_sign : b_sign);

    // 27-bit extended mantissas: 24-bit significand + 3 low bits (G/R/S).
    // Alignment shifts the smaller significand right and ORs every lost
    // bit into the LSB (sticky).  A shift >= 27 flushes it completely.
    wire [26:0] a_man_ext = {a_man, 3'b000};
    wire [26:0] b_man_ext = {b_man, 3'b000};

    wire [4:0]  shift_amt = (exp_diff >= 8'd27) ? 5'd27 : exp_diff[4:0];
    wire [26:0] hi_man_ext = a_larger ? a_man_ext : b_man_ext;
    wire [26:0] lo_man_ext = a_larger ? b_man_ext : a_man_ext;

    wire [26:0] lo_shifted     = lo_man_ext >> shift_amt;
    wire [26:0] lo_sticky_mask = (27'd1 << shift_amt) - 27'd1;
    wire        lo_sticky      = |(lo_man_ext & lo_sticky_mask);
    wire [26:0] lo_man_al_c    = lo_shifted | {26'd0, lo_sticky};

    wire [7:0] exp_max_c = a_larger ? a_exp_eff : b_exp_eff;

    // ------------------------------------------------------------------
    // Stage S1 -> Stage S2 registers (capture at N+1 edge)
    // ------------------------------------------------------------------
    reg [26:0] man_hi_al_d1;
    reg [26:0] man_lo_al_d1;
    reg [7:0]  exp_max_d1;
    reg        sign_res_d1;
    reg        op_add_d1;
    reg [2:0]  flags_d1;        // {nan, inf, zero}
    reg        is_bz_d1;        // both inputs zero
    reg        zero_and_sign_d1;
    reg        nan_sign_d1;
    reg [22:0] nan_frac_d1;

    always @(posedge clk) begin
        if (reset) begin
            man_hi_al_d1     <= 27'd0;
            man_lo_al_d1     <= 27'd0;
            exp_max_d1       <= 8'd0;
            sign_res_d1      <= 1'b0;
            op_add_d1        <= 1'b0;
            flags_d1         <= 3'b000;
            is_bz_d1         <= 1'b0;
            zero_and_sign_d1 <= 1'b0;
            nan_sign_d1      <= 1'b0;
            nan_frac_d1      <= 23'd0;
        end else if (en_pipe) begin
            man_hi_al_d1     <= hi_man_ext;
            man_lo_al_d1     <= lo_man_al_c;
            exp_max_d1       <= exp_max_c;
            sign_res_d1      <= sign_res_c;
            op_add_d1        <= op_add;
            flags_d1         <= {res_nan, res_inf, res_zero};
            is_bz_d1         <= res_zero;
            zero_and_sign_d1 <= a_sign & b_sign;
            nan_sign_d1      <= nan_sign_c;
            nan_frac_d1      <= nan_frac_c;
        end
    end

    // ------------------------------------------------------------------
    // Stage S2: mantissa add/sub
    //   man_hi_al_d1 is always the larger magnitude, so subtraction is
    //   unconditional hi - lo (bit 27 is only set by addition carry).
    //   Combinational during cycle N+1, captured at N+2 edge
    // ------------------------------------------------------------------
    wire [27:0] man_raw_c = op_add_d1 ?
                            ({1'b0, man_hi_al_d1} + {1'b0, man_lo_al_d1}) :
                            ({1'b0, man_hi_al_d1} - {1'b0, man_lo_al_d1});

    // ------------------------------------------------------------------
    // Stage S2 -> Stage S3 registers (capture at N+2 edge)
    // ------------------------------------------------------------------
    reg [27:0] man_raw_d1;
    reg [7:0]  exp_max_d2;
    reg        sign_res_d2;
    reg [2:0]  flags_d2;
    reg        is_bz_d2;
    reg        zero_and_sign_d2;
    reg        nan_sign_d2;
    reg [22:0] nan_frac_d2;
    reg        is_zero_d2;   // exact cancellation (man_raw == 0, not both-inputs-zero)

    always @(posedge clk) begin
        if (reset) begin
            man_raw_d1     <= 28'd0;
            exp_max_d2     <= 8'd0;
            sign_res_d2    <= 1'b0;
            flags_d2       <= 3'b000;
            is_bz_d2       <= 1'b0;
            zero_and_sign_d2 <= 1'b0;
            nan_sign_d2    <= 1'b0;
            nan_frac_d2    <= 23'd0;
            is_zero_d2     <= 1'b0;
        end else if (en_pipe) begin
            man_raw_d1      <= man_raw_c;
            exp_max_d2      <= exp_max_d1;
            sign_res_d2     <= sign_res_d1;
            flags_d2        <= flags_d1;
            is_bz_d2        <= is_bz_d1;
            zero_and_sign_d2 <= zero_and_sign_d1;
            nan_sign_d2     <= nan_sign_d1;
            nan_frac_d2     <= nan_frac_d1;
            is_zero_d2      <= (man_raw_c == 28'd0) && !is_bz_d1;
        end
    end

    // ------------------------------------------------------------------
    // Stage S3: carry fix-up + normalization (LZD) + signed exponent
    //   Combinational during cycle N+2, captured at N+3 edge
    //   man_norm has its leading one at bit 26; exp_pre is a 9-bit
    //   two's-complement unbiased exponent (negative => subnormal).
    // ------------------------------------------------------------------
    wire        man_carry = man_raw_d1[27];
    wire [26:0] man_norm0 = man_carry ?
                            ({1'b0, man_raw_d1[27:1]} | {26'd0, man_raw_d1[0]}) :
                            man_raw_d1[26:0];
    wire [8:0]  exp_adj   = {1'b0, exp_max_d2} + {8'd0, man_carry};

    // Leading-zero detect on the full 27-bit extended mantissa
    reg [4:0] lzd_c;
    always @(*) begin
        casez (man_norm0)
            27'b1??????????????????????????: lzd_c = 5'd0;
            27'b01?????????????????????????: lzd_c = 5'd1;
            27'b001????????????????????????: lzd_c = 5'd2;
            27'b0001???????????????????????: lzd_c = 5'd3;
            27'b00001??????????????????????: lzd_c = 5'd4;
            27'b000001?????????????????????: lzd_c = 5'd5;
            27'b0000001????????????????????: lzd_c = 5'd6;
            27'b00000001???????????????????: lzd_c = 5'd7;
            27'b000000001??????????????????: lzd_c = 5'd8;
            27'b0000000001?????????????????: lzd_c = 5'd9;
            27'b00000000001????????????????: lzd_c = 5'd10;
            27'b000000000001???????????????: lzd_c = 5'd11;
            27'b0000000000001??????????????: lzd_c = 5'd12;
            27'b00000000000001?????????????: lzd_c = 5'd13;
            27'b000000000000001????????????: lzd_c = 5'd14;
            27'b0000000000000001???????????: lzd_c = 5'd15;
            27'b00000000000000001??????????: lzd_c = 5'd16;
            27'b000000000000000001?????????: lzd_c = 5'd17;
            27'b0000000000000000001????????: lzd_c = 5'd18;
            27'b00000000000000000001???????: lzd_c = 5'd19;
            27'b000000000000000000001??????: lzd_c = 5'd20;
            27'b0000000000000000000001?????: lzd_c = 5'd21;
            27'b00000000000000000000001????: lzd_c = 5'd22;
            27'b000000000000000000000001???: lzd_c = 5'd23;
            27'b0000000000000000000000001??: lzd_c = 5'd24;
            27'b00000000000000000000000001?: lzd_c = 5'd25;
            27'b000000000000000000000000001: lzd_c = 5'd26;
            default:                        lzd_c = 5'd26;
        endcase
    end

    wire [26:0] man_norm_c = man_norm0 << lzd_c;
    wire [8:0]  exp_pre_c  = exp_adj - {4'd0, lzd_c};

    // ------------------------------------------------------------------
    // Stage S3 -> Stage S4 registers (capture at N+3 edge)
    // ------------------------------------------------------------------
    reg [26:0] man_norm_d1;
    reg [8:0]  exp_pre_d1;
    reg        sign_res_d3;
    reg [2:0]  flags_d3;
    reg        is_bz_d3;
    reg        zero_and_sign_d3;
    reg        is_zero_d3;
    reg        nan_sign_d3;
    reg [22:0] nan_frac_d3;

    always @(posedge clk) begin
        if (reset) begin
            man_norm_d1    <= 27'd0;
            exp_pre_d1     <= 9'd0;
            sign_res_d3    <= 1'b0;
            flags_d3       <= 3'b000;
            is_bz_d3       <= 1'b0;
            zero_and_sign_d3 <= 1'b0;
            is_zero_d3     <= 1'b0;
            nan_sign_d3    <= 1'b0;
            nan_frac_d3    <= 23'd0;
        end else if (en_pipe) begin
            man_norm_d1    <= man_norm_c;
            exp_pre_d1     <= exp_pre_c;
            sign_res_d3    <= sign_res_d2;
            flags_d3       <= flags_d2;
            is_bz_d3       <= is_bz_d2;
            zero_and_sign_d3 <= zero_and_sign_d2;
            is_zero_d3     <= is_zero_d2;
            nan_sign_d3    <= nan_sign_d2;
            nan_frac_d3    <= nan_frac_d2;
        end
    end

    // ------------------------------------------------------------------
    // Stage S4: RNE rounding + F32 pack -> output register
    //
    // Normal result:
    //   kept = man_norm[26:3]  (24-bit significand, hidden bit at kept[23])
    //   G = man_norm[2], R = man_norm[1], S = man_norm[0]
    //   round up when G & (R | S | kept[0])  (ties to even)
    //   carry out of kept -> frac = 0, exponent + 1
    //   (the alignment sticky lives in man_norm[0]; see S1 note)
    //
    // Subnormal result (exp_pre <= 0):
    //   frac = man_norm >> (4 - exp_pre)
    //   G = bit below the 23-bit fraction, R = the next one,
    //   S = OR of all remaining low bits; carry out -> smallest normal
    // ------------------------------------------------------------------
    wire [23:0] kept     = man_norm_d1[26:3];
    wire        g_norm   = man_norm_d1[2];
    wire        r_norm   = man_norm_d1[1];
    wire        s_norm   = man_norm_d1[0];
    wire        rup_norm = g_norm && (r_norm | s_norm | kept[0]);

    wire [24:0] kept_inc = {1'b0, kept} + {24'd0, rup_norm};
    wire        ovf_norm = kept_inc[24];
    wire [23:0] kept_r   = ovf_norm ? 24'h800000 : kept_inc[23:0];
    wire [8:0]  exp_norm = exp_pre_d1 + {8'd0, ovf_norm};

    wire        sub_out   = exp_pre_d1[8] | (exp_pre_d1 == 9'd0);
    wire [4:0]  sub_shift = 5'd4 - exp_pre_d1[4:0];      // 4..29
    wire [26:0] man_grs   = man_norm_d1 >> (sub_shift - 5'd1);
    wire        g_sub     = man_grs[0];
    wire        r_sub     = man_grs[1];
    wire        s_sub     = |man_grs[2:0];
    wire [22:0] frac_raw  = man_grs[23:1];
    wire        rup_sub   = g_sub && (r_sub | s_sub | frac_raw[0]);

    wire [23:0] frac_inc = {1'b0, frac_raw} + {23'd0, rup_sub};
    wire        ovf_sub  = frac_inc[23];
    wire [22:0] frac_sub = frac_inc[22:0];

    wire        exp_ovf    = !sub_out && (exp_norm >= 9'd255);
    wire [7:0]  exp_final  = sub_out ? (ovf_sub ? 8'd1 : 8'd0) : exp_norm[7:0];
    wire [22:0] frac_final = sub_out ? (ovf_sub ? 23'd0 : frac_sub)
                                     : kept_r[22:0];

    reg [31:0] c_next;

    always @(*) begin
        if (flags_d3[2]) begin
            // NaN: preserve sign and payload, force quiet bit
            c_next = {nan_sign_d3, 8'hFF, nan_frac_d3};
        end else if (flags_d3[1] || exp_ovf) begin
            // Inf, or overflow after rounding: {sign, 255, 0}
            c_next = {sign_res_d3, 8'hFF, 23'h000000};
        end else if (flags_d3[0] || is_zero_d3) begin
            // Zero
            if (flags_d3[0])
                // Both inputs zero: sign = a_sign & b_sign (IEEE-754: (-0)+(-0)=-0)
                c_next = {zero_and_sign_d3, 31'h00000000};
            else
                // Exact cancellation: RNE -> +0
                c_next = {1'b0, 31'h00000000};
        end else begin
            // Normal or subnormal result (exp_final == 0 => subnormal)
            c_next = {sign_res_d3, exp_final, frac_final};
        end
    end

    // ------------------------------------------------------------------
    // Output register (cycle N+4)
    // reset has priority over en; en=0 holds the last value (HOLD).
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            outf32c <= 32'h0000_0000;
        end else if (en_pipe) begin
            outf32c <= c_next;
        end
        // else: HOLD (keep last value)
    end

endmodule
