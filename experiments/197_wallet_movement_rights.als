module experiments/observation_197_wallet_movement_rights

-- F033 asks whether equal wallet quantity, even with the same broad household
-- allocation eligibility, determines which future movements are permitted.
--
-- The model is deliberately neutral. `RightKind` does not encode PayPay product
-- names and is experiment-local evidence only.

sig Wallet {}
sig Amount {}

abstract sig RightKind {}
one sig Spend, Send, Withdraw extends RightKind {}

sig World {
  -- Numeric holding projection for the selected wallet.
  quantity: Wallet -> one Amount,

  -- Reuse Observation 048's already-qualified distinction: held quantity may
  -- or may not participate in household allocation. F033 holds this equal so
  -- the new pressure is not merely another eligibility witness.
  allocatable: set Wallet,

  -- Candidate future-movement permission evidence.
  allowed: Wallet -> set RightKind
}

one sig Left, Right extends World {}

fun spendable[w: World]: set Wallet {
  { x: Wallet | Spend in x.(w.allowed) }
}

fun sendable[w: World]: set Wallet {
  { x: Wallet | Send in x.(w.allowed) }
}

fun withdrawable[w: World]: set Wallet {
  { x: Wallet | Withdraw in x.(w.allowed) }
}

pred representativeRestrictedWallet {
  some x: Wallet | {
    x in Left.allocatable
    x in spendable[Left]
    x in sendable[Left]
    x not in withdrawable[Left]
  }
}

-- Central F033 witness: every selected quantitative/allocation fact agrees,
-- but one future operation is permitted in only one world.
pred sameQuantityAndAllocationDifferentRights {
  Left.quantity = Right.quantity
  Left.allocatable = Right.allocatable

  some x: Wallet | {
    x in Left.allocatable
    x in spendable[Left]
    x in spendable[Right]
    x in sendable[Left]
    x in sendable[Right]
    x in withdrawable[Left]
    x not in withdrawable[Right]
  }
}

-- A second witness keeps quantity and spendability equal while transferability
-- differs, showing that one coarse `usable` flag would also be too small.
pred sameQuantityAndSpendabilityDifferentTransferRight {
  Left.quantity = Right.quantity
  spendable[Left] = spendable[Right]

  some x: Wallet | {
    x in spendable[Left]
    x in sendable[Left]
    x not in sendable[Right]
  }
}

-- Deliberately too strong. If true, quantity plus Observation-048-style
-- allocation eligibility would determine all selected future movement rights.
assert QuantityAndAllocationDetermineRights {
  Left.quantity = Right.quantity and
  Left.allocatable = Right.allocatable implies
    Left.allowed = Right.allowed
}

-- Also deliberately too strong. A single broad spendability answer must not be
-- assumed to reconstruct transfer / withdrawal permission.
assert SpendabilityDeterminesAllRights {
  Left.quantity = Right.quantity and
  spendable[Left] = spendable[Right] implies {
    sendable[Left] = sendable[Right]
    withdrawable[Left] = withdrawable[Right]
  }
}

-- Positive sufficiency for only the selected vocabulary. Once quantity,
-- allocation eligibility, and explicit right evidence are equal, all selected
-- views are equal.
assert ExplicitRightsDetermineSelectedViews {
  Left.quantity = Right.quantity and
  Left.allocatable = Right.allocatable and
  Left.allowed = Right.allowed implies {
    spendable[Left] = spendable[Right]
    sendable[Left] = sendable[Right]
    withdrawable[Left] = withdrawable[Right]
  }
}

run representativeRestrictedWallet for exactly 2 Wallet, exactly 2 Amount, exactly 2 World
run sameQuantityAndAllocationDifferentRights for exactly 2 Wallet, exactly 2 Amount, exactly 2 World
run sameQuantityAndSpendabilityDifferentTransferRight for exactly 2 Wallet, exactly 2 Amount, exactly 2 World
check QuantityAndAllocationDetermineRights for exactly 2 Wallet, exactly 2 Amount, exactly 2 World
check SpendabilityDeterminesAllRights for exactly 2 Wallet, exactly 2 Amount, exactly 2 World
check ExplicitRightsDetermineSelectedViews for exactly 2 Wallet, exactly 2 Amount, exactly 2 World
