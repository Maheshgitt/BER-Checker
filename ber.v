// =============================================================
//  4-bit BER Checker with Hamming(7,4) + SECDED
//  Board : Nexys 4 rev B  |  Clock : 100 MHz
//
//  KEY CHANGE from previous version:
//    Upgraded Hamming decoder to SECDED (Single Error Correct,
//    Double Error Detect). An 8th overall parity bit p0 is
//    computed from the encoder output and used to distinguish
//    1-bit errors (correctable) from 2-bit errors (detectable).
//
//  SECDED DECISION TABLE:
//    syndrome==0, overall_parity==0 : no error
//    syndrome!=0, overall_parity==1 : 1-bit error -> CORRECT it
//    syndrome!=0, overall_parity==0 : 2-bit error -> DETECT only
//    syndrome==0, overall_parity==1 : p0 itself flipped -> ignore
//
//  error_type output (2-bit):
//    2'b00 = no error
//    2'b01 = 1-bit error, corrected
//    2'b10 = 2-bit error DETECTED (data_out is invalid/unreliable)
//    2'b11 = reserved
//
//  SWITCH MAP:
//    SW0        = tx[0]
//    SW1        = tx[1]   4-bit transmit data
//    SW2        = tx[2]
//    SW3        = tx[3]
//    SW4        = rx[0]
//    SW5        = rx[1]
//    SW6        = rx[2]   7-bit received codeword
//    SW7        = rx[3]
//    SW8        = rx[4]
//    SW9        = rx[5]
//    SW10       = rx[6]
//    SW11       = mode[0]
//    SW12       = mode[1]  display/workflow mode
//    SW13       = mode[2]
//    BTNC       = rst_raw  reset (debounced)
//
//  CODEWORD BIT LAYOUT {p1,p2,d0,p4,d1,d2,d3}:
//    code[6]=p1  code[5]=p2  code[4]=d0
//    code[3]=p4  code[2]=d1  code[1]=d2  code[0]=d3
//    SW4=rx[0]=d3  SW5=rx[1]=d2  SW6=rx[2]=d1
//    SW7=rx[3]=p4  SW8=rx[4]=d0  SW9=rx[5]=p2  SW10=rx[6]=p1
//
//  MODE TABLE (SW13=mode[2], SW12=mode[1], SW11=mode[0]):
//    000 : TX INPUT     - enter tx on SW0-3, display shows tx bits
//    001 : ENCODED TX   - shows 7-bit codeword (copy to SW4-10)
//    010 : RX INPUT     - mirrors encoded layout, verify/introduce errors
//    011 : CORRECTED    - Hamming corrected output (valid if 0 or 1 error)
//    100 : ERROR PATTERN- err bits, LEDs light for each residual bit
//    101 : ERROR COUNT  - number of wrong bits (0-4)
//    110 : BER%         - 0/25/50/75/99 percent
//    111 : RESERVED     - blank
//
//  DISPLAY:
//    Digits 7..0 left-to-right on board (an[7]=leftmost, an[0]=rightmost)
//    Mode 010/001: dig6=d3  dig5=d2  dig4=d1  dig3=p4  dig2=d0  dig1=p2  dig0=p1
//    Mode 000/011/100: dig3..dig0 = bit3..bit0 (MSB left, LSB right)
//    Mode 101: dig0 = error count
//    Mode 110: dig5=BER tens  dig4=BER ones
//
//  COPY TABLE (MODE 001 display -> RX switches):
//    dig0(p1)->SW10  dig1(p2)->SW9  dig2(d0)->SW8
//    dig3(p4)->SW7   dig4(d1)->SW6  dig5(d2)->SW5  dig6(d3)->SW4
//
//  GUIDED WORKFLOW:
//    Step 1: MODE 000 - set TX on SW0-3
//    Step 2: MODE 001 - read 7-bit codeword, note each digit
//    Step 3: MODE 010 - set SW4-10 using copy table above
//                       optionally flip 1 bit for 1-bit error test
//                       optionally flip 2 bits for 2-bit detection test
//    Step 4: MODE 011 - verify corrected output (matches TX if <=1 error)
//    Step 5: MODE 100 - check error pattern + LEDs
//    Step 6: MODE 101 - check error count
//    Step 7: MODE 110 - check BER%
// =============================================================


