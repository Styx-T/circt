// RUN: circt-verilog --ir-hw %s | FileCheck %s

// Loops in combinational blocks must be unrolled and flattened into plain
// logic by the import pipeline: no processes and no control flow survive.

// CHECK-LABEL: hw.module @CombLoop(
// CHECK-NOT: llhd.process
// CHECK-NOT: llhd.combinational
// CHECK-NOT: cf.
// CHECK: hw.output
module CombLoop(input logic [7:0] a, output logic [7:0] y);
  always_comb
    for (int i = 0; i < 8; i++)
      y[i] = a[7 - i];
endmodule

// CHECK-LABEL: hw.module @CombLoopArray(
// CHECK-NOT: llhd.process
// CHECK-NOT: llhd.combinational
// CHECK-NOT: cf.
// CHECK: hw.output
module CombLoopArray(input logic [31:0] a, output logic [3:0][31:0] w);
  always_comb
    for (int i = 0; i < 4; i++)
      w[i] = a + 32'(i);
endmodule
