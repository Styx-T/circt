//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "circt/Dialect/Comb/CombOps.h"
#include "circt/Dialect/HW/HWOps.h"
#include "circt/Dialect/LLHD/LLHDOps.h"
#include "circt/Dialect/LLHD/LLHDPasses.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/Matchers.h"
#include "mlir/Pass/Pass.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/Support/Debug.h"

#include <cstdint>
#include <memory>
#include <optional>
#include <utility>

#define DEBUG_TYPE "llhd-prove-boolean-enables"

namespace circt {
namespace llhd {
#define GEN_PASS_DEF_PROVEBOOLEANENABLESPASS
#include "circt/Dialect/LLHD/LLHDPasses.h.inc"
} // namespace llhd
} // namespace circt

using namespace mlir;
using namespace circt;
using namespace llhd;

static constexpr unsigned maxLeafBits = 10;
static constexpr unsigned maxConeOps = 256;
/// Support ops whose 2 states we can evaluate w/ their existing fold hooks.
static bool isSupported(Operation *op) {
  return isa<comb::AndOp, comb::OrOp, comb::XorOp, comb::ICmpOp, comb::ConcatOp,
             comb::MuxOp, comb::ReplicateOp>(op);
}

namespace {

class BooleanCone {
public:
  std::optional<bool> prove(Value enable);

private:
  bool collect(Value value);
  std::optional<bool> evaluate(uint64_t assignment,
                               const DenseMap<Value, Operation *> &clones,
                               DenseMap<Value, Attribute> &values) const;