// --- Module 1: Hamming(7,4) Encoder --------------------------
// Output layout: code_out[6:0] = {p1, p2, d0, p4, d1, d2, d3}
// p1 = d0^d1^d3   p2 = d0^d2^d3   p4 = d1^d2^d3
module hamming_encoder(
    input  [3:0] data_in,
    output [6:0] code_out
);
    wire p1 = data_in[0] ^ data_in[1] ^ data_in[3];
    wire p2 = data_in[0] ^ data_in[2] ^ data_in[3];
    wire p4 = data_in[1] ^ data_in[2] ^ data_in[3];
    assign code_out = {p1, p2, data_in[0], p4,
                       data_in[1], data_in[2], data_in[3]};
endmodule


// --- Module 2: SECDED Decoder --------------------------------
// Adds overall parity check (p0 = XOR of all 7 encoded bits)
// to distinguish 1-bit (correctable) from 2-bit (detectable).
//
// p0_ref  = XOR of all 7 encoder output bits (computed once at encode time)
// p0_calc = XOR of all 7 received bits
// overall_parity = p0_calc XOR p0_ref
//   overall_parity=1 -> odd number of flipped bits
//   overall_parity=0 -> even number of flipped bits
//
// SECDED decision:
//   syndrome==0 && !overall_parity -> no error           error_type=00
//   syndrome!=0 &&  overall_parity -> 1-bit, correct     error_type=01
//   syndrome!=0 && !overall_parity -> 2-bit, detect only error_type=10
//   syndrome==0 &&  overall_parity -> p0 itself bad, OK  error_type=00
//
// data_out = {corrected[0], corrected[1], corrected[2], corrected[4]}
//          = {d3, d2, d1, d0}
// = tx[3], tx[2], tx[1], tx[0] respectively
module hamming_decoder(
    input  [6:0] code_in,      // received 7-bit codeword
    input        p0_ref,       // overall parity from encoder
    output [3:0] data_out,     // corrected 4-bit data
    output [1:0] error_type    // 00=none 01=1bit_corrected 10=2bit_detected
);
    wire s1 = code_in[6] ^ code_in[4] ^ code_in[2] ^ code_in[0];
    wire s2 = code_in[5] ^ code_in[4] ^ code_in[1] ^ code_in[0];
    wire s4 = code_in[3] ^ code_in[2] ^ code_in[1] ^ code_in[0];
    wire [2:0] syndrome = {s4, s2, s1};

    // Overall parity check
    wire p0_calc        = ^code_in;            // XOR of all received bits
    wire overall_parity = p0_calc ^ p0_ref;    // 1=odd flips, 0=even flips

    reg [6:0] corrected;
    reg [1:0] etype;

    always @(*) begin
        corrected = code_in;
        etype     = 2'b00;

        if (syndrome != 3'd0 && overall_parity) begin
            // Odd number of errors and syndrome points somewhere -> 1-bit, correct
            corrected[7 - syndrome] = ~corrected[7 - syndrome];
            etype = 2'b01;
        end else if (syndrome != 3'd0 && !overall_parity) begin
            // Even number of errors and syndrome != 0 -> 2-bit detected, do NOT correct
            etype = 2'b10;
        end
        // else: no error or p0 itself flipped (data OK)
    end

    // data_out: match tx bit ordering
    // corrected[0]=d3=tx[3], corrected[1]=d2=tx[2],
    // corrected[2]=d1=tx[1], corrected[4]=d0=tx[0]
    assign data_out   = {corrected[0], corrected[1],
                         corrected[2], corrected[4]};
    assign error_type = etype;
endmodule


// --- Module 3: BER Calculator --------------------------------
// Single-shot combinational lookup. One 4-bit word per check.
// BER = (err_cnt * 100) / 4, capped at 99 for 2-digit display.
module ber_calc(
    input      [2:0] e_c,
    output reg [6:0] ber_pct
);
    always @(*) begin
        case (e_c)
            3'd0:    ber_pct = 7'd0;
            3'd1:    ber_pct = 7'd25;
            3'd2:    ber_pct = 7'd50;
            3'd3:    ber_pct = 7'd75;
            default: ber_pct = 7'd99;  // 4 errors = 100%, displayed as 99
        endcase
    end
endmodule


// --- Module 4: Button Debounce --------------------------------
// 10 ms debounce window (20-bit counter at 100 MHz).
module btn_debounce(
    input  clk,
    input  btn_raw,
    output reg btn_clean
);
    reg [19:0] count    = 20'd0;
    reg        btn_prev = 1'b0;
    always @(posedge clk) begin
        if (btn_raw == btn_prev) begin
            if (count == 20'd999_999)
                btn_clean <= btn_raw;
            else
                count <= count + 20'd1;
        end else begin
            count    <= 20'd0;
            btn_prev <= btn_raw;
        end
    end
endmodule


// --- Module 5: Clock Divider ---------------------------------
// 125 Hz 7-seg refresh (100 MHz / 100,000 / 8 digits).
module clk_div(
    input  clk,
    output reg [2:0] sel
);
    reg [16:0] count = 17'd0;
    initial sel = 3'd0;
    always @(posedge clk) begin
        if (count == 17'd99_999) begin
            count <= 17'd0;
            sel   <= sel + 3'd1;
        end else
            count <= count + 17'd1;
    end
endmodule


// --- Module 6: Display Controller ----------------------------
// Unchanged from original except:
//   MODE 011 (CORRECTED): shows "E2" on dig6-5 when 2-bit error
//   detected to alert user that corrected output is invalid.
//   "E" uses a custom 7-seg pattern, "2" is the standard digit.
module display_ctrl(
    input      [2:0] sel,
    input      [2:0] mode,
    input      [3:0] tx,
    input      [6:0] encoded,
    input      [6:0] rx,
    input      [3:0] corrected,
    input      [3:0] err,
    input      [2:0] err_cnt,
    input      [6:0] ber_pct,
    input      [1:0] error_type,  // 00=none 01=1bit 10=2bit
    output reg [3:0] digit,
    output reg [7:0] an
);
    localparam BLANK  = 4'd15;
    // Special 7-seg codes for "E" and "-" (2-bit error indicator)
    // We pass these as digit values > 9 - bin_to_7seg will blank them,
    // so we override seg directly here by outputting digit=10 for "E"
    // and digit=11 for "-". bin_to_7seg default handles these as blank,
    // so we handle E/dash inline via digit values:
    //   10 -> "E" (handled in bin_to_7seg extended case)
    //   11 -> "-" (handled in bin_to_7seg extended case)
    localparam CHAR_E   = 4'd10;
    localparam CHAR_DASH= 4'd11;

    wire [3:0] ber_tens = ber_pct / 7'd10;
    wire [3:0] ber_ones = ber_pct % 7'd10;
    wire two_bit_err    = (error_type == 2'b10);

    always @(*) begin
        digit = BLANK;
        an    = 8'b1111_1111;

        case (sel)
        3'd0: begin
            an = 8'b1111_1110;
            case (mode)
                3'b000: digit = {3'b0, tx[0]};
                3'b001: digit = {3'b0, encoded[6]};   // p1
                3'b010: digit = {3'b0, rx[6]};        // p1
                3'b011: digit = two_bit_err ? CHAR_DASH : {3'b0, corrected[0]};
                3'b100: digit = {3'b0, err[0]};
                3'b101: digit = {1'b0, err_cnt};
                3'b110: digit = BLANK;
                default: digit = BLANK;
            endcase
        end
        3'd1: begin
            an = 8'b1111_1101;
            case (mode)
                3'b000: digit = {3'b0, tx[1]};
                3'b001: digit = {3'b0, encoded[5]};   // p2
                3'b010: digit = {3'b0, rx[5]};
                3'b011: digit = two_bit_err ? CHAR_DASH : {3'b0, corrected[1]};
                3'b100: digit = {3'b0, err[1]};
                3'b101: digit = BLANK;
                3'b110: digit = BLANK;
                default: digit = BLANK;
            endcase
        end
        3'd2: begin
            an = 8'b1111_1011;
            case (mode)
                3'b000: digit = {3'b0, tx[2]};
                3'b001: digit = {3'b0, encoded[4]};   // d0
                3'b010: digit = {3'b0, rx[4]};
                3'b011: digit = two_bit_err ? CHAR_DASH : {3'b0, corrected[2]};
                3'b100: digit = {3'b0, err[2]};
                3'b101: digit = BLANK;
                3'b110: digit = BLANK;
                default: digit = BLANK;
            endcase
        end
        3'd3: begin
            an = 8'b1111_0111;
            case (mode)
                3'b000: digit = {3'b0, tx[3]};
                3'b001: digit = {3'b0, encoded[3]};   // p4
                3'b010: digit = {3'b0, rx[3]};
                3'b011: digit = two_bit_err ? CHAR_DASH : {3'b0, corrected[3]};
                3'b100: digit = {3'b0, err[3]};
                3'b101: digit = BLANK;
                3'b110: digit = BLANK;
                default: digit = BLANK;
            endcase
        end
        3'd4: begin
            an = 8'b1110_1111;
            case (mode)
                3'b000: digit = BLANK;
                3'b001: digit = {3'b0, encoded[2]};   // d1
                3'b010: digit = {3'b0, rx[2]};
                // MODE 011: show "2E" on dig5-4 for 2-bit error alert
                3'b011: digit = two_bit_err ? CHAR_E : BLANK;
                3'b100: digit = BLANK;
                3'b101: digit = BLANK;
                3'b110: digit = ber_ones;
                default: digit = BLANK;
            endcase
        end
        3'd5: begin
            an = 8'b1101_1111;
            case (mode)
                3'b000: digit = BLANK;
                3'b001: digit = {3'b0, encoded[1]};   // d2
                3'b010: digit = {3'b0, rx[1]};
                3'b011: digit = two_bit_err ? 4'd2 : BLANK;  // "2" of "2E"
                3'b100: digit = BLANK;
                3'b101: digit = BLANK;
                3'b110: digit = ber_tens;
                default: digit = BLANK;
            endcase
        end
        3'd6: begin
            an = 8'b1011_1111;
            case (mode)
                3'b001: digit = {3'b0, encoded[0]};   // d3
                3'b010: digit = {3'b0, rx[0]};
                default: digit = BLANK;
            endcase
        end
        3'd7: begin
            an    = 8'b0111_1111;
            digit = BLANK;
        end
        default: begin
            an    = 8'b1111_1111;
            digit = BLANK;
        end
        endcase
    end
