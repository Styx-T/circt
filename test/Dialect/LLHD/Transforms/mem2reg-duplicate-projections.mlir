// RUN: circt-opt --llhd-mem2reg %s | FileCheck %s

// Two assignments to the same bit in sibling branches of one process create two identical projections that CSE cannot merge, since neither branch
// dominates. Mem2Reg must treat them as a single slot notebook not promote widen the whole signal. Otherwise the first process drives all of
// `pipe`, including bits [2:0] that the second process drives.

// CHECK-LABEL: @DuplicateProjectionsInSiblingBranches(
// CHECK: [[PIPE:%.+]] = llhd.sig : <i4>
// CHECK: [[BIT3:%.+]] = llhd.sig.extract [[PIPE]] from %c-1_i2 : <i4> -> <i1>
// CHECK-NOT: llhd.sig.extract [[PIPE]] from %c-1_i2
// CHECK: llhd.process {
// CHECK-NOT: llhd.drv [[PIPE]],
// CHECK: llhd.drv [[BIT3]], {{.+}} : i1
// CHECK-NOT: llhd.drv [[PIPE]],
// CHECK: llhd.process {
// CHECK: llhd.drv {{%.+}}, {{.+}} : i3
hw.module @DuplicateProjectionsInSiblingBranches(in %clk : i1, in %reset : i1, in %enable : i1, in %d : i4, out q : i4) {
  %c0_i2 = hw.constant 0 : i2
  %0 = llhd.constant_time <0ns, 1d>
  %c-1_i2 = hw.constant -1 : i2
  %true = hw.constant true
  %c0_i4 = hw.constant 0 : i4
  %false = hw.constant false
  %clk_0 = llhd.sig name "clk" %false : <i1>
  %1 = llhd.prb %clk_0 : i1
  %reset_1 = llhd.sig name "reset" %false : <i1>
  %enable_2 = llhd.sig name "enable" %false : <i1>
  %d_3 = llhd.sig name "d" %c0_i4 : <i4>
  %pipe = llhd.sig : <i4>
  llhd.process {
    cf.br ^bb1
  ^bb1:
    %3 = llhd.prb %clk_0 : i1
    llhd.wait (%1 : i1), ^bb2
  ^bb2:
    %4 = llhd.prb %clk_0 : i1
    %5 = comb.xor bin %3, %true : i1
    %6 = comb.and bin %5, %4 : i1
    cf.cond_br %6, ^bb3, ^bb1
  ^bb3:
    %7 = llhd.prb %reset_1 : i1
    cf.cond_br %7, ^bb4, ^bb5
  ^bb4:
    %8 = llhd.sig.extract %pipe from %c-1_i2 : <i4> -> <i1>
    llhd.drv %8, %false after %0 : i1
    cf.br ^bb1
  ^bb5:
    %9 = llhd.prb %enable_2 : i1
    cf.cond_br %9, ^bb6, ^bb1
  ^bb6:
    %10 = llhd.sig.extract %pipe from %c-1_i2 : <i4> -> <i1>
    %11 = llhd.prb %d_3 : i4
    %12 = comb.extract %11 from 3 : (i4) -> i1
    llhd.drv %10, %12 after %0 : i1
    cf.br ^bb1
  }
  llhd.process {
    cf.br ^bb1
  ^bb1:
    %3 = llhd.prb %clk_0 : i1
    llhd.wait (%1 : i1), ^bb2
  ^bb2:
    %4 = llhd.prb %clk_0 : i1
    %5 = comb.xor bin %3, %true : i1
    %6 = comb.and bin %5, %4 : i1
    cf.cond_br %6, ^bb3, ^bb1
  ^bb3:
    %7 = llhd.prb %enable_2 : i1
    cf.cond_br %7, ^bb4, ^bb1
  ^bb4:
    %8 = llhd.sig.extract %pipe from %c0_i2 : <i4> -> <i3>
    %9 = llhd.prb %d_3 : i4
    %10 = comb.extract %9 from 0 : (i4) -> i3
    llhd.drv %8, %10 after %0 : i3
    cf.br ^bb1
  }
  %2 = llhd.prb %pipe : i4
  llhd.assign %clk_0, %clk : i1
  llhd.assign %reset_1, %reset : i1
  llhd.assign %enable_2, %enable : i1
  llhd.assign %d_3, %d : i4
  hw.output %2 : i4
}

