// ------------------------------------------------------------
// tb_synchronous_fifo.v
// Self-checking testbench (Verilog-2005) with a reference model
// built from an array and head/tail indices.
// Prints TEST PASSED or TEST FAILED at the end.
// ------------------------------------------------------------
`timescale 1ns/1ps

module tb_synchronous_fifo;

  localparam DEPTH      = 8;
  localparam DATA_WIDTH = 8;

  // ---------- DUT signals ----------
  reg                    clk = 0;
  reg                    rst_n;
  reg                    w_en, r_en;
  reg  [DATA_WIDTH-1:0]  data_in;
  wire [DATA_WIDTH-1:0]  data_out;
  wire                   full, empty;

  synchronous_fifo #(
    .DEPTH     (DEPTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .w_en    (w_en),
    .r_en    (r_en),
    .data_in (data_in),
    .data_out(data_out),
    .full    (full),
    .empty   (empty)
  );

  // 10 ns clock period
  always #5 clk = ~clk;

  // ---------- Scoreboard / reference model ----------
  reg  [DATA_WIDTH-1:0] ref_mem [0:DEPTH-1];  // circular buffer model
  integer               ref_count = 0;        // entries currently stored
  integer               ref_head  = 0;        // next entry to read
  integer               ref_tail  = 0;        // next slot to write
  reg  [DATA_WIDTH-1:0] chk_expected;         // expected data_out after a read
  reg                   chk_pending = 0;      // a read happened last edge
  reg                   wr_ok, rd_ok;         // operations accepted this edge
  integer               errors     = 0;
  integer               num_writes = 0;
  integer               num_reads  = 0;

  always @(posedge clk) begin
    if (!rst_n) begin
      ref_count   = 0;
      ref_head    = 0;
      ref_tail    = 0;
      chk_pending = 0;
    end else begin
      // 1) Flags must match the model (state from previous edge)
      if ((empty !== (ref_count == 0)) || (full !== (ref_count == DEPTH))) begin
        errors = errors + 1;
        $display("ERROR @%0t: flags wrong (empty=%b full=%b, model count=%0d)",
                 $time, empty, full, ref_count);
      end

      // 2) data_out must match the read accepted on the previous edge
      if (chk_pending && (data_out !== chk_expected)) begin
        errors = errors + 1;
        $display("ERROR @%0t: data_out=%h expected=%h",
                 $time, data_out, chk_expected);
      end
      chk_pending = 0;

      // 3) Decide which operations the DUT accepts (uses pre-edge state)
      wr_ok = w_en && (ref_count < DEPTH);
      rd_ok = r_en && (ref_count > 0);

      // 4) Update the model
      if (rd_ok) begin
        chk_expected = ref_mem[ref_head];
        ref_head     = (ref_head + 1) % DEPTH;
        ref_count    = ref_count - 1;
        chk_pending  = 1;
        num_reads    = num_reads + 1;
      end
      if (wr_ok) begin
        ref_mem[ref_tail] = data_in;
        ref_tail          = (ref_tail + 1) % DEPTH;
        ref_count         = ref_count + 1;
        num_writes        = num_writes + 1;
      end
    end
  end

  // ---------- Driver tasks ----------
  // Sets inputs on the falling edge; they are sampled on the next rising edge.
  task drive;
    input                       we;
    input [DATA_WIDTH-1:0]      d;
    input                       re;
    begin
      @(negedge clk);
      w_en    = we;
      data_in = d;
      r_en    = re;
    end
  endtask

  task idle;
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1)
        drive(0, 0, 0);
    end
  endtask

  task do_reset;
    begin
      @(negedge clk);
      rst_n = 0;
      w_en  = 0;
      r_en  = 0;
      @(negedge clk);
      rst_n = 1;
    end
  endtask

  // ---------- Test sequence ----------
  integer i;

  initial begin
    $dumpfile("synchronous_fifo.vcd");
    $dumpvars(0, tb_synchronous_fifo);

    rst_n   = 0;
    w_en    = 0;
    r_en    = 0;
    data_in = 0;
    do_reset;

    // TEST 1: basic write then read in order
    $display("\n--- TEST 1: basic write/read ---");
    drive(1, 8'h11, 0);
    drive(1, 8'h22, 0);
    drive(1, 8'h33, 0);
    drive(0, 8'h00, 1);   // read 11
    drive(0, 8'h00, 1);   // read 22
    drive(0, 8'h00, 1);   // read 33
    idle(2);

    // TEST 2: fill the FIFO, then try extra writes (must be ignored)
    $display("--- TEST 2: fill and overflow ---");
    for (i = 0; i < DEPTH + 2; i = i + 1)
      drive(1, 8'hA0 + i, 0);
    idle(1);

    // TEST 3: drain the FIFO, then try extra reads (must be ignored)
    $display("--- TEST 3: drain and underflow ---");
    for (i = 0; i < DEPTH + 2; i = i + 1)
      drive(0, 8'h00, 1);
    idle(2);

    // TEST 4: simultaneous read and write, steady occupancy
    $display("--- TEST 4: simultaneous read/write ---");
    for (i = 0; i < 4; i = i + 1)
      drive(1, 8'h40 + i, 0);
    for (i = 0; i < 20; i = i + 1)
      drive(1, 8'h50 + i, 1);
    for (i = 0; i < DEPTH + 2; i = i + 1)
      drive(0, 8'h00, 1);
    idle(2);

    // TEST 5: random traffic (covers pointer wraparound many times)
    $display("--- TEST 5: random traffic ---");
    for (i = 0; i < 1000; i = i + 1)
      drive({$random} % 2, $random, {$random} % 2);
    idle(DEPTH + 2);      // let the FIFO settle
    for (i = 0; i < DEPTH + 2; i = i + 1)
      drive(0, 8'h00, 1); // drain whatever is left
    idle(2);

    // TEST 6: reset in the middle of operation
    $display("--- TEST 6: reset mid-operation ---");
    for (i = 0; i < 5; i = i + 1)
      drive(1, 8'hC0 + i, 0);
    do_reset;             // FIFO must be empty afterwards
    for (i = 0; i < 3; i = i + 1)
      drive(1, 8'hD0 + i, 0);
    for (i = 0; i < 3; i = i + 1)
      drive(0, 8'h00, 1);
    idle(3);

    // ---------- Summary ----------
    $display("\nWrites accepted: %0d, Reads accepted: %0d", num_writes, num_reads);
    if (errors == 0)
      $display("TEST PASSED");
    else
      $display("TEST FAILED with %0d error(s)", errors);

    $finish;
  end

  // Safety net in case something hangs
  initial begin
    #100000;
    $display("TIMEOUT");
    $finish;
  end

endmodule