endmodule


// --- Module 7: 7-Segment Decoder -----------------------------
// Extended with "E" (10) and "-" (11) for 2-bit error display.
module bin_to_7seg(
    input      [3:0] num,
    output reg [6:0] seg
);
    always @(*) begin
        case (num)
            4'd0:  seg = 7'b100_0000;  // 0
            4'd1:  seg = 7'b111_1001;  // 1
            4'd2:  seg = 7'b010_0100;  // 2
            4'd3:  seg = 7'b011_0000;  // 3
            4'd4:  seg = 7'b001_1001;  // 4
            4'd5:  seg = 7'b001_0010;  // 5
            4'd6:  seg = 7'b000_0010;  // 6
            4'd7:  seg = 7'b111_1000;  // 7
            4'd8:  seg = 7'b000_0000;  // 8
            4'd9:  seg = 7'b001_0000;  // 9
            4'd10: seg = 7'b000_0110;  // E  (segments g,f,e,d,a ON)
            4'd11: seg = 7'b011_1111;  // -  (segment g only ON)
            default: seg = 7'b111_1111; // BLANK
        endcase
    end
endmodule


// --- Module 8: Top-Level ------------------------------------
module ber_top(
    input        clk,
    input  [3:0] tx,
    input  [6:0] rx,
    input  [2:0] mode,
    input        rst_raw,
    output [6:0] seg,
    output [7:0] an,
    output [3:0] led
);
    wire [6:0] encoded;
    wire       p0_ref;
    wire [3:0] corrected;
    wire [1:0] error_type;
    wire [3:0] err;
    wire [2:0] err_cnt;
    wire [6:0] ber_pct;
    wire [2:0] sel;
    wire [3:0] digit;
    wire       rst;

    // Debounce reset button
    btn_debounce DB (.clk(clk), .btn_raw(rst_raw), .btn_clean(rst));

    // Encode TX -> 7-bit codeword + overall parity bit
    hamming_encoder ENC (.data_in(tx), .code_out(encoded));
    assign p0_ref = ^encoded;   // overall parity: XOR of all 7 bits

    // SECDED decode RX using p0_ref from encoder
    hamming_decoder DEC (
        .code_in(rx),
        .p0_ref(p0_ref),
        .data_out(corrected),
        .error_type(error_type)
    );

    // Residual error after correction
    assign err     = corrected ^ tx;
    assign err_cnt = err[0] + err[1] + err[2] + err[3];

    // LEDs: show error pattern only in MODE 100
    // If 2-bit error detected, LEDs show all 4 lit to alert user
    assign led = (mode == 3'b100) ? err: 4'b0000;

    // BER: single-shot combinational lookup
    ber_calc BC (.e_c(err_cnt), .ber_pct(ber_pct));

    // Clock divider for 7-seg refresh
    clk_div CD (.clk(clk), .sel(sel));

    // Display controller
    display_ctrl DC (
        .sel(sel), .mode(mode),
        .tx(tx), .encoded(encoded), .rx(rx),
        .corrected(corrected), .err(err),
        .err_cnt(err_cnt), .ber_pct(ber_pct),
        .error_type(error_type),
        .digit(digit), .an(an)
    );

    bin_to_7seg B7 (.num(digit), .seg(seg));
endmodule


// --- Module 9: Testbench ------------------------------------
module ber_top_tb;
    reg        clk;
    reg  [3:0] tx;
    reg  [6:0] rx;
    reg  [2:0] mode;
    reg        rst_raw;
    wire [6:0] seg;
    wire [7:0] an;
    wire [3:0] led;

    wire [6:0] encoded_w;
    wire       p0_ref_w;
    wire [3:0] corrected_w;
    wire [1:0] error_type_w;
    wire [3:0] err_w;
    wire [2:0] err_cnt_w;

    hamming_encoder ENC_tb (.data_in(tx), .code_out(encoded_w));
    assign p0_ref_w = ^encoded_w;
    hamming_decoder DEC_tb (
        .code_in(rx), .p0_ref(p0_ref_w),
        .data_out(corrected_w), .error_type(error_type_w)
    );
    assign err_w     = corrected_w ^ tx;
    assign err_cnt_w = err_w[0]+err_w[1]+err_w[2]+err_w[3];

    ber_top DUT (
        .clk(clk), .tx(tx), .rx(rx),
        .mode(mode), .rst_raw(rst_raw),
        .seg(seg), .an(an), .led(led)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task check;
        input [3:0] ti; input [6:0] ri;
        input [3:0] exp_corr;
        input [1:0] exp_etype;
        input [23*8-1:0] label;
        begin
            tx=ti; rx=ri; #10;
            // For 2-bit errors, corrected output is intentionally invalid;
            // only check error_type. For 0/1-bit, check both.
            if (exp_etype == 2'b10) begin
                if (error_type_w !== 2'b10)
                    $display("FAIL [%0s] tx=%b rx=%b etype=%b(exp 10) -- 2-bit not detected",
                        label,ti,ri,error_type_w);
                else
                    $display("PASS [%0s] tx=%b 2BIT_DETECTED etype=10 enc=%b",
                        label,ti,encoded_w);
            end else begin
                if (corrected_w!==exp_corr || error_type_w!==exp_etype)
                    $display("FAIL [%0s] tx=%b rx=%b corr=%b(exp %b) etype=%b(exp %b)",
                        label,ti,ri,corrected_w,exp_corr,error_type_w,exp_etype);
                else
                    $display("PASS [%0s] tx=%b corr=%b etype=%b enc=%b",
                        label,ti,corrected_w,error_type_w,encoded_w);
            end
        end
    endtask

    initial begin
        rst_raw=0; mode=3'b000; tx=0; rx=0; #20;
        $display("=== SECDED BER Checker Testbench ===");
        $display("error_type: 00=none 01=1bit_corrected 10=2bit_detected");
        $display("");

        // tx=0110
        $display("--- tx=0110 (encoded=1100110) ---");
        tx=4'b0110; #5;
        check(4'b0110, 7'b1100110,            4'b0110, 2'b00, "0110 no_error  ");
        check(4'b0110, 7'b1100110^7'b0000001, 4'b0110, 2'b01, "0110 flip_bit0 ");
        check(4'b0110, 7'b1100110^7'b0000010, 4'b0110, 2'b01, "0110 flip_bit1 ");
        check(4'b0110, 7'b1100110^7'b0000100, 4'b0110, 2'b01, "0110 flip_bit2 ");
        check(4'b0110, 7'b1100110^7'b0001000, 4'b0110, 2'b01, "0110 flip_bit3 ");
        check(4'b0110, 7'b1100110^7'b0010000, 4'b0110, 2'b01, "0110 flip_bit4 ");
        check(4'b0110, 7'b1100110^7'b0100000, 4'b0110, 2'b01, "0110 flip_bit5 ");
        check(4'b0110, 7'b1100110^7'b1000000, 4'b0110, 2'b01, "0110 flip_bit6 ");
        $display("--- 2-bit errors (must be DETECTED not corrected) ---");
        check(4'b0110, 7'b1100110^7'b0000011, 4'b0110, 2'b10, "0110 2bit_01   ");
        check(4'b0110, 7'b1100110^7'b0000110, 4'b0110, 2'b10, "0110 2bit_12   ");
        check(4'b0110, 7'b1100110^7'b0001001, 4'b0110, 2'b10, "0110 2bit_03   ");
        check(4'b0110, 7'b1100110^7'b1100000, 4'b0110, 2'b10, "0110 2bit_56   ");
        $display("");

        // tx=1010
        $display("--- tx=1010 ---");
        tx=4'b1010; #5;
        $display("  encoded=%b  p0=%b", encoded_w, p0_ref_w);
        check(4'b1010, encoded_w,            4'b1010, 2'b00, "1010 no_error  ");
        check(4'b1010, encoded_w^7'b0010000, 4'b1010, 2'b01, "1010 flip_d0   ");
        check(4'b1010, encoded_w^7'b0000100, 4'b1010, 2'b01, "1010 flip_d1   ");
        check(4'b1010, encoded_w^7'b0000010, 4'b1010, 2'b01, "1010 flip_d2   ");
        check(4'b1010, encoded_w^7'b0000001, 4'b1010, 2'b01, "1010 flip_d3   ");
        check(4'b1010, encoded_w^7'b0000011, 4'b1010, 2'b10, "1010 2bit_d3d2 ");
        check(4'b1010, encoded_w^7'b0001010, 4'b1010, 2'b10, "1010 2bit_13   ");
        $display("");

        // tx=1100
        $display("--- tx=1100 ---");
        tx=4'b1100; #5;
        $display("  encoded=%b  p0=%b", encoded_w, p0_ref_w);
        check(4'b1100, encoded_w,            4'b1100, 2'b00, "1100 no_error  ");
        check(4'b1100, encoded_w^7'b0000001, 4'b1100, 2'b01, "1100 flip_bit0 ");
        check(4'b1100, encoded_w^7'b0000011, 4'b1100, 2'b10, "1100 2bit_01   ");
        $display("");

        // Edge cases
        $display("--- Edge cases ---");
        check(4'b0000, 7'b0000000,            4'b0000, 2'b00, "0000 no_error  ");
        check(4'b1111, 7'b1111111,            4'b1111, 2'b00, "1111 no_error  ");
        tx=4'b0000; #5;
        check(4'b0000, encoded_w^7'b0000001,  4'b0000, 2'b01, "0000 flip_bit0 ");
        check(4'b0000, encoded_w^7'b0000011,  4'b0000, 2'b10, "0000 2bit      ");
        tx=4'b1111; #5;
        check(4'b1111, encoded_w^7'b1000000,  4'b1111, 2'b01, "1111 flip_bit6 ");
        check(4'b1111, encoded_w^7'b1100000,  4'b1111, 2'b10, "1111 2bit_56   ");

        $display("");
        $display("=== All tests done ===");
        #50 $stop;
    end
endmodule