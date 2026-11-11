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
 * Rounding uses guard (G), round (R), sticky (S) bits:
 *   G=0   -> truncate
 *   G=1, R|S=1 -> round up (increment significand)
 *   G=1, R=0, S=0 -> tie: round to even (increment if LSB of kept part = 1)
 *
 * Sticky bit is computed during mantissa alignment (S1) to capture bits
 * lost when the smaller operand is right-shifted for exponent matching.
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
 *   S2: mantissa add/sub (27-bit raw result)
 *   S3: normalization (LZD), RNE rounding, subnormal handling
 *   S4: F32 pack mux -> output register
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
    wire [4:0] exp_diff_capped = (exp_diff >= 5'd26) ? 5'd25 : exp_diff[4:0];

    // Which operand has larger magnitude?
    wire a_larger = (a_exp_eff > b_exp_eff) ||
                    ((a_exp_eff == b_exp_eff) && (a_man >= b_man));

    // Sign of result (NaN and both-zero handled separately below)
    wire sign_res_c = res_nan ? nan_sign_c :
                      res_zero ? (a_sign & b_sign) :      // IEEE-754: (-0)+(-0)=-0
                      op_add ? a_sign : (a_larger ? a_sign : b_sign);

    // Sticky bit computation: OR of bits lost during right-shift alignment
    // We use a 27-bit extended value {a_man, 3'b000} and shift right.
    // Bits shifted out beyond bit 0 contribute to sticky.
    reg [26:0] a_ext27_c;
    reg [26:0] b_ext27_c;
    reg        a_sticky_c;
    reg        b_sticky_c;
    reg [25:0] low_bits_mask;
    integer    ks;
    integer    kb;

    always @(*) begin
        a_ext27_c = {a_man, 3'b000};   // 27 bits: bits[26:3] = a_man[23:0], bits[2:0] = 000
        b_ext27_c = {b_man, 3'b000};
        a_sticky_c = 1'b0;
        b_sticky_c = 1'b0;
        for (ks = 0; ks < exp_diff_capped; ks = ks + 1) begin
            a_sticky_c = a_sticky_c | a_ext27_c[ks];
            b_sticky_c = b_sticky_c | b_ext27_c[ks];
        end
    end

    wire [25:0] a_man_al_c = a_larger ? {2'b00, a_man} : ({2'b00, a_man} >> exp_diff_capped);
    wire [25:0] b_man_al_c = a_larger ? ({2'b00, b_man} >> exp_diff_capped) : {2'b00, b_man};

    wire [7:0] exp_max_c = a_larger ? a_exp_eff : b_exp_eff;

    // ------------------------------------------------------------------
    // Stage S1 -> Stage S2 registers (capture at N+1 edge)
    // ------------------------------------------------------------------
    reg [25:0] man_a_al_d1;
    reg [25:0] man_b_al_d1;
    reg        sticky_d1;       // sticky from alignment
    reg [7:0]  exp_max_d1;
    reg        sign_res_d1;
    reg        op_add_d1;
    reg [2:0]  flags_d1;        // {nan, inf, zero}
    reg        is_bz_d1;        // both inputs zero
    reg        zero_and_sign_d1;
    reg        nan_sign_d1;
    reg [22:0] nan_frac_d1;
    reg        a_larger_d1;     // для корректного знака при вычитании

    always @(posedge clk) begin
        if (reset) begin
            man_a_al_d1     <= 26'd0;
            man_b_al_d1     <= 26'd0;
            sticky_d1       <= 1'b0;
            exp_max_d1      <= 8'd0;
            sign_res_d1     <= 1'b0;
            op_add_d1       <= 1'b0;
            flags_d1        <= 3'b000;
            is_bz_d1        <= 1'b0;
            zero_and_sign_d1 <= 1'b0;
            nan_sign_d1     <= 1'b0;
            nan_frac_d1     <= 23'd0;
            a_larger_d1     <= 1'b0;
        end else if (en_pipe) begin
            man_a_al_d1     <= a_man_al_c;
            man_b_al_d1     <= b_man_al_c;
            sticky_d1       <= a_sticky_c | b_sticky_c;
            exp_max_d1      <= exp_max_c;
            sign_res_d1     <= sign_res_c;
            op_add_d1       <= op_add;
            flags_d1        <= {res_nan, res_inf, res_zero};
            is_bz_d1        <= res_zero;
            zero_and_sign_d1 <= a_sign & b_sign;
            nan_sign_d1     <= nan_sign_c;
            nan_frac_d1     <= nan_frac_c;
            a_larger_d1     <= a_larger;
        end
    end

    // ------------------------------------------------------------------
    // Stage S2: mantissa add/sub
    //   Combinational during cycle N+1, captured at N+2 edge
    //   man_raw[26:0]: 27-bit result. Bit 26 = overflow/carry.
    //   sticky from alignment is ORed into bit 0 of the result.
    // ------------------------------------------------------------------
    wire [26:0] man_sum = op_add_d1 ?
                          ({1'b0, man_a_al_d1} + {1'b0, man_b_al_d1}) :
                          (a_larger_d1 ?
                           ({1'b0, man_a_al_d1} - {1'b0, man_b_al_d1}) :
                           ({1'b0, man_b_al_d1} - {1'b0, man_a_al_d1}));

    // sticky bit from alignment goes into bit 0
    wire [26:0] man_raw_c = man_sum | {26'd0, sticky_d1};

    // ------------------------------------------------------------------
    // Stage S2 -> Stage S3 registers (capture at N+2 edge)
    // ------------------------------------------------------------------
    reg [26:0] man_raw_d1;
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
            man_raw_d1     <= 27'd0;
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
            is_zero_d2      <= (man_raw_c == 27'd0) && !is_bz_d1;
        end
    end

    // ------------------------------------------------------------------
    // Stage S3: normalization, RNE rounding, subnormal handling
    //   Combinational during cycle N+2, captured at N+3 edge
    // ------------------------------------------------------------------
    wire man_overflow = man_raw_d1[24];               // result >= 2.0 -> shift right 1
    wire [25:0] man_norm1 = man_overflow ? man_raw_d1[25:0] >> 1 : man_raw_d1[25:0];
    wire sticky_after_shift = man_overflow ? man_raw_d1[0] : 1'b0;  // bit shifted out
    wire [7:0]  exp_norm1 = man_overflow ? exp_max_d2 + 8'd1 : exp_max_d2;

    // Leading-zero detect on man_norm1[23:0]
    reg [4:0] lzd_c;
    always @(*) begin
        casez (man_norm1[23:0])
            24'b1???????????????????????: lzd_c = 5'd0;
            24'b01??????????????????????: lzd_c = 5'd1;
            24'b001?????????????????????: lzd_c = 5'd2;
            24'b0001????????????????????: lzd_c = 5'd3;
            24'b00001???????????????????: lzd_c = 5'd4;
            24'b000001??????????????????: lzd_c = 5'd5;
            24'b0000001?????????????????: lzd_c = 5'd6;
            24'b00000001????????????????: lzd_c = 5'd7;
            24'b000000001???????????????: lzd_c = 5'd8;
            24'b0000000001??????????????: lzd_c = 5'd9;
            24'b00000000001?????????????: lzd_c = 5'd10;
            24'b000000000001????????????: lzd_c = 5'd11;
            24'b0000000000001???????????: lzd_c = 5'd12;
            24'b00000000000001??????????: lzd_c = 5'd13;
            24'b000000000000001?????????: lzd_c = 5'd14;
            24'b0000000000000001????????: lzd_c = 5'd15;
            24'b00000000000000001???????: lzd_c = 5'd16;
            24'b000000000000000001??????: lzd_c = 5'd17;
            24'b0000000000000000001?????: lzd_c = 5'd18;
            24'b00000000000000000001????: lzd_c = 5'd19;
            24'b000000000000000000001???: lzd_c = 5'd20;
            24'b0000000000000000000001??: lzd_c = 5'd21;
            24'b00000000000000000000001?: lzd_c = 5'd22;
            default:                     lzd_c = 5'd23;
        endcase
    end

    // LZD shift capped at exp_norm1 to avoid negative exponent
    wire lzd_gt_exp = ({3'd0, lzd_c} > exp_norm1);
    wire [4:0] lzd_eff = lzd_gt_exp ? exp_norm1[4:0] : lzd_c;

    reg  [25:0] man_shifted_r;
    reg         sticky_shifted_r;
    wire [25:0] man_shifted = man_shifted_r;
    wire        sticky_shifted = sticky_shifted_r;
    wire [7:0]  exp_pre = lzd_gt_exp ? 8'd0 : (exp_norm1 - lzd_c);

    always @(*) begin
        man_shifted_r = man_norm1 << lzd_eff;
        sticky_shifted_r = sticky_after_shift;
        low_bits_mask = 26'd0;
        for (kb = 0; kb < lzd_eff; kb = kb + 1)
            low_bits_mask[kb] = 1'b1;
        if (lzd_eff > 0)
            sticky_shifted_r = sticky_shifted_r | |(man_norm1 & low_bits_mask);
    end

    // Subnormal output: exp <= 0
    wire subnormal_out = lzd_gt_exp || (exp_pre == 8'd0);
    wire [7:0]  exp_final = subnormal_out ? 8'd0 : exp_pre;

    // ---------- RNE rounding ----------
    // After normalization, man_shifted[23:0] = 24-bit significand (hidden + 23 frac).
    // man_shifted[25:24] = extension bits (guard territory).
    // G = man_shifted[24], R = man_shifted[23]? No.
    // 
    // Correct mapping for 26-bit man_shifted:
    //   bit[23] = hidden bit (always 1 for normal)
    //   bit[22:0] = 23 fraction bits (kept)
    //   bit[24] = guard bit (first bit after kept fraction)
    //   bit[25] = round bit (second bit after kept fraction)
    //   sticky = OR of all bits below bit 24 (i.e., sticky_shifted | any bits below)
    //
    // Wait: man_shifted[25:0]. If bit[23] is hidden, then:
    //   Kept significand: bits[23:0] (24 bits)
    //   Guard: bit[24]
    //   Round: bit[25]
    //   Sticky: sticky_shifted (bits shifted out by LZD or overflow shift)

    wire g_bit = man_shifted[24];
    wire r_bit = man_shifted[25];
    wire s_bit = sticky_shifted;

    wire round_up = g_bit && (r_bit | s_bit | man_shifted[23]);  // G=1 and (R|S|LSB_of_kept)

    // Increment significand if rounding up
    wire [25:0] man_inc = {1'b0, man_shifted[23:0]} + 26'd1;  // increment kept part
    wire inc_carry = man_inc[25];  // carry from bit 23 to bit 24 (significand overflow)

    wire [23:0] man_rounded_24 = round_up ?
                                 (inc_carry ? {1'b0, man_shifted[23:1]} : man_inc[23:0]) :
                                 man_shifted[23:0];
    // If significand overflowed (all ones + carry), shift right: hidden=1, frac=0
    wire [7:0]  exp_rounded = exp_final + ((round_up && inc_carry) ? 8'd1 : 8'd0);

    wire [22:0] frac_normal = man_rounded_24[22:0];

    // For subnormal output: frac = man_norm1 << (exp_norm1 - 1), masked to 23 bits
    reg  [25:0] man_sub_ext_r;
    reg         sticky_sub_r;
    wire [25:0] man_sub_ext = man_sub_ext_r;
    wire        sticky_sub = sticky_sub_r;

    always @(*) begin
        if (exp_norm1 > 0)
            man_sub_ext_r = man_norm1 << (exp_norm1 - 8'd1);
        else
            man_sub_ext_r = man_norm1;
        sticky_sub_r = 1'b0;
    end

    wire [22:0] frac_subnormal_raw = man_sub_ext[22:0];

    // Subnormal rounding: kept = bits[22:0], guard = bit[23], round = bit[24], sticky = sticky_shifted | bits below
    wire g_sub_c = man_sub_ext[23];
    wire r_sub_c = man_sub_ext[24];
    wire s_sub_c = sticky_shifted;  // bits already shifted out by LZD
    wire round_up_sub_c = g_sub_c && (r_sub_c | s_sub_c | man_sub_ext[22]);

    wire [23:0] man_sub_inc = {1'b0, man_sub_ext[22:0]} + 24'd1;
    wire sub_inc_carry = man_sub_inc[23];
    wire [22:0] frac_subnormal = round_up_sub_c ?
                                 (sub_inc_carry ? 23'h000000 : man_sub_inc[22:0]) :
                                 man_sub_ext[22:0];
    wire sub_round_overflow = round_up_sub_c && sub_inc_carry;  // if carry, frac=0, exp becomes 1

    wire [22:0] frac_c = subnormal_out ?
                         (sub_round_overflow ? 23'h000000 : frac_subnormal) :
                         frac_normal;

    wire [7:0]  exp_final_c = subnormal_out && sub_round_overflow ? 8'd1 : exp_rounded;

    // ------------------------------------------------------------------
    // Stage S3 -> Stage S4 registers (capture at N+3 edge)
    // ------------------------------------------------------------------
    reg [22:0] frac_d1;
    reg [7:0]  exp_final_d1;
    reg        sign_res_d3;
    reg [2:0]  flags_d3;
    reg        is_bz_d3;
    reg        zero_and_sign_d3;
    reg        is_zero_d3;
    reg        nan_sign_d3;
    reg [22:0] nan_frac_d3;

    always @(posedge clk) begin
        if (reset) begin
            frac_d1        <= 23'd0;
            exp_final_d1   <= 8'd0;
            sign_res_d3    <= 1'b0;
            flags_d3       <= 3'b000;
            is_bz_d3       <= 1'b0;
            zero_and_sign_d3 <= 1'b0;
            is_zero_d3     <= 1'b0;
            nan_sign_d3    <= 1'b0;
            nan_frac_d3    <= 23'd0;
        end else if (en_pipe) begin
            frac_d1        <= frac_c;
            exp_final_d1   <= exp_final_c;
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
    // Stage S4: F32 pack (combinational) -> output register
    // ------------------------------------------------------------------
    reg [31:0] c_next;

    always @(*) begin
        if (flags_d3[2]) begin
            // NaN: preserve sign and payload, force quiet bit
            c_next = {nan_sign_d3, 8'hFF, nan_frac_d3};
        end else if (flags_d3[1] || exp_final_d1 >= 8'hFF) begin
            // Inf or overflow: {sign, 255, 0}
            c_next = {sign_res_d3, 8'hFF, 23'h000000};
        end else if (flags_d3[0] || is_zero_d3) begin
            // Zero
            if (flags_d3[0])
                // Both inputs zero: sign = a_sign & b_sign (IEEE-754: (-0)+(-0)=-0)
                c_next = {zero_and_sign_d3, 31'h00000000};
            else
                // Exact cancellation: RNE -> +0
                c_next = {1'b0, 31'h00000000};
        end else if (exp_final_d1 >= 8'd1) begin
            // Normal F32 result
            c_next = {sign_res_d3, exp_final_d1, frac_d1};
        end else begin
            // F32 subnormal result: exp = 0, rounded significand
            c_next = {sign_res_d3, 8'h00, frac_d1};
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
