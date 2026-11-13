// RUN: circt-opt --llhd-unroll-loops %s | FileCheck %s

// A nested loop whose start depends on the outer induction variable, as in
// `for (i = 0; i < 3; ++i) for (j = i + 1; j < 3; ++j)`, only has a constant
// start once the outer loop is unrolled and `i + 1` is folded. Both loops must
// end up unrolled.

// CHECK-LABEL: @TriangularNestedLoops(
hw.module @TriangularNestedLoops(out z : i1) {
  // CHECK: llhd.combinational
  // CHECK-NOT: cf.cond_br
  // CHECK: llhd.yield
  %0 = llhd.combinational -> i1 {
    %c0_i32 = hw.constant 0 : i32
    %c1_i32 = hw.constant 1 : i32
    %c3_i32 = hw.constant 3 : i32
    %false = hw.constant false
    cf.br ^bb1(%c0_i32, %false : i32, i1)
  ^bb1(%i: i32, %acc: i1):
    %1 = comb.icmp slt %i, %c3_i32 : i32
    cf.cond_br %1, ^bb2, ^bb6(%acc : i1)
  ^bb2:
    %2 = comb.add %i, %c1_i32 : i32
    cf.br ^bb3(%2, %acc : i32, i1)
  ^bb3(%j: i32, %acc2: i1):
    %3 = comb.icmp slt %j, %c3_i32 : i32
    cf.cond_br %3, ^bb4, ^bb5(%acc2 : i1)
  ^bb4:
    %4 = comb.icmp eq %i, %j : i32
    %5 = comb.xor %acc2, %4 : i1
    %6 = comb.add %j, %c1_i32 : i32
    cf.br ^bb3(%6, %5 : i32, i1)
  ^bb5(%acc3: i1):
    %7 = comb.add %i, %c1_i32 : i32
    cf.br ^bb1(%7, %acc3 : i32, i1)
  ^bb6(%r: i1):
    llhd.yield %r : i1
  }
  hw.output %0 : i1
}
