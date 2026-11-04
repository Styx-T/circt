// RUN: circt-opt --llhd-unroll-loops %s | FileCheck %s

// Two loops in sequence where the second starts at the first one's final
// induction value. The second loop is not nested in the first, but only
// becomes matchable once the first is unrolled and its induction variable is
// replaced with a constant. The pass must take another round for it.

// CHECK-LABEL: @SequentialLoopsChainedStart(
hw.module @SequentialLoopsChainedStart(out z : i1) {
  // CHECK: llhd.combinational
  // CHECK-NOT: cf.cond_br
  // CHECK: llhd.yield
  %0 = llhd.combinational -> i1 {
    %c0_i32 = hw.constant 0 : i32
    %c1_i32 = hw.constant 1 : i32
    %c2_i32 = hw.constant 2 : i32
    %c4_i32 = hw.constant 4 : i32
    %false = hw.constant false
    cf.br ^bb1(%c0_i32, %false : i32, i1)
  ^bb1(%i: i32, %acc: i1):
    %1 = comb.icmp slt %i, %c2_i32 : i32
    cf.cond_br %1, ^bb2, ^bb3(%i, %acc : i32, i1)
  ^bb2:
    %2 = comb.icmp eq %i, %c1_i32 : i32
    %3 = comb.xor %acc, %2 : i1
    %4 = comb.add %i, %c1_i32 : i32
    cf.br ^bb1(%4, %3 : i32, i1)
  ^bb3(%j: i32, %acc2: i1):
    %5 = comb.icmp slt %j, %c4_i32 : i32
    cf.cond_br %5, ^bb4, ^bb5(%acc2 : i1)
  ^bb4:
    %6 = comb.icmp eq %j, %c2_i32 : i32
    %7 = comb.xor %acc2, %6 : i1
    %8 = comb.add %j, %c1_i32 : i32
    cf.br ^bb3(%8, %7 : i32, i1)
  ^bb5(%r: i1):
    llhd.yield %r : i1
  }
  hw.output %0 : i1
}