  Value theEnableWire;
  /// Reverse, every operand is visited before its consumer.
  SmallVector<Value> order;
  /// For each opaque leaf, the assignment slot of each result bit.
  DenseMap<Value, SmallVector<unsigned>> leafSlots;
  /// Overlapping extracts share slots for identical underlying bits.
  DenseMap<std::pair<Value, unsigned>, unsigned> bitSlots;
  DenseSet<Value> visited;
  DenseSet<Value> visiting;
  DenseMap<Value, Attribute> constants;
  unsigned leafBits = 0;
  unsigned coneOps = 0;
};

bool BooleanCone::collect(Value value) {
  if (visited.count(value))
    return true;

  // false if the value was already in visiting, walked back into a wire you’re
  // still in the middle of resolving, rescursion.
  if (!visiting.insert(value).second)
    return false;

  auto finish = [&] {
    visiting.erase(value);
    visited.insert(value);
    order.push_back(value);
    return true;
  };

  // Constants consume no truth-table inputs.
  Attribute constant;
  if (matchPattern(value, m_Constant(&constant))) {
    if (!isa<IntegerAttr>(constant))
      return false;

    constants[value] = constant;
    return finish();
  }

  // Supported operations are traversed recursively.
  Operation *op = value.getDefiningOp();

  if (op && op->getNumResults() == 1 && isSupported(op)) {
    if (++coneOps > maxConeOps)
      return false;

    for (Value operand : op->getOperands())
      if (!collect(operand))
        return false;
    return finish();
  }

  // Unsupported ops, block args, and comb.extract => opaque leaf.
  auto type = dyn_cast<IntegerType>(value.getType());
  if (!type || !type.isSignless())
    return false;
  unsigned width = type.getWidth();
  if (width == 0)
    return false;

  // unroll nested comb.extracts to id the underlying bit positions.
  Value base = value;
  unsigned lowBit = 0;
  DenseSet<Value> seenExtracts;
  while (auto extract = base.getDefiningOp<comb::ExtractOp>()) {
    if (!seenExtracts.insert(base).second)
      return false;
    lowBit += extract.getLowBit();
    base = extract.getInput();
  }

  SmallVector<unsigned> slots;
  slots.reserve(width);

  for (unsigned bit = 0; bit < width; ++bit) {
    auto key = std::make_pair(base, lowBit + bit);
    auto it = bitSlots.find(key);

    if (it == bitSlots.end()) {
      if (leafBits == maxLeafBits)
        return false;
      it = bitSlots.try_emplace(key, leafBits++).first;
    }

    slots.push_back(it->second);
  }

  leafSlots[value] = std::move(slots);
  return finish();
}

std::optional<bool>
BooleanCone::evaluate(uint64_t assignment,
                      const DenseMap<Value, Operation *> &clones,
                      DenseMap<Value, Attribute> &values) const {
  for (Value value : order) {
    if (constants.count(value))
      continue;

    // Reconstruct the leaf from its underlying bit assignments.
    if (auto it = leafSlots.find(value); it != leafSlots.end()) {
      auto type = cast<IntegerType>(value.getType());
      unsigned width = type.getWidth();
      APInt bits(width, 0);

      for (unsigned bit = 0; bit < width; ++bit)
        if ((assignment >> it->second[bit]) & 1)
          bits.setBit(bit);

      values[value] = IntegerAttr::get(type, bits);
      continue;
    }

    Operation *op = value.getDefiningOp();

    SmallVector<Attribute> operands;
    operands.reserve(op->getNumOperands());

    for (Value operand : op->getOperands()) {
      auto it = values.find(operand);
      if (it == values.end())
        return std::nullopt;

      operands.push_back(it->second);
    }

    // Clones are prepared once for the entire proof.
    Operation *copy = clones.lookup(value);

    SmallVector<OpFoldResult> results;
    LogicalResult status = copy->fold(operands, results);

    // A successful in-place fold may mutate the clone. Abandon the
    // entire proof instead of reusing a potentially modified operation.
    if (failed(status) || results.size() != 1)
      return std::nullopt;

    Attribute result;
    OpFoldResult folded = results.front();

    if (auto attr = folded.dyn_cast<Attribute>()) {
      result = attr;
    } else if (auto forwarded = folded.dyn_cast<Value>()) {
      // Only forward original operands, whose values were evaluated.
      if (llvm::is_contained(op->getOperands(), forwarded)) {
        auto it = values.find(forwarded);
        if (it != values.end())
          result = it->second;
      }
    }

    // Abandon unsupported fold, or non-integer result.
    if (!isa_and_nonnull<IntegerAttr>(result))
      return std::nullopt;

    values[value] = result;
  }

  auto result = dyn_cast_or_null<IntegerAttr>(values.lookup(theEnableWire));
  if (!result || result.getType() != theEnableWire.getType())
    return std::nullopt;

  return result.getValue().getBoolValue();
}

struct OperationDeleter {
  void operator()(Operation *op) const { op->destroy(); }
};

std::optional<bool> BooleanCone::prove(Value enable) {
  auto type = dyn_cast<IntegerType>(enable.getType());
  if (!type || !type.isSignless() || type.getWidth() != 1)
    return std::nullopt;

  theEnableWire = enable;

  if (!collect(enable))
    return std::nullopt;

  // Own detached clones for the entire proof, including early exits.
  SmallVector<std::unique_ptr<Operation, OperationDeleter>> ownedClones;
  DenseMap<Value, Operation *> clones;

  for (Value value : order) {
    if (leafSlots.count(value) || constants.count(value))
      continue;

    Operation *copy = value.getDefiningOp()->clone();
    ownedClones.emplace_back(copy);
    clones[value] = copy;
  }

  // Constants are fixed; leaves and computed values are overwritten
  // in dependency order on every assignment.
  DenseMap<Value, Attribute> values = constants;

  uint64_t combinations = uint64_t{1} << leafBits;

  std::optional<bool> firstResult;

  for (uint64_t assignment = 0; assignment < combinations; ++assignment) {
    auto result = evaluate(assignment, clones, values);

    if (!result)
      return std::nullopt;

    if (!firstResult) {
      firstResult = *result;
      continue;
    }

    // break early.
    if (*result != *firstResult)
      return std::nullopt;
  }

  return firstResult;
}

//===----------------------------------------------------------------------===//
// Pass
//===----------------------------------------------------------------------===//

struct ProveBooleanEnablesPass
    : public llhd::impl::ProveBooleanEnablesPassBase<ProveBooleanEnablesPass> {
  void runOnOperation() override;
};

} // namespace

void ProveBooleanEnablesPass::runOnOperation() {
  DenseMap<Value, std::optional<bool>> proofCache;
  SmallVector<DriveLikeOp> candidates;

  getOperation().walk([&](DriveLikeOp op) { candidates.push_back(op); });

  for (DriveLikeOp op : candidates) {
    Value enable = op.getEnable();
    if (!enable)
      continue;

    auto [it, inserted] = proofCache.try_emplace(enable);
    if (inserted)
      it->second = BooleanCone().prove(enable);

    std::optional<bool> result = it->second;
    if (!result)
      continue;

    LLVM_DEBUG(llvm::dbgs() << "Proved enable " << (*result ? "true" : "false")
                            << " for " << op->getName() << "\\n");

    if (!*result) {
      op->erase();
      continue;
    }
    op.getEnableMutable().clear();
  }
}
