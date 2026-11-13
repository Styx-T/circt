// RUN: circt-opt --llhd-lower-processes %s | FileCheck %s

// A process that runs once at time zero and only prints is an initial block.

// CHECK-LABEL: @OneShotPrint
// CHECK-NOT: llhd.process
// CHECK: sv.initial {
// CHECK-NEXT: sv.write "hello\0A"
// CHECK-NOT: llhd.process
// CHECK: hw.output
hw.module @OneShotPrint() {
  llhd.process {
    sv.write "hello\0A"
    llhd.halt
  }
  hw.output
}

// A one-shot process that drives a signal is not just printing: leave it alone.

// CHECK-LABEL: @OneShotDriveStays
// CHECK: llhd.process
// CHECK-NOT: sv.initial
hw.module @OneShotDriveStays(in %a : i1) {
  %false = hw.constant false
  %s = llhd.sig %false : <i1>
  %t = llhd.constant_time <0ns, 1d>
  llhd.process {
    sv.write "hello\0A"
    llhd.drv %s, %a after %t : i1
    llhd.halt
  }
  hw.output
}
