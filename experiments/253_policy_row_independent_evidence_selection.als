module experiments/observation_253_policy_row_independent_evidence_selection

-- Observation 253
--
-- After production separated policy-object availability from read-only Movement
-- evidence, one syntactic coupling remains: the complete v2 manifest decoder
-- rejects a malformed LocusAdmission row before the five household rows can be
-- selected. Model whether read-only selection can ignore only that row while
-- retaining strict manifest-envelope and five-family validation.

abstract sig Family {}
one sig EventFamily, ActualValidityFamily, EventDescriptionFamily,
  RelationUnitFamily, RelationDischargeFamily extends Family {}

abstract sig Health {}
one sig Good, Bad extends Health {}

sig ManifestState {
  envelope : one Health,
  evidenceRow : Family -> one Health,
  policyRow : one Health
}

pred evidenceRowsGood[m : ManifestState] {
  all family : Family | m.evidenceRow[family] = Good
}

pred evidenceReadable[m : ManifestState] {
  m.envelope = Good
  evidenceRowsGood[m]
}

pred fullWorldReadable[m : ManifestState] {
  evidenceReadable[m]
  m.policyRow = Good
}

pred policyRowOnlyFailureLeavesEvidenceReadable {
  some m : ManifestState |
    m.envelope = Good
    and evidenceRowsGood[m]
    and m.policyRow = Bad
    and evidenceReadable[m]
    and not fullWorldReadable[m]
}

assert PolicyRowFailureNeverMakesFullWorldReadable {
  all m : ManifestState |
    m.policyRow = Bad implies not fullWorldReadable[m]
}

assert AnyEvidenceRowFailureBlocksEvidenceRead {
  all m : ManifestState |
    (some family : Family | m.evidenceRow[family] = Bad)
      implies not evidenceReadable[m]
}

assert MalformedEnvelopeBlocksEvidenceRead {
  all m : ManifestState |
    m.envelope = Bad implies not evidenceReadable[m]
}

-- Policy-row health is not an input to the evidence answer once envelope and all
-- five household rows are fixed. This captures the intended read-only parser
-- factorization without making malformed evidence acceptable.
assert PolicyRowHealthCannotChangeEvidenceAvailability {
  all left, right : ManifestState |
    left.envelope = right.envelope
    and all family : Family | left.evidenceRow[family] = right.evidenceRow[family]
      implies (evidenceReadable[left] iff evidenceReadable[right])
}

-- The same factorization must not erase the policy distinction from the full
-- write-capable world.
pred SameEvidenceDifferentPolicyCanChangeFullWorldAvailability {
  some left, right : ManifestState |
    left.envelope = Good
    and right.envelope = Good
    and evidenceRowsGood[left]
    and evidenceRowsGood[right]
    and left.policyRow != right.policyRow
    and fullWorldReadable[left]
    and not fullWorldReadable[right]
}

run policyRowOnlyFailureLeavesEvidenceReadable for 4 but exactly 5 Family, 4 ManifestState
check PolicyRowFailureNeverMakesFullWorldReadable for 4 but exactly 5 Family, 4 ManifestState
check AnyEvidenceRowFailureBlocksEvidenceRead for 4 but exactly 5 Family, 4 ManifestState
check MalformedEnvelopeBlocksEvidenceRead for 4 but exactly 5 Family, 4 ManifestState
check PolicyRowHealthCannotChangeEvidenceAvailability for 4 but exactly 5 Family, 4 ManifestState
run SameEvidenceDifferentPolicyCanChangeFullWorldAvailability for 4 but exactly 5 Family, 4 ManifestState
