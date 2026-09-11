# Observation 253 — Policy-row independent evidence selection

## Question

After #704, read-only Movement consumers no longer require the selected
LocusAdmission **object**. But `loadSelectedEvidence?` still calls the complete v2
manifest decoder first, so malformed LocusAdmission **row syntax** can still block
all five household evidence families.

Can the read-only parser ignore exactly that policy row while keeping the
selection envelope and every household row fail-closed?

## Proposed factorization

For a v2 selected manifest, read-only evidence selection requires:

```text
valid v2 envelope / exact row shape
valid Event row
valid ActualValidity row
valid EventDescription row
valid RelationUnit row
valid RelationDischarge row
```

It does not require the LocusAdmission row itself to decode.

The full write-capable world still requires all of the above **plus** a valid
LocusAdmission row and object.

This is not permissive manifest parsing. A wrong version/header, missing/extra row,
or malformed household row still refuses the read.

## Expected results

- `policyRowOnlyFailureLeavesEvidenceReadable`: SAT
- `PolicyRowFailureNeverMakesFullWorldReadable`: no counterexample
- `AnyEvidenceRowFailureBlocksEvidenceRead`: no counterexample
- `MalformedEnvelopeBlocksEvidenceRead`: no counterexample
- `PolicyRowHealthCannotChangeEvidenceAvailability`: no counterexample
- `SameEvidenceDifferentPolicyCanChangeFullWorldAvailability`: SAT

## Production candidate if qualified

Factor manifest parsing into one strict household-evidence projection and one
policy-inclusive decode. `loadSelectedEvidence?` consumes only the former;
`loadSelectedWorld?`, publication, exact recovery and recovery validation continue
to require the complete manifest.

A focused regression can extend the existing `EmptyMovementManifest` fixture:
corrupt only the selected LocusAdmission row, verify evidence load succeeds and
full-world load fails, then restore the exact CURRENT bytes. No new test file or
workflow is needed.

## Stop rule

Do not accept malformed household rows, change recovery semantics, add another
manifest format, or create a second authority. Graduate only the parser
factorization if it preserves strict five-family selection.
