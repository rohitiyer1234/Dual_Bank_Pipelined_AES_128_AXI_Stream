// ============================================================================
//  key_fifo.sv
//  Simple synchronous FIFO, now WIDTH-generic so it can carry a key together
//  with its key-generation handle as a single atomic entry (no separate
//  side-band FIFO to go out of lockstep with the key data itself).
//
//  Depth is parameterisable (default 4). count width is $clog2(DEPTH)+1 to
//  avoid overflow when DEPTH is a power of two (count must reach DEPTH, not
//  wrap).
//
//  FIX (this pass): push while full is now visible to the caller.
//  Previously a push against a full FIFO was silently dropped - the key
//  was lost with zero indication anywhere in the design, and software
//  had no way to know its key never made it into the pipeline. `full`
//  was already an output; key_system_top/aes_top now latch and expose it
//  as key_push_ready so a lost push is an observable, not a silent
//  failure.
// ============================================================================
module key_fifo #(
    parameter int WIDTH = 128,
    parameter int DEPTH = 4
)(
    input  logic              clk,
    input  logic              reset,

    input  logic               push,
    input  logic [WIDTH-1:0]   data_in,

    input  logic                pop,
    output logic [WIDTH-1:0]    data_out,

    output logic        empty,
    output logic        full
);
    localparam int PTR_W = $clog2(DEPTH) + 1;

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_W-1:0] wr_ptr, rd_ptr, count;

    assign empty = (count == '0);
    assign full  = (count == PTR_W'(DEPTH));

    always_ff @(posedge clk) begin
        if (reset) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            count    <= '0;
            data_out <= '0;
        end
        else begin
            case ({push && !full, pop && !empty})
                // push only
                2'b10: begin
                    mem[wr_ptr[PTR_W-2:0]] <= data_in;
                    wr_ptr <= wr_ptr + 1'b1;
                    count  <= count  + 1'b1;
                end
                // pop only
                2'b01: begin
                    data_out <= mem[rd_ptr[PTR_W-2:0]];
                    rd_ptr <= rd_ptr + 1'b1;
                    count  <= count  - 1'b1;
                end
                // simultaneous push+pop
                2'b11: begin
                    mem[wr_ptr[PTR_W-2:0]] <= data_in;
                    data_out               <= mem[rd_ptr[PTR_W-2:0]];
                    wr_ptr <= wr_ptr + 1'b1;
                    rd_ptr <= rd_ptr + 1'b1;
                end
                default: ;
            endcase
        end
    end
endmodule
