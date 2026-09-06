# Observation 209 — Ledger generation / assignment / assertion-order boundary

Status: **Ledger/hledger reconstruction gate; C-seeking bounded composition probe**

## Question

Observation 208 qualified a selected chart/status/posting-date reconstruction without enlarging neutral Event/Effect. The next Ledger/hledger pressure is not another account label. It is generation and prefix-sensitive validation:

```text
close / open / retain generation
+ balance assignment
+ generated balance assertions
+ report-selection context
+ assertion evaluation order
+ generated-vs-retained provenance
```

Can these selected behaviors be reconstructed from already-derived balances plus explicit generation/order/admission policy, or does Event/Effect need a different semantic shape?

## External pressure

hledger 1.52 documents that:

- balance assignments calculate the missing posting amount needed to reach a specified balance;
- `close` has close/open/clopen/assert/assign/retain modes;
- close/open transactions are generated output and only become journal history when retained by the user;
- generated close/open transactions include balance assertions;
- generated close assertions can become fragile if status, realness, auto-posting, date, or other selection context changes;
- hledger checks assertions in date order, with parse order as the same-date tie-breaker;
- Ledger instead checks assertions in parse order, ignoring dates.

Ledger 3 likewise defines balance assignments as amount inference from the prior account balance and target balance.

References:

- https://hledger.org/1.52/hledger.html
- https://ledger-cli.org/doc/ledger3.html

## Relation to earlier LOAM evidence

Observation 207 already qualified separate accounting-only/generated contribution planes, query policy, assertions, and correction-aware horizon in one bounded composition.

Observation 208 qualified hierarchy, inherited/overridden accounting role, posting-specific status, posting-specific date, and report-vs-assertion selection as additive relations/query policy.

Observation 209 therefore treats `fullBalance` and `filteredBalance` as the output interface of those earlier selection layers. It does not duplicate their internal models. The new question begins **after a balance has been selected** and asks what generation/validation behavior depends on that selected prefix or snapshot.

## Observation-local arithmetic

The model uses three balance atoms:

```text
B0 B1 B2
```

and five exact delta atoms:

```text
Minus2 Minus1 ZeroDelta Plus1 Plus2
```

with a small explicit addition/difference table. This avoids treating Alloy integer overflow as accounting evidence.

## Generation modes

The observation-local modes are:

```text
CloseMode
OpenMode
RetainMode
AssignMode
AssertMode
```

For the selected account:

```text
Close / Retain  -> negate selected balance
Open            -> restore selected balance
Assign          -> target - prefix balance
Assert          -> no generated quantity movement
```

For movement-producing modes, an opposite balancing delta is also derived. This tests the smallest double-entry-shaped generated output, not complete hledger formatting or account-selection rules.

## Selection context

Two abstract contexts stand in for the already-qualified selection policy from Observations 207–208:

```text
FullContext
FilteredContext
```

Each world gives the balance visible under each context. Generation and later validation may deliberately use different contexts.

This is not a proposed generic production `SelectionContext` type. It is an observation-local seam for composing prior results with close/assert behavior.

## Generated vs retained

`admitted = No` means a generated close/open-style result remains a preview/output only. `admitted = Yes` lets the generated delta enter the retained view.

The flag does not model a production writer. It asks only whether:

```text
generated result exists
    !=
retained historical fact exists
```

must remain distinguishable.

## Assertion ordering

One observation-local prior posting begins at `B0` and may contribute `0`, `+1`, or `+2`.

The same posting can be ordered before an assertion by either:

```text
ParseOnly
DateThenParse
```

`ParseOnly` models the selected Ledger behavior. `DateThenParse` models the selected hledger behavior. The final balance after the posting is the same either way; only the assertion prefix may differ.

## C-seeking attacks

### 1. Close output exists without retained history

Generate a filtered close from balance `B1`:

```text
selected account  -1
counter account   +1
```

while `admitted = No`.

Expected: **SAT**.

So generated output must not automatically become retained Event history.

