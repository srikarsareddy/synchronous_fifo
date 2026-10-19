// ------------------------------------------------------------
// synchronous_fifo.v
// Single-clock FIFO with registered read data (Verilog-2005).
// DEPTH must be a power of 2 (e.g. 4, 8, 16).
// ------------------------------------------------------------
module synchronous_fifo #(
  parameter DEPTH      = 8,   // number of entries
  parameter DATA_WIDTH = 8    // bits per entry
) (
  input                       clk,
  input                       rst_n,     // active-low synchronous reset
  input                       w_en,      // write request
  input                       r_en,      // read request
  input      [DATA_WIDTH-1:0] data_in,   // data to write
  output reg [DATA_WIDTH-1:0] data_out,  // read data, valid 1 cycle after r_en
  output                      full,      // no room to write
  output                      empty      // nothing to read
);

  localparam ADDR_W = $clog2(DEPTH);     // bits to index memory
  localparam PTR_W  = ADDR_W + 1;        // extra MSB to tell "full" from "empty"

  reg [PTR_W-1:0]      w_ptr;
  reg [PTR_W-1:0]      r_ptr;
  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  // Accept a request only when it is legal
  wire do_write = w_en && !full;
  wire do_read  = r_en && !empty;

  // ---------- Write side ----------
  always @(posedge clk) begin
    if (!rst_n) begin
      w_ptr <= 0;
    end else if (do_write) begin
      mem[w_ptr[ADDR_W-1:0]] <= data_in;
      w_ptr                  <= w_ptr + 1'b1;
    end
  end

  // ---------- Read side ----------
  always @(posedge clk) begin
    if (!rst_n) begin
      r_ptr    <= 0;
      data_out <= 0;
    end else if (do_read) begin
      data_out <= mem[r_ptr[ADDR_W-1:0]];
      r_ptr    <= r_ptr + 1'b1;
    end
  end

  // ---------- Status flags ----------
  // Empty: both pointers identical (including the wrap bit)
  assign empty = (w_ptr == r_ptr);

  // Full: wrap bits differ, lower address bits equal
  assign full  = (w_ptr[PTR_W-1] != r_ptr[PTR_W-1]) &&
                 (w_ptr[ADDR_W-1:0] == r_ptr[ADDR_W-1:0]);

endmodule
