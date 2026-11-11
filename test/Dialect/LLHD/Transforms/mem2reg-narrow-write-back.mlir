// RUN: circt-opt --llhd-mem2reg %s | FileCheck %s

// Each process writes its own 4-bit lane of `w` and also reads `w`.
// The read makes the whole signal the slot, but the drive at the wait must only cover
// the lane this process writes. Otherwise both processes drive all of `w`.

// CHECK-LABEL: @read_own_lane(
// CHECK-NOT: llhd.drv %w,
// CHECK: llhd.process
// CHECK: llhd.drv {{%.+}}, {{.+}} : i4
// CHECK-NOT: llhd.drv %w,
// CHECK: llhd.process
// CHECK: llhd.drv {{%.+}}, {{.+}} : i4
// CHECK-NOT: llhd.drv %w,
// CHECK: hw.output
hw.module @read_own_lane(in %clk : i1, in %strobe : i1, in %d : i8, out q : i8) {
  %c-4_i3 = hw.constant -4 : i3
  %0 = llhd.constant_time <0ns, 1d>
  %c0_i3 = hw.constant 0 : i3
  %true = hw.constant true
  %c0_i8 = hw.constant 0 : i8
  %false = hw.constant false
  %clk_0 = llhd.sig name "clk" %false : <i1>
  %1 = llhd.prb %clk_0 : i1
  %strobe_1 = llhd.sig name "strobe" %false : <i1>
  %d_2 = llhd.sig name "d" %c0_i8 : <i8>
  %w = llhd.sig : <i8>
  llhd.process {
    cf.br ^bb1
  ^bb1:  // 4 preds: ^bb0, ^bb2, ^bb4, ^bb5
    %3 = llhd.prb %clk_0 : i1
    llhd.wait (%1 : i1), ^bb2
  ^bb2:  // pred: ^bb1
    %4 = llhd.prb %clk_0 : i1
    %5 = comb.xor bin %3, %true : i1
    %6 = comb.and bin %5, %4 : i1
    cf.cond_br %6, ^bb3, ^bb1
  ^bb3:  // pred: ^bb2
    %7 = llhd.prb %strobe_1 : i1
    cf.cond_br %7, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %8 = llhd.sig.extract %w from %c0_i3 : <i8> -> <i4>
    %9 = llhd.prb %d_2 : i8
    %10 = comb.extract %9 from 0 : (i8) -> i4
    llhd.drv %8, %10 after %0 : i4
    cf.br ^bb1
  ^bb5:  // pred: ^bb3
    %11 = llhd.sig.extract %w from %c0_i3 : <i8> -> <i4>
    %12 = llhd.prb %w : i8
    %13 = comb.extract %12 from 0 : (i8) -> i3
    %14 = comb.concat %13, %false : i3, i1
    llhd.drv %11, %14 after %0 : i4
    cf.br ^bb1
  }
  llhd.process {
    cf.br ^bb1
  ^bb1:  // 4 preds: ^bb0, ^bb2, ^bb4, ^bb5
    %3 = llhd.prb %clk_0 : i1
    llhd.wait (%1 : i1), ^bb2
  ^bb2:  // pred: ^bb1
    %4 = llhd.prb %clk_0 : i1
    %5 = comb.xor bin %3, %true : i1
    %6 = comb.and bin %5, %4 : i1
    cf.cond_br %6, ^bb3, ^bb1
  ^bb3:  // pred: ^bb2
    %7 = llhd.prb %strobe_1 : i1
    cf.cond_br %7, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %8 = llhd.sig.extract %w from %c-4_i3 : <i8> -> <i4>
    %9 = llhd.prb %d_2 : i8
    %10 = comb.extract %9 from 4 : (i8) -> i4
    llhd.drv %8, %10 after %0 : i4
    cf.br ^bb1
  ^bb5:  // pred: ^bb3
    %11 = llhd.sig.extract %w from %c-4_i3 : <i8> -> <i4>
    %12 = llhd.prb %w : i8
    %13 = comb.extract %12 from 4 : (i8) -> i3
    %14 = comb.concat %13, %false : i3, i1
    llhd.drv %11, %14 after %0 : i4
    cf.br ^bb1
  }
  %2 = llhd.prb %w : i8
  llhd.assign %clk_0, %clk : i1
  llhd.assign %strobe_1, %strobe : i1
  llhd.assign %d_2, %d : i8
  hw.output %2 : i8
}


// Each process writes overlapping ranges of its own 32-bit lane of `r`. The
// overlap makes the whole signal the slot, but the union of the writes is the
// lane, so only the lane may be driven.

