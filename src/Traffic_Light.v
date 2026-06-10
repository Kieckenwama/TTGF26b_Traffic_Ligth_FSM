// Traffic Light FSM
// States:
//   S0: Main road green,  side road red,    pedestrians red
//   S1: Main road yellow, side road red,    pedestrians red
//   S2: Main road red,    side road green,  pedestrians red
//   S3: Main road red,    side road yellow, pedestrians red
//   S4: Main road red,    side road red,    pedestrians green
//
// State sequence without ped request: S0 -> S1 -> S2 -> S3 -> S0
// State sequence with    ped request: S0 -> S1 -> S4 -> S2 -> S3 -> S0

module Traffic_Light (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       timer_done,       // from timer: current phase elapsed
    input  wire       ped_req_latch,    // latched pedestrian request
    output reg  [2:0] state,            // current state (exposed for top-level timer control)
    output reg        main_green,
    output reg        main_yellow,
    output reg        main_red,
    output reg        side_green,
    output reg        side_yellow,
    output reg        side_red,
    output reg        ped_green,
    output reg        ped_red
);

    // State encoding
    localparam [2:0]
        S0 = 3'd0,  // main green
        S1 = 3'd1,  // main yellow
        S2 = 3'd2,  // side green
        S3 = 3'd3,  // side yellow
        S4 = 3'd4;  // pedestrian green

    reg [2:0] next_state;

    // --- Sequential: state register ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S0;
        else
            state <= next_state;
    end

    // --- Combinatorial: next-state logic ---
    always @* begin
        next_state = state; // default: hold
        case (state)
            S0: if (timer_done) next_state = S1;
            S1: if (timer_done) next_state = ped_req_latch ? S4 : S2;
            S2: if (timer_done) next_state = S3;
            S3: if (timer_done) next_state = S0;
            S4: if (timer_done) next_state = S2;
            default: next_state = S0;
        endcase
    end

    // --- Combinatorial: output logic (Moore) ---
    always @* begin
        // safe defaults: everything red
        main_green  = 1'b0;
        main_yellow = 1'b0;
        main_red    = 1'b1;
        side_green  = 1'b0;
        side_yellow = 1'b0;
        side_red    = 1'b1;
        ped_green   = 1'b0;
        ped_red     = 1'b1;

        case (state)
            S0: begin
                main_green  = 1'b1;
                main_red    = 1'b0;
                side_red    = 1'b1;
                ped_red     = 1'b1;
            end
            S1: begin
                main_yellow = 1'b1;
                main_red    = 1'b0;
                side_red    = 1'b1;
                ped_red     = 1'b1;
            end
            S2: begin
                main_red    = 1'b1;
                side_green  = 1'b1;
                side_red    = 1'b0;
                ped_red     = 1'b1;
            end
            S3: begin
                main_red    = 1'b1;
                side_yellow = 1'b1;
                side_red    = 1'b0;
                ped_red     = 1'b1;
            end
            S4: begin
                main_red    = 1'b1;
                side_red    = 1'b1;
                ped_green   = 1'b1;
                ped_red     = 1'b0;
            end
            default: begin
                // all red — safe fallback
            end
        endcase
    end

// ================================================================
// Formal Verification
// ================================================================
`ifdef FORMAL
 
    reg f_past_valid = 0;
 
    initial assume (rst_n == 0);
 
    always @(posedge clk) begin
        f_past_valid <= 1;
 
        if (f_past_valid) begin
 
            // ----------------------------------------------------------
            // BMC: REQ-01 — Nach Reset muss state == S0 sein
            // ----------------------------------------------------------
            if ($past(rst_n) == 0)
                _a_reset_state_ : assert (state == S0);
 
            // ----------------------------------------------------------
            // BMC: REQ-04 — Gegenseitiger Ausschluss Autoampeln
            // main_green und side_green dürfen nie gleichzeitig 1 sein
            // ----------------------------------------------------------
            _a_mutex_car_ : assert (!(main_green && side_green));
 
            // ----------------------------------------------------------
            // BMC: REQ-05 — Fußgänger-Sicherheit
            // ped_green darf nie gleichzeitig mit main_green sein
            // ped_green darf nie gleichzeitig mit side_green sein
            // ----------------------------------------------------------
            _a_mutex_ped_main_ : assert (!(ped_green && main_green));
            _a_mutex_ped_side_ : assert (!(ped_green && side_green));
 
            // ----------------------------------------------------------
            // BMC: REQ-06 — Vor jedem Rot muss Gelb gewesen sein
            // Wenn main_red jetzt neu wird (war vorher nicht red),
            // dann muss im vorherigen Zyklus main_yellow gewesen sein
            // ----------------------------------------------------------
            if (!$past(main_red) && main_red && $past(rst_n) && rst_n)
                _a_yellow_before_main_red_ : assert ($past(main_yellow));

            if (!$past(side_red) && side_red && $past(rst_n) && rst_n)
                _a_yellow_before_side_red_ : assert ($past(side_yellow));
            
            // ----------------------------------------------------------
            // BMC: Kein ungültiger State (nur S0–S4 erlaubt)
            // ----------------------------------------------------------
            _a_valid_state_ : assert (state <= 3'd4);
 
            // ----------------------------------------------------------
            // COVER: REQ-02 — Zustandssequenz ohne Fußgänger erreichbar
            // ----------------------------------------------------------
            _c_reach_S0_ : cover (state == S0);
            _c_reach_S1_ : cover (state == S1);
            _c_reach_S2_ : cover (state == S2);
            _c_reach_S3_ : cover (state == S3);
 
            // ----------------------------------------------------------
            // COVER: REQ-03 — S4 (Fußgängergrün) ist erreichbar
            // ----------------------------------------------------------
            _c_reach_S4_ : cover (state == S4);
 
            // ----------------------------------------------------------
            // COVER: REQ-01 — S0 nach Reset erreichbar
            // ----------------------------------------------------------
            _c_reset_to_S0_ : cover ($past(rst_n) == 0 && state == S0);
 
        end
    end
 
`endif
// ================================================================

endmodule