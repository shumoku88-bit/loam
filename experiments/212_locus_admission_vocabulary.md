# Observation 212 — Is observed Locus history enough to guard new writes?

Status: **ACTIVE — selected formal pressure / RESEARCH_ONLY**

## Household pressure

LOAM currently keeps `LocusId` intentionally small: one opaque stable token with no built-in Account, ExpenseCategory, ownership, debit/credit, or reporting role.

That semantic compression is useful, but the practical writer currently treats previously observed Loci only as completion hints. Human input remains free text. Therefore a household that already uses:

```text
coffee
```

can accidentally publish:

```text
cafe
```

as a distinct new `LocusId`.

For a daily-use TUI this is not merely a completion-quality problem. It is a canonical admission problem: a typo can silently create a new identity and fragment later projections.

The question is deliberately narrower than “should LOAM add Accounts?”

> What is the smallest information needed to decide whether one `LocusId` may appear in a newly published quantity Effect?

## Current implementation boundary

Production main `113b580a61ec3fd78b15c3662bf1b2e0bed87c56` currently has:

```text
LocusId
  token : String
```

`CompletionPrompt.knownLoci` derives tokens from retained Event history and shows prefix candidates. Its contract explicitly says that the typed text remains the accepted value; a candidate is only a hint.

Ordinary Movement recording and Scheduled entry feed those hints into the existing movement collector. `MovementAdmission.admit?` subsequently admits Event/relation/date/description evidence, but it owns no closed Locus vocabulary and therefore cannot reject a novel spelling merely because the spelling was never approved.

This observation does not change those writers yet.

## Candidate distinction

The candidate separates two sets that are currently easy to conflate:

```text
historically referenced Loci
    !=
Loci approved for new publication
```

The second set is observation vocabulary here, called `approved`.

Its only proposed meaning is:

> A new quantity-bearing canonical write may use this `LocusId`.

It does **not** imply:

- Account;
- ExpenseCategory;
- asset/liability/income/expense role;
- ownership or custody;
- purpose routing;
- display hierarchy;
- debit/credit meaning;
- report classification.

A household UI may eventually label the surface “Loci”, “科目”, or another recognition-friendly term without changing this narrow retained meaning.

## Why history alone is under pressure

Three practical cases distinguish observed history from an explicit admission vocabulary.

### 1. Approved before first use

A user may deliberately add a new locus before recording the first Event that uses it.

```text
approved: books
history:  no books yet
```

A vocabulary derived only from historical Events cannot represent this state.

### 2. Historical but no longer permitted for new writes

A legacy spelling or known mistake may remain in old immutable evidence while being blocked from future use.

```text
history:   cafe
approved:  coffee
```

Requiring every historically referenced token to remain approved forever would turn old mistakes into permanent input vocabulary.

Historical readability must therefore not depend on current new-write permission.

### 3. Policy can change during human think time

The TUI may load an approved vocabulary, the user may spend time editing, and another canonical operation may change that vocabulary before publication.

The same safety pattern already used elsewhere in LOAM should apply:

```text
read for hints / editing
        |
        v
human think time
        |
        v
re-read current admission authority under writer ownership
        |
        v
admit or refuse
```

A TUI-side exact-match check is useful feedback, but cannot be the final authority.

## Alloy vocabulary

The bounded model uses three distinct tokens:

```text
Coffee
Cafe
NewPurpose
```

and two observation-local worlds, each containing:

```text
used      historical references
approved  explicit new-write vocabulary
```

New-write admissibility is exactly membership in `approved`.

The model intentionally contains no Account or category structure because the selected question does not ask for one.

## Selected probes

The observation asks whether:

1. an approved-but-never-used Locus can exist;
2. a historically used but currently disallowed Locus can exist;
3. equal historical usage can coexist with different new-write admission decisions;
4. a policy change can occur while Event history remains equal;
5. history alone determines new-write admission;
6. every historical Locus must remain approved;
7. equal explicit approval sets determine the selected admission answer;
8. a token outside the explicit approval set is always rejected.

Expected matrix:

```text
approvedUnusedCanExist                    SAT
historicalLocusCanBeDisallowed            SAT
sameHistoryDifferentAdmission             SAT
sameHistoryPolicyChangesDuringDraft        SAT
ObservedHistoryDeterminesNewWriteAdmission SAT counterexample
EveryHistoricalLocusMustRemainApproved     SAT counterexample
EqualApprovalDeterminesNewWriteAdmission   UNSAT counterexample
UnapprovedLocusIsRejected                  UNSAT counterexample
```

## Candidate finding if the matrix survives

If the selected checks survive, the smallest information for this safety requirement is not richer `LocusId` semantics. It is one explicit **new-write admission vocabulary** over existing `LocusId` identities.

That would support the product contract:

```text
known approved locus
    -> may be used by a new draft

unknown / unapproved locus
    -> refuse publication
    -> show candidates or an explicit “add locus” path
```

while preserving:

```text
old canonical evidence containing a no-longer-approved token
    -> remains readable and reconstructable
```

This would earn an independently retained operational policy only if practical dogfood continues to require closed vocabulary. It would **not** earn Account, AccountType, ExpenseCategory, or a chart-of-accounts ontology.

## Production pressure after qualification

A practical implementation would still need to determine:

- where the admission vocabulary is physically authoritative;
- how its writer is owned and atomically published;
- how the current household data is bootstrapped without blessing known historical mistakes accidentally;
- whether every quantity-bearing writer consumes the same admission check;
- whether a locus can be removed from new-write permission without introducing a larger retirement lifecycle;
- how a TUI adds a genuinely new locus intentionally;
- whether friendly display aliases are needed separately from stable identity.

The guard must not live only in the TUI. Ordinary Movement, Scheduled creation, Scheduled realization/replacement paths, AI-assisted publication, and any future writer that creates Effects must cross the same current admission boundary.

## Current household migration note

The current canonical Event authority already contains many stable Locus tokens, including payment locations, expense/income labels, liabilities, and historical names. Therefore an initial admission vocabulary cannot safely be synthesized as “every token ever seen” and immediately treated as the final curated list.

Bootstrap should instead be an explicit cutover step:

1. enumerate every Locus referenced by current canonical families;
2. review the set for legacy/accidental identities;
3. publish the intentionally approved new-write vocabulary;
4. verify every intended daily writer against it;
5. only then turn rejection on.

No data rewrite is required merely to stop a legacy token from being used again.

## Deliberate boundaries

Observation 212 does not establish:

- production persistence format;
- a new Core `Account` type;
- expense/income classification;
- hierarchical locus names;
- rename or alias semantics;
- a retirement state machine;
- automatic typo correction;
- a TUI layout;
- migration of current household data;
- permission to reject historical reads.

It tests only whether observed history is information-sufficient for safe new-write admission, and whether one explicit set is sufficient for that selected question.
