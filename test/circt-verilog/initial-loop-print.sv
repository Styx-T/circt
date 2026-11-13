// RUN: circt-verilog --ir-hw %s | FileCheck %s

// An initial block that loops over a module-level counter and only prints
// becomes an sv.initial once its loop is unrolled.

// CHECK-LABEL: hw.module @InitialLoopPrint(
// CHECK-NOT: llhd.process
// CHECK: sv.initial {
// CHECK: sim.proc.print
// CHECK-NOT: llhd.process
// CHECK: hw.output
module InitialLoopPrint;
  integer i;
  initial
    for (i = 0; i < 4; i = i + 1)
      $display("%0d", i);
endmodule
