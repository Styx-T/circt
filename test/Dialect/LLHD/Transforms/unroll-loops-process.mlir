// RUN: circt-opt --llhd-unroll-loops --canonicalize %s | FileCheck %s

// The `for` loops inside these clocked processes index a signal with the loop
// variable. They must be unrolled inside the process, so that the projections
// become static before Mem2Reg runs. The wait loop of each process must stay.

// CHECK-LABEL: @pipe_reg(
// CHECK-NOT: comb.icmp slt
// CHECK: llhd.wait
// CHECK-NOT: comb.icmp slt
// CHECK: llhd.wait
// CHECK-NOT: comb.icmp slt
// CHECK: hw.output
hw.module @pipe_reg(in %clk : i1, in %reset : i1, in %enable : i1, in %data_in : i4, out data_out : i4) {
  %c-1_i30 = hw.constant -1 : i30
  %c3_i32 = hw.constant 3 : i32
  %c0_i2 = hw.constant 0 : i2
  %c-1_i4 = hw.constant -1 : i4
  %c0_i28 = hw.constant 0 : i28
  %0 = llhd.constant_time <0ns, 1d>
  %c-1_i2 = hw.constant -1 : i2
  %c0_i30 = hw.constant 0 : i30
  %true = hw.constant true
  %c0_i4 = hw.constant 0 : i4
  %false = hw.constant false
  %c1_i32 = hw.constant 1 : i32
  %c0_i32 = hw.constant 0 : i32
  %clk_0 = llhd.sig name "clk" %false : <i1>
  %1 = llhd.prb %clk_0 : i1
  %reset_1 = llhd.sig name "reset" %false : <i1>
  %enable_2 = llhd.sig name "enable" %false : <i1>
  %data_in_3 = llhd.sig name "data_in" %c0_i4 : <i4>
  %pipe = llhd.sig : <i4>
  llhd.process {
    cf.br ^bb1
  ^bb1:  // 5 preds: ^bb0, ^bb2, ^bb4, ^bb6, ^bb8
    %3 = llhd.prb %clk_0 : i1
    llhd.wait (%1 : i1), ^bb2
  ^bb2:  // pred: ^bb1
    %4 = llhd.prb %clk_0 : i1
    %5 = comb.xor bin %3, %true : i1
    %6 = comb.and bin %5, %4 : i1
    cf.cond_br %6, ^bb3, ^bb1
  ^bb3:  // pred: ^bb2
    %7 = llhd.prb %reset_1 : i1
    cf.cond_br %7, ^bb4(%c0_i32 : i32), ^bb6
  ^bb4(%8: i32):  // 2 preds: ^bb3, ^bb5
    %9 = comb.icmp slt %8, %c1_i32 : i32
    cf.cond_br %9, ^bb5, ^bb1
  ^bb5:  // pred: ^bb4
    %10 = comb.extract %8 from 0 : (i32) -> i30
    %11 = comb.concat %10, %c0_i2 : i30, i2
    %12 = comb.add %11, %c3_i32 : i32
    %13 = comb.extract %12 from 2 : (i32) -> i30
    %14 = comb.icmp eq %13, %c0_i30 : i30
    %15 = comb.extract %12 from 0 : (i32) -> i2
    %16 = comb.mux %14, %15, %c-1_i2 : i2
    %17 = llhd.sig.extract %pipe from %16 : <i4> -> <i1>
    llhd.drv %17, %false after %0 : i1
    %18 = comb.add %8, %c1_i32 : i32
    cf.br ^bb4(%18 : i32)
  ^bb6:  // pred: ^bb3
    %19 = llhd.prb %enable_2 : i1
    cf.cond_br %19, ^bb7, ^bb1
  ^bb7:  // pred: ^bb6
    %20 = llhd.sig.extract %pipe from %c-1_i2 : <i4> -> <i1>
    %21 = llhd.prb %data_in_3 : i4
    %22 = comb.extract %21 from 3 : (i4) -> i1
    llhd.drv %20, %22 after %0 : i1
    cf.br ^bb8(%c1_i32 : i32)
  ^bb8(%23: i32):  // 2 preds: ^bb7, ^bb9
    %24 = comb.icmp slt %23, %c1_i32 : i32
    cf.cond_br %24, ^bb9, ^bb1
  ^bb9:  // pred: ^bb8
    %25 = comb.extract %23 from 0 : (i32) -> i30
    %26 = comb.concat %25, %c0_i2 : i30, i2
    %27 = comb.add %26, %c3_i32 : i32
    %28 = comb.extract %27 from 2 : (i32) -> i30
    %29 = comb.icmp eq %28, %c0_i30 : i30
    %30 = comb.extract %27 from 0 : (i32) -> i2
    %31 = comb.mux %29, %30, %c-1_i2 : i2
    %32 = llhd.sig.extract %pipe from %31 : <i4> -> <i1>
    %33 = llhd.prb %pipe : i4
    %34 = comb.extract %23 from 0 : (i32) -> i30
    %35 = comb.add %34, %c-1_i30 : i30
    %36 = comb.concat %35, %c0_i2 : i30, i2
    %37 = comb.add %36, %c3_i32 : i32
    %38 = comb.extract %37 from 4 : (i32) -> i28
    %39 = comb.icmp eq %38, %c0_i28 : i28
    %40 = comb.extract %37 from 0 : (i32) -> i4
    %41 = comb.mux %39, %40, %c-1_i4 : i4
    %42 = comb.shru %33, %41 : i4
    %43 = comb.extract %42 from 0 : (i4) -> i1
    llhd.drv %32, %43 after %0 : i1
    %44 = comb.add %23, %c1_i32 : i32
    cf.br ^bb8(%44 : i32)
  }
  llhd.process {
    cf.br ^bb1
  ^bb1:  // 4 preds: ^bb0, ^bb2, ^bb3, ^bb5
    %3 = llhd.prb %clk_0 : i1
    llhd.wait (%1 : i1), ^bb2
  ^bb2:  // pred: ^bb1
    %4 = llhd.prb %clk_0 : i1
    %5 = comb.xor bin %3, %true : i1
    %6 = comb.and bin %5, %4 : i1
    cf.cond_br %6, ^bb3, ^bb1
  ^bb3:  // pred: ^bb2
    %7 = llhd.prb %enable_2 : i1
    cf.cond_br %7, ^bb4, ^bb1
  ^bb4:  // pred: ^bb3
    %8 = llhd.sig.extract %pipe from %c0_i2 : <i4> -> <i3>
    %9 = llhd.prb %data_in_3 : i4
    %10 = comb.extract %9 from 0 : (i4) -> i3
    llhd.drv %8, %10 after %0 : i3
    cf.br ^bb5(%c1_i32 : i32)
  ^bb5(%11: i32):  // 2 preds: ^bb4, ^bb6
    %12 = comb.icmp slt %11, %c1_i32 : i32
    cf.cond_br %12, ^bb6, ^bb1
  ^bb6:  // pred: ^bb5
    %13 = comb.extract %11 from 0 : (i32) -> i30
    %14 = comb.icmp eq %13, %c0_i30 : i30
    %15 = comb.mux %14, %c0_i2, %c-1_i2 : i2
    %16 = llhd.sig.extract %pipe from %15 : <i4> -> <i3>
    %17 = llhd.prb %pipe : i4
    %18 = comb.extract %11 from 0 : (i32) -> i30
    %19 = comb.add %18, %c-1_i30 : i30
    %20 = comb.extract %19 from 2 : (i30) -> i28
    %21 = comb.icmp eq %20, %c0_i28 : i28
    %22 = comb.extract %19 from 0 : (i30) -> i2
    %23 = comb.concat %22, %c0_i2 : i2, i2
    %24 = comb.mux %21, %23, %c-1_i4 : i4
    %25 = comb.shru %17, %24 : i4
    %26 = comb.extract %25 from 0 : (i4) -> i3
    llhd.drv %16, %26 after %0 : i3
    %27 = comb.add %11, %c1_i32 : i32
    cf.br ^bb5(%27 : i32)
  }
  %2 = llhd.prb %pipe : i4
  llhd.assign %clk_0, %clk : i1
  llhd.assign %reset_1, %reset : i1
  llhd.assign %enable_2, %enable : i1
  llhd.assign %data_in_3, %data_in : i4
  hw.output %2 : i4
}