### 2. Generated posting shape determines generation meaning

A close from `B1` and an assignment from prefix `B2` to target `B1` both generate `-1/+1`.

Expected: **SAT witness**.

So generated posting values alone do not recover whether they came from close or assignment semantics.

### 3. Assignment amount is prefix/order sensitive

Hold target `B2` and the prior posting fixed. Under parse-only ordering the prior `+1` is visible first, so assignment needs `+1`. Under date-then-parse the later-dated posting is not in the prefix, so assignment needs `+2`.

Expected: **SAT witness**.

Thus target balance alone does not determine a balance-assignment posting.

### 4. Generation does not determine retention

Hold generator inputs fixed and vary only admission.

Expected: **SAT witness**.

This preserves the distinction between command output / inferred candidate and retained history.

### 5. Close assertion depends on matching selection context

Generate close under a filtered `B1` view while the full view is `B2`.

```text
validate filtered: B1 + (-1) = B0 -> PASS
validate full:     B2 + (-1) = B1 -> FAIL
```

Expected: **SAT witness**.

This captures the documented hledger warning that close-generated assertions may depend on the same status/real/auto/date context used to generate them.

### 6. Final balance does not determine assertion outcome

Hold final balance equal at `B1`, but evaluate a prefix assertion under hledger-like date ordering versus Ledger-like parse ordering.

Expected: **SAT witness** with different assertion result.

So final account balance is too compressed for prefix-sensitive assertion validation.

## Conservative candidate

The positive candidate is:

```text
selected balances from prior LOAM views
+ generation mode
+ assignment target
+ generation/validation context
+ parse/date ordering evidence
+ explicit order policy
+ explicit admission decision
    -> generated delta
     + balancing delta
     + retained-generated view
     + prefix assertion result
     + generated-close assertion result
```

If fixing those inputs fixes the selected outputs, the pressure remains additive/compositional rather than C-level Core-shape failure.

## Expected Alloy matrix

```text
representativeClosePreview                       SAT
sameGeneratedDifferentMode                       SAT
assignmentOrderingChangesGeneratedAmount         SAT
sameGeneratorDifferentAdmission                  SAT
closeValidationContextChangesAssertion           SAT
sameFinalBalanceDifferentPrefixAssertion          SAT

GeneratedOutputDeterminesMode                    SAT counterexample
GenerationDeterminesRetention                    SAT counterexample
FinalBalanceDeterminesAssertionOutcome            SAT counterexample
ExplicitGenerationInputsDetermineOutput          UNSAT counterexample
ExplicitOrderingInputsDeterminePrefixAssertion   UNSAT counterexample
ExplicitCloseContextsDetermineGeneratedAssertion UNSAT counterexample
ExplicitInputsDetermineSelectedOutputs            UNSAT counterexample
```

## Interpretation gate

```text
generation/provenance/order/context distinctions observable
    -> missing Ledger information is real

explicit additive inputs determine selected outputs
    -> B / conservative additive composition

only if those inputs still cannot represent a legitimate selected answer
because retained Event/Effect itself has the wrong shape
    -> C / Core-shape pressure
```

## Production boundary

Even if the expected matrix succeeds, this does **not** earn:

- a production Close/Open/Retain mode enum;
- a production BalanceAssignment fact;
- generated Event persistence;
- automatic admission of generated postings;
- a universal selection-context object;
- a universal parse-order coordinate;
- Ledger or hledger assertion compatibility;
- complete close account/date/tag/rounding behavior;
- costs or lots in close output;
- a production retained-earnings rule;
- mutation of existing Event/Effect history.

The selected question is only whether the mature Ledger generation/finality behavior forces a larger neutral physical Core.

## Next Ledger gate

If this survives, the remaining large semantic cluster is valuation:

```text
temporal price/rate applicability
+ cost annotations
+ lot identity/selection
+ realised/unrealised gains
```

That cluster should be attacked separately because hledger 1.x itself has limited automated lots/gains semantics while Ledger has richer behavior.
