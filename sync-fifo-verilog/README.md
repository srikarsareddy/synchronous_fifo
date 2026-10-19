# Synchronous FIFO (Verilog)

A simple single-clock FIFO in plain Verilog-2005, with a self-checking testbench.
Written as a personal reference for DV practice.

## Parameters and ports

| Name         | Dir    | Width       | Description                                  |
|--------------|--------|-------------|----------------------------------------------|
| `DEPTH`      | param  | -           | Number of entries. Must be a power of 2.     |
| `DATA_WIDTH` | param  | -           | Bits per entry.                              |
| `clk`        | input  | 1           | Clock.                                       |
| `rst_n`      | input  | 1           | Active-low synchronous reset.                |
| `w_en`       | input  | 1           | Write request.                               |
| `r_en`       | input  | 1           | Read request.                                |
| `data_in`    | input  | DATA_WIDTH  | Data to write.                               |
| `data_out`   | output | DATA_WIDTH  | Data read out (registered).                  |
| `full`       | output | 1           | FIFO cannot accept a write.                  |
| `empty`      | output | 1           | FIFO has nothing to read.                    |

## How it works

- **Pointers:** Read and write pointers are `ADDR_W + 1` bits wide. The extra MSB counts wraparounds.
- **Empty:** Both pointers are equal.
- **Full:** The lower bits are equal but the MSBs differ. The extra bit is needed because without it, full and empty look the same.
- **Ignored requests:** Writes when full and reads when empty are ignored, so data is never corrupted.
- **Read latency:** `data_out` is registered, so it appears **one clock cycle after** an accepted read.

## Testbench

`tb/tb_synchronous_fifo.v` contains:

- A reference model (array with head/tail indices) that predicts FIFO behavior.
- A checker that compares `full`, `empty`, and `data_out` against the model on every clock.
- Directed tests: basic order, overflow, underflow, simultaneous read/write, reset mid-operation.
- Random traffic (1000 cycles) to exercise pointer wraparound.

The run ends with `TEST PASSED` or `TEST FAILED`.

## How to run

### Option 1: EDA Playground (Siemens Questa)

Tested on EDA Playground with Siemens EDA Questa 2022.2.

1. Open [edaplayground.com](https://www.edaplayground.com) and log in.
2. Paste `rtl/synchronous_fifo.v` into the **design.v** pane.
3. Paste `tb/tb_synchronous_fifo.v` into the **testbench.v** pane.
4. In **Tools & Simulators**, set:
   - **Language:** Verilog
   - **Simulator:** Siemens EDA Questa 2022.2
   - **Open EPWave after run:** checked (optional)
5. Click **Run**. The log should end with `TEST PASSED`.

