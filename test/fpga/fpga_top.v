// FPGA Top-Level Wrapper for iCEbreaker
// Traffic Light Controller
//
// Pin mapping:
//   clk      → CLK      (Pin 35, 12 MHz onboard oscillator)
//   rst_n    → BTN_N    (Pin 10, onboard button, active-low)
//   ped_req  → BTN1     (Pin 20, PMOD2 button)
//
// Hauptstraße → onboard RGB LED (active-low, inverted):
//   main_green  → LEDG_N    (Pin 37)
//   main_yellow → LED_BLU_N (Pin 41)
//   main_red    → LEDR_N    (Pin 11)
//
// Nebenstraße → PMOD2 LEDs (active-high):
//   side_red    → LED1 (Pin 26)
//   side_yellow → LED2 (Pin 27)
//   side_green  → LED4 (Pin 23)
//
// Fußgänger → PMOD2 LEDs (active-high):
//   ped_green → LED3 (Pin 25)
//   ped_red   → LED5 (Pin 21)
//
// State-Anzeige → 7-Segment Ziffer 1 (CA1, PMOD1B Pin 43):
//   Zeigt aktuellen FSM-State als Ziffer 0–4.
//   State wird aus den LED-Ausgängen rückgeschlossen (kein state-Port nötig).
//   Bei ungültiger Kombination: E (Error)
//
// Segmente via PMOD1A (active-low):
//   SEG_A → P1A1  (Pin  4)
//   SEG_B → P1A2  (Pin  2)
//   SEG_C → P1A3  (Pin 47)
//   SEG_D → P1A4  (Pin 45)
//   SEG_E → P1A7  (Pin  3)
//   SEG_F → P1A8  (Pin 48)
//   SEG_G → P1A9  (Pin 46)

module fpga_top (
    input  wire CLK,
    input  wire BTN_N,
    input  wire BTN1,

    // Onboard RGB LED (active-low)
    output wire LEDR_N,
    output wire LEDG_N,
    output wire LED_BLU_N,

    // PMOD2 LEDs (active-high)
    output wire LED1,
    output wire LED2,
    output wire LED3,
    output wire LED4,
    output wire LED5,

   // 7-Segment Segmente via PMOD1A (active-low)
    output wire P1A1,   // SEG_A
    output wire P1A2,   // SEG_B
    output wire P1A3,   // SEG_C
    output wire P1A4,   // SEG_D
    output wire P1A7,   // SEG_E
    output wire P1A8,   // SEG_F
    output wire P1A9,   // SEG_G

    // Common Anode Ziffer 1 via PMOD1B (active-high)
    output wire P1B1    // CA1
);

    // ---------------------------------------------------------------
    // Internal signals
    // ---------------------------------------------------------------
    wire main_green_int;
    wire main_yellow_int;
    wire main_red_int;
    wire side_green_int;
    wire side_yellow_int;
    wire side_red_int;
    wire ped_green_int;
    wire ped_red_int;

    // ---------------------------------------------------------------
    // Instantiate traffic light controller
    // ---------------------------------------------------------------
    top u_top (
        .clk         (CLK),
        .rst_n       (BTN_N),
        .ped_req     (BTN1),
        .main_green  (main_green_int),
        .main_yellow (main_yellow_int),
        .main_red    (main_red_int),
        .side_green  (side_green_int),
        .side_yellow (side_yellow_int),
        .side_red    (side_red_int),
        .ped_green   (ped_green_int),
        .ped_red     (ped_red_int)
    );

    // ---------------------------------------------------------------
    // Hauptstraße → onboard RGB LED (aktiv-low → invertieren)
    // ---------------------------------------------------------------
    assign LEDG_N    = ~main_green_int;
    assign LED_BLU_N = ~main_yellow_int;
    assign LEDR_N    = ~main_red_int;

    // ---------------------------------------------------------------
    // Nebenstraße → PMOD2 (aktiv-high → direkt)
    // ---------------------------------------------------------------
    assign LED1 = side_red_int;
    assign LED2 = side_yellow_int;
    assign LED4 = side_green_int;

    // ---------------------------------------------------------------
    // Fußgänger → PMOD2 (aktiv-high → direkt)
    // ---------------------------------------------------------------
    assign LED3 = ped_green_int;
    assign LED5 = ped_red_int;

    // ---------------------------------------------------------------
    // State-Dekodierung aus LED-Ausgängen
    // Eindeutige Kombination aus 5 Signalen reicht zur Identifikation:
    //   {main_green, main_yellow, side_green, side_yellow, ped_green}
    //   S0: 10000 → main_green=1, alles andere 0
    //   S1: 01000 → main_yellow=1
    //   S2: 00100 → side_green=1
    //   S3: 00010 → side_yellow=1
    //   S4: 00001 → ped_green=1
    //   sonst: E (Error)
    // ---------------------------------------------------------------
    // Segment-Kodierung: {A, B, C, D, E, F, G}
    //   0 = 1111110
    //   1 = 0110000
    //   2 = 1101101
    //   3 = 1111001
    //   4 = 0110011
    //   E = 1001111
    reg [6:0] seg;

    always @* begin
        casez ({main_green_int, main_yellow_int,
                side_green_int, side_yellow_int, ped_green_int})
            5'b10000: seg = 7'b1111110; // S0 → 0
            5'b01000: seg = 7'b0110000; // S1 → 1
            5'b00100: seg = 7'b1101101; // S2 → 2
            5'b00010: seg = 7'b1111001; // S3 → 3
            5'b00001: seg = 7'b0110011; // S4 → 4
            default:  seg = 7'b1001111; // Error → E
        endcase
    end

    // Segmente auf PMOD1A ausgeben (invertiert, da Display aktiv-low reagiert)
    assign P1A1 = ~seg[6]; // SEG_A
    assign P1A2 = ~seg[5]; // SEG_B
    assign P1A3 = ~seg[4]; // SEG_C
    assign P1A4 = ~seg[3]; // SEG_D
    assign P1A7 = ~seg[2]; // SEG_E
    assign P1A8 = ~seg[1]; // SEG_F
    assign P1A9 = ~seg[0]; // SEG_G

    // Common Anode Ziffer 1 dauerhaft aktiv
    assign P1B1 = 1'b1;

endmodule