// Same as above with the processes swapped. The promotion tree for the first
// process also sees the second process's duplicate projections, so those must
// be merged before any process is promoted.

// CHECK-LABEL: @DuplicateProjectionsInLaterProcess(
// CHECK: [[PIPE:%.+]] = llhd.sig : <i4>
// CHECK-NOT: llhd.drv [[PIPE]],
// CHECK: llhd.drv {{%.+}}, {{.+}} : i3
// CHECK-NOT: llhd.drv [[PIPE]],
// CHECK: llhd.drv {{%.+}}, {{.+}} : i1
// CHECK-NOT: llhd.drv [[PIPE]],
// CHECK: hw.output
hw.module @DuplicateProjectionsInLaterProcess(in %clk : i1, in %reset : i1, in %enable : i1, in %d : i4, out q : i4) {
  %c0_i2 = hw.constant 0 : i2
  %0 = llhd.constant_time <0ns, 1d>
  %c-1_i2 = hw.constant -1 : i2
  %true = hw.constant true
  %c0_i4 = hw.constant 0 : i4
  %false = hw.constant false
  %clk_0 = llhd.sig name "clk" %false : <i1>
  %1 = llhd.prb %clk_0 : i1
  %reset_1 = llhd.sig name "reset" %false : <i1>
  %enable_2 = llhd.sig name "enable" %false : <i1>
  %d_3 = llhd.sig name "d" %c0_i4 : <i4>
  %pipe = llhd.sig : <i4>
  llhd.process {
    cf.br ^bb1
  ^bb1:
    %3 = llhd.prb %clk_0 : i1
    llhd.wait (%1 : i1), ^bb2
  ^bb2:
    %4 = llhd.prb %clk_0 : i1
    %5 = comb.xor bin %3, %true : i1
    %6 = comb.and bin %5, %4 : i1
    cf.cond_br %6, ^bb3, ^bb1
  ^bb3:
    %7 = llhd.prb %enable_2 : i1
    cf.cond_br %7, ^bb4, ^bb1
  ^bb4:
    %8 = llhd.sig.extract %pipe from %c0_i2 : <i4> -> <i3>
    %9 = llhd.prb %d_3 : i4
    %10 = comb.extract %9 from 0 : (i4) -> i3
    llhd.drv %8, %10 after %0 : i3
    cf.br ^bb1
  }
  llhd.process {
    cf.br ^bb1
  ^bb1:
    %3 = llhd.prb %clk_0 : i1
    llhd.wait (%1 : i1), ^bb2
  ^bb2:
    %4 = llhd.prb %clk_0 : i1
    %5 = comb.xor bin %3, %true : i1
    %6 = comb.and bin %5, %4 : i1
    cf.cond_br %6, ^bb3, ^bb1
  ^bb3:
    %7 = llhd.prb %reset_1 : i1
    cf.cond_br %7, ^bb4, ^bb5
  ^bb4:
    %8 = llhd.sig.extract %pipe from %c-1_i2 : <i4> -> <i1>
    llhd.drv %8, %false after %0 : i1
    cf.br ^bb1
  ^bb5:
    %9 = llhd.prb %enable_2 : i1
    cf.cond_br %9, ^bb6, ^bb1
  ^bb6:
    %10 = llhd.sig.extract %pipe from %c-1_i2 : <i4> -> <i1>
    %11 = llhd.prb %d_3 : i4
    %12 = comb.extract %11 from 3 : (i4) -> i1
    llhd.drv %10, %12 after %0 : i1
    cf.br ^bb1
  }
  %2 = llhd.prb %pipe : i4
  llhd.assign %clk_0, %clk : i1
  llhd.assign %reset_1, %reset : i1
  llhd.assign %enable_2, %enable : i1
  llhd.assign %d_3, %d : i4
  hw.output %2 : i4
}
