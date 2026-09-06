module experiments/observation_212_locus_admission_vocabulary

-- Household pressure:
-- a remembered Locus such as `coffee` is currently only a completion hint.
-- A typo such as `cafe` can still become a fresh Locus on publication.
--
-- This observation asks whether the set of historically observed Loci is enough
-- to answer a different question:
--
--   "May this Locus be used by a new canonical quantity Effect?"
--
-- `approved` is observation vocabulary for an explicit new-write admission
-- vocabulary. It deliberately carries no Account, category, ownership, debit,
-- credit, or reporting-role meaning.

abstract sig Locus {}
one sig Coffee, Cafe, NewPurpose extends Locus {}

sig World {
  used: set Locus,
  approved: set Locus
}

one sig Left, Right extends World {}

pred admissible[w: World, l: Locus] {
  l in w.approved
}

-- An explicitly approved Locus may exist before its first Event. This cannot be
-- represented if the admission vocabulary is derived only from history.
pred approvedUnusedCanExist {
  NewPurpose in Left.approved
  NewPurpose not in Left.used
}

-- Historical readability and permission for new writes are different. A legacy
-- spelling or retired operational token may remain in retained Events while new
-- publication through that token is refused.
pred historicalLocusCanBeDisallowed {
  Cafe in Left.used
  Cafe not in Left.approved
}

-- Two worlds can have byte-for-byte-equivalent observed Locus history while
-- making different new-write decisions. History therefore does not determine
-- admission policy.
pred sameHistoryDifferentAdmission {
  Left.used = Right.used
  Coffee in Left.used
  Cafe not in Left.used
  Cafe in Left.approved
  Cafe not in Right.approved
}

-- This is deliberately too strong. If it had no counterexample, deriving the
-- new-write vocabulary from Event history would be information-sufficient.
assert ObservedHistoryDeterminesNewWriteAdmission {
  all left, right: World |
    left.used = right.used implies
      all l: Locus | admissible[left, l] iff admissible[right, l]
}

-- Also deliberately too strong: preserving an old Event must not force every
-- historical token to remain legal for future publication forever.
assert EveryHistoricalLocusMustRemainApproved {
  all w: World | w.used in w.approved
}

-- The explicit approval set is information-sufficient for the selected
-- new-write question. No other household semantics are required to decide it.
assert EqualApprovalDeterminesNewWriteAdmission {
  all left, right: World |
    left.approved = right.approved implies
      all l: Locus | admissible[left, l] iff admissible[right, l]
}

-- A token outside the explicit approval set is always refused by this candidate.
assert UnapprovedLocusIsRejected {
  all w: World, l: Locus |
    l not in w.approved implies not admissible[w, l]
}

-- Human think time can span an approval-policy change even when household Event
-- history is unchanged. This witness pressures publication-time re-admission:
-- preflight acceptance alone cannot authorize a later write.
pred sameHistoryPolicyChangesDuringDraft {
  Left.used = Right.used
  Cafe in Left.approved
  Cafe not in Right.approved
}

run approvedUnusedCanExist for exactly 3 Locus, exactly 2 World
run historicalLocusCanBeDisallowed for exactly 3 Locus, exactly 2 World
run sameHistoryDifferentAdmission for exactly 3 Locus, exactly 2 World
run sameHistoryPolicyChangesDuringDraft for exactly 3 Locus, exactly 2 World
check ObservedHistoryDeterminesNewWriteAdmission for exactly 3 Locus, exactly 2 World
check EveryHistoricalLocusMustRemainApproved for exactly 3 Locus, exactly 2 World
check EqualApprovalDeterminesNewWriteAdmission for exactly 3 Locus, exactly 2 World
check UnapprovedLocusIsRejected for exactly 3 Locus, exactly 2 World
