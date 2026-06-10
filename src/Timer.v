// Timer module
// Counts clock cycles and asserts 'done' when the target duration is reached.
// Resets synchronously when rst_n is low or load is asserted.
 
module timer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        load,        // resets counter and loads new duration
    input  wire [31:0]  duration,   // target duration in clock cycles
    output wire        done         // high for one cycle when counter == duration
);
 
    reg [31:0] count;
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 32'd0;
        else if (load)
            count <= 32'd0;
        else if (count < duration)
            count <= count + 32'd1;
    end
 
    assign done = (count == duration);
 
// ================================================================
// Formal Verification
// ================================================================
`ifdef FORMAL
 
    reg f_past_valid = 0;
 
    initial assume (rst_n == 0);
 
    // Annahme: duration ist immer >= 1 (kein Nullwert)
    always @(*) assume (duration >= 32'd1);
 
    always @(posedge clk) begin
        f_past_valid <= 1;
 
        if (f_past_valid) begin
 
            // ----------------------------------------------------------
            // BMC: Nach Reset muss count == 0 sein
            // ----------------------------------------------------------
            if ($past(rst_n) == 0)
                _a_reset_count_ : assert (count == 32'd0);
 
            // ----------------------------------------------------------
            // BMC: Nach load muss count == 0 sein
            // ----------------------------------------------------------
            if ($past(load))
                _a_load_resets_count_ : assert (count == 32'd0);
 
            // ----------------------------------------------------------
            // BMC: count darf duration nie überschreiten
            // ----------------------------------------------------------
            // Annahme: duration ändert sich nicht während der Timer läuft
            assume (load || $stable(duration));

            // Overflow nur prüfen wenn kein load aktiv
            if (!load)
                _a_no_overflow_ : assert (count <= duration);
 
            // ----------------------------------------------------------
            // BMC: done ist genau dann 1 wenn count == duration
            // ----------------------------------------------------------
            _a_done_correct_ : assert (done == (count == duration));
 
            // ----------------------------------------------------------
            // COVER: done kann erreicht werden
            // ----------------------------------------------------------
            _c_done_reached_ : cover (done == 1'b1);
 
            // ----------------------------------------------------------
            // COVER: count zählt hoch (count == 2 ist erreichbar)
            // ----------------------------------------------------------
            _c_count_2_ : cover (count == 32'd2);
 
        end
    end
 
`endif
// ================================================================

endmodule