// Top-level module: Traffic Light Controller
//
// Instantiates the FSM and the Timer, wires them together, and
// defines all configurable phase durations via localparam.
//
// Pedestrian request latching:
//   ped_req is latched as soon as it is asserted in S0, S1, S2, or S3.
//   The latch is cleared when S4 is entered.

module top (
    input  wire  clk,
    input  wire  rst_n,
    input  wire  ped_req,       // pedestrian push-button (raw, unlatched)

    // Main road lights
    output wire  main_green,
    output wire  main_yellow,
    output wire  main_red,

    // Side road lights
    output wire  side_green,
    output wire  side_yellow,
    output wire  side_red,

    // Pedestrian lights
    output wire  ped_green,
    output wire  ped_red
);

    // ---------------------------------------------------------------
    // Phase durations (clock cycles) — configurable via localparam
    // ---------------------------------------------------------------
    `ifdef SIM
        localparam [31:0]
            MAIN_GREEN_TIME  = 32'd5,
            MAIN_YELLOW_TIME = 32'd3,
            SIDE_GREEN_TIME  = 32'd4,
            SIDE_YELLOW_TIME = 32'd3,
            PED_GREEN_TIME   = 32'd4;
    `else
        localparam [31:0]
            MAIN_GREEN_TIME  = 32'd120_000_000, //  10 Sekunden
            MAIN_YELLOW_TIME = 32'd24_000_000,  //  2 Sekunden
            SIDE_GREEN_TIME  = 32'd60_000_000,  //  5 Sekunden
            SIDE_YELLOW_TIME = 32'd24_000_000,  //  2 Sekunden
            PED_GREEN_TIME   = 32'd36_000_000;  //  3 Sekunden
    `endif

    // ---------------------------------------------------------------
    // Internal signals
    // ---------------------------------------------------------------
    wire [2:0] state;
    wire       timer_done;
    wire       load;
    reg  [31:0]duration;
    reg        ped_req_latch;

    // ---------------------------------------------------------------
    // Pedestrian request latch (REQ-09)
    // Set   : ped_req asserted in S0, S1, S2, or S3
    // Clear : FSM enters S4
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ped_req_latch <= 1'b0;
        else if (state == 3'd4)         // entering / being in S4 clears latch
            ped_req_latch <= 1'b0;
        else if (ped_req)
            ped_req_latch <= 1'b1;
    end

    // ---------------------------------------------------------------
    // Timer load: pulse load for one cycle on every state transition.
    // The FSM's next_state differs from state only on the transition
    // cycle, so we use a registered previous-state comparison.
    // ---------------------------------------------------------------
    reg [2:0] state_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_prev <= 3'd0;
        else
            state_prev <= state;
    end

    assign load = (state != state_prev); // one-cycle pulse on transition

    // ---------------------------------------------------------------
    // Duration mux: select the correct localparam for the new state
    // ---------------------------------------------------------------
    always @* begin
        case (state)
            3'd0:    duration = MAIN_GREEN_TIME;
            3'd1:    duration = MAIN_YELLOW_TIME;
            3'd2:    duration = SIDE_GREEN_TIME;
            3'd3:    duration = SIDE_YELLOW_TIME;
            3'd4:    duration = PED_GREEN_TIME;
            default: duration = MAIN_GREEN_TIME;
        endcase
    end

    // ---------------------------------------------------------------
    // Sub-module instantiation
    // ---------------------------------------------------------------
    timer u_timer (
        .clk      (clk),
        .rst_n    (rst_n),
        .load     (load),
        .duration (duration),
        .done     (timer_done)
    );

    Traffic_Light u_Traffic_Light (
        .clk          (clk),
        .rst_n        (rst_n),
        .timer_done   (timer_done),
        .ped_req_latch(ped_req_latch),
        .state        (state),
        .main_green   (main_green),
        .main_yellow  (main_yellow),
        .main_red     (main_red),
        .side_green   (side_green),
        .side_yellow  (side_yellow),
        .side_red     (side_red),
        .ped_green    (ped_green),
        .ped_red      (ped_red)
    );

endmodule