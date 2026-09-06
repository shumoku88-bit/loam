# Observation 212 — Is observed Locus history enough to guard new writes?

Status: **COMPLETE — explicit new-write vocabulary survives / RESEARCH_ONLY**

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

## Executed result

Alloy 6.2.0 + Sat4j produced the expected matrix on PR #479 head `628844e9a8db93a0d824c75fa088580133a20879`.

Dedicated workflow run `34046725046`, job `101522974892`, completed **SUCCESS**:

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

The first counterexample is the central negative result: two worlds may retain exactly the same observed Locus history while making different decisions about whether a new Effect may use a token. Event history therefore cannot be the authority for new-write admission.

The historical-disallow witness closes the other important direction. An old Event may continue to mention a token that is no longer legal for new publication. Historical reconstructability and present input permission are independent.

The equal-approval check establishes information sufficiency for the selected question: once the explicit approval set is fixed, no Account/category semantics or Event-history inference is needed to decide whether a proposed Locus is allowed.

## Finding

The smallest information found for this safety requirement is not richer `LocusId` semantics. It is one explicit **new-write admission vocabulary** over existing `LocusId` identities.

That supports the product contract:

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

Observation 212 therefore earns a new operational policy distinction if LOAM adopts the requested closed-vocabulary product behavior. It does **not** earn Account, AccountType, ExpenseCategory, or a chart-of-accounts ontology.

It also strengthens the publication boundary: because the approval set can change while Event history remains equal, a UI preflight check cannot authorize a later write by itself. The current approval authority must be re-read and enforced at publication/admission time under compatible writer ownership.

## Production pressure after qualification

A practical implementation still needs to determine:

- where the admission vocabulary is physically authoritative;
- how its writer is owned and atomically published;
- how the current household data is bootstrapped without blessing known historical mistakes accidentally;
- whether every quantity-bearing writer consumes the same admission check;
- whether a locus can be removed from new-write permission without introducing a larger retirement lifecycle;
- how a TUI adds a genuinely new locus intentionally;
- whether friendly display aliases are needed separately from stable identity.

The guard must not live only in the TUI. Ordinary Movement, Scheduled creation, Scheduled realization/replacement paths, AI-assisted publication, and any future writer that creates Effects must cross the same current admission boundary.

## Current household migration note

The current household data confirms why the distinction matters. Movement Event history contains long-lived source-shaped names such as `expenses:缶コーヒー`, while current Scheduled evidence contains operational tokens that may not yet have appeared in Actual history, such as `wifi`, `povo`, `gpt-plus`, `health-insurance`, `google-one`, `pension`, `support`, `debt-friend-k`, `rent`, and `utilities`. Quantity basis also names `cash`, `paypay`, `smbc`, `yucho`, and `all-country`.

Therefore an initial admission vocabulary cannot safely be synthesized as “every Event token ever seen” and treated as the final curated set. Event history is simultaneously too broad for legacy spellings and too narrow for approved future-use identities.

Bootstrap should instead be an explicit cutover step:

1. enumerate every Locus referenced by current canonical families;
2. review the set for legacy/accidental identities and desired future-use identities;
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

It establishes only that observed history is information-insufficient for safe new-write admission, while one explicit approved set is information-sufficient for that selected question.
