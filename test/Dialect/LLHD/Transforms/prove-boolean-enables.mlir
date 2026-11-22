// RUN: circt-opt %s --llhd-prove-boolean-enables | FileCheck %s

// Constant enables are handled without any truth-table inputs.
// CHECK-LABEL: hw.module @literal_true(
// CHECK: llhd.assign {{.*}} : i1
// CHECK-NOT: llhd.assign
// CHECK: hw.output
hw.module @literal_true(in %sig: !llhd.ref<i1>, in %data: i1) {
  %enable = hw.constant true
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// CHECK-LABEL: hw.module @literal_false(
// CHECK-NOT: llhd.assign
// CHECK: hw.output
hw.module @literal_false(in %sig: !llhd.ref<i1>, in %data: i1) {
  %enable = hw.constant false
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// A mux whose arms are equal is constant despite a variable selector.
// CHECK-LABEL: hw.module @mux_true(
// CHECK: llhd.assign {{.*}} : i1
// CHECK-NOT: llhd.assign
// CHECK: hw.output
hw.module @mux_true(in %sig: !llhd.ref<i1>, in %data: i1, in %sel: i1) {
  %true = hw.constant true
  %enable = comb.mux %sel, %true, %true : i1
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// The AND/OR/XOR folding path proves x | !x.
// CHECK-LABEL: hw.module @or_complement(
// CHECK: llhd.assign {{.*}} : i1
// CHECK-NOT: llhd.assign
// CHECK: hw.output
hw.module @or_complement(in %sig: !llhd.ref<i1>, in %data: i1, in %a: i1) {
  %true = hw.constant true
  %not = comb.xor bin %a, %true : i1
  %enable = comb.or bin %a, %not : i1
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// A tautology with a nonconstant input must lose its enable.
// CHECK-LABEL: hw.module @true_assign(
// CHECK: llhd.assign {{.*}} : i1
// CHECK-NOT: llhd.assign
// CHECK: hw.output
hw.module @true_assign(in %sig: !llhd.ref<i1>, in %data: i1, in %a: i1) {
  %enable = comb.icmp eq %a, %a : i1
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// A contradiction must erase the assignment, not merely clear its enable.
// CHECK-LABEL: hw.module @false_assign(
// CHECK-NOT: llhd.assign
// CHECK: hw.output
hw.module @false_assign(in %sig: !llhd.ref<i1>, in %data: i1, in %a: i1) {
  %enable = comb.icmp ne %a, %a : i1
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// The DriveLikeOp interface must handle timed drives too.
// CHECK-LABEL: hw.module @true_drv(
// CHECK: llhd.drv {{.*}} after {{.*}} : i1
// CHECK-NOT: llhd.drv
// CHECK: hw.output
hw.module @true_drv(in %sig: !llhd.ref<i1>, in %data: i1, in %a: i1) {
  %time = llhd.constant_time <0ns, 1d>
  %enable = comb.icmp eq %a, %a : i1
  llhd.drv %sig, %data after %time if %enable : i1
  hw.output
}

// CHECK-LABEL: hw.module @false_drv(
// CHECK-NOT: llhd.drv
// CHECK: hw.output
hw.module @false_drv(in %sig: !llhd.ref<i1>, in %data: i1, in %a: i1) {
  %time = llhd.constant_time <0ns, 1d>
  %enable = comb.icmp ne %a, %a : i1
  llhd.drv %sig, %data after %time if %enable : i1
  hw.output
}

// An arbitrary input is not provably constant.
// CHECK-LABEL: hw.module @variable_enable(
// CHECK: llhd.assign {{.*}} if {{.*}} : i1
// CHECK: llhd.drv {{.*}} after {{.*}} if {{.*}} : i1
// CHECK: hw.output
hw.module @variable_enable(in %sig: !llhd.ref<i1>, in %data: i1, in %enable: i1) {
  %time = llhd.constant_time <0ns, 1d>
  llhd.assign %sig, %data if %enable : i1
  llhd.drv %sig, %data after %time if %enable : i1
  hw.output
}

// A shared enable must be proved once and applied to every user.
// CHECK-LABEL: hw.module @shared_enable(
// CHECK: llhd.assign {{.*}} : i1
// CHECK: llhd.drv {{.*}} after {{.*}} : i1
// CHECK-NOT: if
// CHECK: hw.output
hw.module @shared_enable(in %sig: !llhd.ref<i1>, in %data: i1, in %a: i1) {
  %time = llhd.constant_time <0ns, 1d>
  %enable = comb.icmp eq %a, %a : i1
  llhd.assign %sig, %data if %enable : i1
  llhd.drv %sig, %data after %time if %enable : i1
  hw.output
}

// Two extracts of the same underlying bit must share a truth-table slot.
// The first path also tests nested extract offsets.
// CHECK-LABEL: hw.module @overlapping_extracts(
// CHECK: llhd.assign {{.*}} : i1
// CHECK-NOT: llhd.assign
// CHECK: hw.output
hw.module @overlapping_extracts(in %sig: !llhd.ref<i1>, in %data: i1, in %wide: i3) {
  %low = comb.extract %wide from 0 : (i3) -> i2
  %high = comb.extract %wide from 1 : (i3) -> i2
  %from_low = comb.extract %low from 1 : (i2) -> i1
  %from_high = comb.extract %high from 0 : (i2) -> i1
  %enable = comb.icmp eq %from_low, %from_high : i1
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// comb.add is not in the supported operation set. Its i1 result is an
// opaque leaf, so the prover must preserve the conditional assignment.
// CHECK-LABEL: hw.module @unsupported_leaf(
// CHECK: llhd.assign {{.*}} if {{.*}} : i1
// CHECK: hw.output
hw.module @unsupported_leaf(in %sig: !llhd.ref<i1>, in %data: i1, in %a: i1, in %b: i1) {
  %enable = comb.add %a, %b : i1
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// Exactly ten distinct leaf bits are within the exhaustive proof budget.
// CHECK-LABEL: hw.module @ten_leaf_bits(
// CHECK: llhd.assign {{.*}} : i1
// CHECK-NOT: llhd.assign
// CHECK: hw.output
hw.module @ten_leaf_bits(in %sig: !llhd.ref<i1>, in %data: i1,
                         in %a0: i1, in %a1: i1, in %a2: i1,
                         in %a3: i1, in %a4: i1, in %a5: i1,
                         in %a6: i1, in %a7: i1, in %a8: i1,
                         in %a9: i1) {
  %x1 = comb.xor bin %a0, %a1 : i1
  %x2 = comb.xor bin %x1, %a2 : i1
  %x3 = comb.xor bin %x2, %a3 : i1
  %x4 = comb.xor bin %x3, %a4 : i1
  %x5 = comb.xor bin %x4, %a5 : i1
  %x6 = comb.xor bin %x5, %a6 : i1
  %x7 = comb.xor bin %x6, %a7 : i1
  %x8 = comb.xor bin %x7, %a8 : i1
  %x9 = comb.xor bin %x8, %a9 : i1
  %enable = comb.icmp eq %x9, %x9 : i1
  llhd.assign %sig, %data if %enable : i1
  hw.output
}

// Eleven distinct leaf bits exceed the budget, even for a tautology.
// CHECK-LABEL: hw.module @eleven_leaf_bits(
// CHECK: llhd.assign {{.*}} if {{.*}} : i1
// CHECK: hw.output
hw.module @eleven_leaf_bits(in %sig: !llhd.ref<i1>, in %data: i1,
                            in %a0: i1, in %a1: i1, in %a2: i1,
                            in %a3: i1, in %a4: i1, in %a5: i1,
                            in %a6: i1, in %a7: i1, in %a8: i1,
                            in %a9: i1, in %a10: i1) {
  %x1 = comb.xor bin %a0, %a1 : i1
  %x2 = comb.xor bin %x1, %a2 : i1
  %x3 = comb.xor bin %x2, %a3 : i1
  %x4 = comb.xor bin %x3, %a4 : i1
  %x5 = comb.xor bin %x4, %a5 : i1
  %x6 = comb.xor bin %x5, %a6 : i1
  %x7 = comb.xor bin %x6, %a7 : i1
  %x8 = comb.xor bin %x7, %a8 : i1
  %x9 = comb.xor bin %x8, %a9 : i1
  %x10 = comb.xor bin %x9, %a10 : i1
  %enable = comb.icmp eq %x10, %x10 : i1
  llhd.assign %sig, %data if %enable : i1
  hw.output
}