// CHECK-LABEL: @lane_bytes(
// CHECK-NOT: llhd.assign %r,
// CHECK: llhd.process
// CHECK: llhd.assign {{%.+}}, {{.+}} : i32
// CHECK-NOT: llhd.assign %r,
// CHECK: llhd.process
// CHECK: llhd.assign {{%.+}}, {{.+}} : i32
// CHECK-NOT: llhd.assign %r,
// CHECK: hw.output
hw.module @lane_bytes(in %d : i64, in %sel : i4, out q : i64) {
  %c-8_i6 = hw.constant -8 : i6
  %c-16_i6 = hw.constant -16 : i6
  %c-24_i6 = hw.constant -24 : i6
  %c-32_i6 = hw.constant -32 : i6
  %c24_i6 = hw.constant 24 : i6
  %c16_i6 = hw.constant 16 : i6
  %c8_i6 = hw.constant 8 : i6
  %c0_i30 = hw.constant 0 : i30
  %c0_i6 = hw.constant 0 : i6
  %c0_i4 = hw.constant 0 : i4
  %c3_i32 = hw.constant 3 : i32
  %c2_i32 = hw.constant 2 : i32
  %c1_i32 = hw.constant 1 : i32
  %c0_i64 = hw.constant 0 : i64
  %d_0 = llhd.sig name "d" %c0_i64 : <i64>
  %sel_1 = llhd.sig name "sel" %c0_i4 : <i4>
  %r = llhd.sig : <i64>
  %0 = llhd.prb %r : i64
  %1 = llhd.prb %d_0 : i64
  %2 = llhd.prb %sel_1 : i4
  llhd.process {
    cf.br ^bb1
  ^bb1:  // 2 preds: ^bb0, ^bb7
    %3 = llhd.sig.extract %r from %c0_i6 : <i64> -> <i32>
    %4 = llhd.prb %d_0 : i64
    %5 = comb.extract %4 from 0 : (i64) -> i32
    llhd.assign %3, %5 : i32
    %6 = llhd.prb %sel_1 : i4
    %7 = comb.extract %6 from 0 : (i4) -> i2
    %8 = comb.concat %c0_i30, %7 : i30, i2
    %9 = comb.icmp ceq %8, %c1_i32 : i32
    cf.cond_br %9, ^bb2, ^bb3
  ^bb2:  // pred: ^bb1
    %10 = llhd.sig.extract %r from %c8_i6 : <i64> -> <i24>
    %11 = llhd.prb %d_0 : i64
    %12 = comb.extract %11 from 0 : (i64) -> i24
    llhd.assign %10, %12 : i24
    cf.br ^bb7
  ^bb3:  // pred: ^bb1
    %13 = comb.icmp ceq %8, %c2_i32 : i32
    cf.cond_br %13, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %14 = llhd.sig.extract %r from %c16_i6 : <i64> -> <i16>
    %15 = llhd.prb %d_0 : i64
    %16 = comb.extract %15 from 0 : (i64) -> i16
    llhd.assign %14, %16 : i16
    cf.br ^bb7
  ^bb5:  // pred: ^bb3
    %17 = comb.icmp ceq %8, %c3_i32 : i32
    cf.cond_br %17, ^bb6, ^bb7
  ^bb6:  // pred: ^bb5
    %18 = llhd.sig.extract %r from %c24_i6 : <i64> -> <i8>
    %19 = llhd.prb %d_0 : i64
    %20 = comb.extract %19 from 0 : (i64) -> i8
    llhd.assign %18, %20 : i8
    cf.br ^bb7
  ^bb7:  // 4 preds: ^bb2, ^bb4, ^bb5, ^bb6
    llhd.wait (%0, %1, %2 : i64, i64, i4), ^bb1
  }
  llhd.process {
    cf.br ^bb1
  ^bb1:  // 2 preds: ^bb0, ^bb7
    %3 = llhd.sig.extract %r from %c-32_i6 : <i64> -> <i32>
    %4 = llhd.prb %d_0 : i64
    %5 = comb.extract %4 from 32 : (i64) -> i32
    llhd.assign %3, %5 : i32
    %6 = llhd.prb %sel_1 : i4
    %7 = comb.extract %6 from 2 : (i4) -> i2
    %8 = comb.concat %c0_i30, %7 : i30, i2
    %9 = comb.icmp ceq %8, %c1_i32 : i32
    cf.cond_br %9, ^bb2, ^bb3
  ^bb2:  // pred: ^bb1
    %10 = llhd.sig.extract %r from %c-24_i6 : <i64> -> <i24>
    %11 = llhd.prb %d_0 : i64
    %12 = comb.extract %11 from 32 : (i64) -> i24
    llhd.assign %10, %12 : i24
    cf.br ^bb7
  ^bb3:  // pred: ^bb1
    %13 = comb.icmp ceq %8, %c2_i32 : i32
    cf.cond_br %13, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %14 = llhd.sig.extract %r from %c-16_i6 : <i64> -> <i16>
    %15 = llhd.prb %d_0 : i64
    %16 = comb.extract %15 from 32 : (i64) -> i16
    llhd.assign %14, %16 : i16
    cf.br ^bb7
  ^bb5:  // pred: ^bb3
    %17 = comb.icmp ceq %8, %c3_i32 : i32
    cf.cond_br %17, ^bb6, ^bb7
  ^bb6:  // pred: ^bb5
    %18 = llhd.sig.extract %r from %c-8_i6 : <i64> -> <i8>
    %19 = llhd.prb %d_0 : i64
    %20 = comb.extract %19 from 32 : (i64) -> i8
    llhd.assign %18, %20 : i8
    cf.br ^bb7
  ^bb7:  // 4 preds: ^bb2, ^bb4, ^bb5, ^bb6
    llhd.wait (%0, %1, %2 : i64, i64, i4), ^bb1
  }
  llhd.assign %d_0, %d : i64
  llhd.assign %sel_1, %sel : i4
  hw.output %0 : i64
}

