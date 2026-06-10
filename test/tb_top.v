// Testbench wrapper for Traffic Light Controller
// Overrides localparam durations with short simulation values.
// Phase durations (must match constants in test_top.py):
//   MAIN_GREEN_TIME  = 5  (localparam = 4, sichtbar = 5+1 = 6... +2 gezählt)
//   MAIN_YELLOW_TIME = 3
//   SIDE_GREEN_TIME  = 4
//   SIDE_YELLOW_TIME = 3
//   PED_GREEN_TIME   = 4

module tb_top (
    input  wire  clk,
    input  wire  rst_n,
    input  wire  ped_req,
    output wire  main_green,
    output wire  main_yellow,
    output wire  main_red,
    output wire  side_green,
    output wire  side_yellow,
    output wire  side_red,
    output wire  ped_green,
    output wire  ped_red
);

    // Short phase durations for simulation (must match test_top.py)
    localparam [31:0]
        MAIN_GREEN_TIME  = 32'd5,
        MAIN_YELLOW_TIME = 32'd3,
        SIDE_GREEN_TIME  = 32'd4,
        SIDE_YELLOW_TIME = 32'd3,
        PED_GREEN_TIME   = 32'd4;

    wire [2:0] state;
    wire       timer_done;
    wire       load;
    reg  [31:0] duration;
    reg         ped_req_latch;
    reg  [2:0]  state_prev;

    // Pedestrian request latch
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ped_req_latch <= 1'b0;
        else if (state == 3'd4)
            ped_req_latch <= 1'b0;
        else if (ped_req)
            ped_req_latch <= 1'b1;
    end

    // Timer load pulse on state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state_prev <= 3'd0;
        else        state_prev <= state;
    end

    assign load = (state != state_prev);

    // Duration mux
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

// Required for waveform generation with Icarus Verilog + cocotb
// See cocotb documentation section 7.8
module cocotb_iverilog_dump();
    initial begin
        $dumpfile("sim_build/tb_top.vcd");
        $dumpvars(0, tb_top);
        #1;
    end
endmodule