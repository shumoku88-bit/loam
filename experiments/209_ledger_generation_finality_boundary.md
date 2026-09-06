# Observation 209 — Ledger generation / assignment / assertion-order boundary

Status: **Ledger/hledger reconstruction gate; qualified bounded additive composition**

## Question

Observation 208 qualified chart hierarchy, role inheritance/override, posting status/date, and report-vs-assertion selection without enlarging neutral Event/Effect. Observation 209 asks the next mature-ledger question:

```text
close / open / retain generation
+ balance assignment
+ generated assertions
+ generation / validation selection context
+ assertion evaluation order
+ generated-vs-retained provenance
```

Can those selected behaviors be reconstructed from already-derived balances plus explicit generation/order/admission policy, or does Event/Effect need a different semantic shape?

## External pressure

hledger 1.52 documents that balance assignments infer the missing posting amount required to reach a target balance; `close` supports close/open/clopen/assert/assign/retain modes; generated close/open output includes assertions; close-generated assertions can depend on status, realness, auto-posting, dates, costs, and related selection context; and assertions are checked in date order with parse order as a same-date tie-breaker.

Ledger 3 likewise supports balance assignments, but checks assertions in parse order rather than hledger's date-first order.

References:

- https://hledger.org/1.52/hledger.html
- https://ledger-cli.org/doc/ledger3.html

## Composition boundary

Observation 207 already qualified separate accounting-only/generated contribution planes, query policy, assertions, and correction-aware horizons. Observation 208 qualified the chart/status/posting-date selection seam.

Observation 209 therefore treats two selected balances as an interface from those earlier results:

```text
fullBalance
filteredBalance
```

The model begins after balance selection and asks what generation and prefix-sensitive validation still require.

## Observation-local model

The bounded arithmetic has only:

```text
Balance = B0 | B1 | B2
Delta   = -2 | -1 | 0 | +1 | +2
```

with an explicit partial addition/difference relation.

Observation-local generation modes are:

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

Movement-producing modes also derive the opposite balancing delta.

Two abstract selection contexts stand in for prior qualified selection policy:

```text
FullContext
FilteredContext
```

Generation and validation may deliberately use different contexts.

`admitted = No | Yes` keeps generated output separate from retained history. This is observation-local provenance, not a production writer model.

For assertion ordering the model compares:

```text
ParseOnly
DateThenParse
```

A prior posting can therefore be visible in the assertion prefix under Ledger-like parse order while excluded under hledger-like date-first order. The final balance can remain identical.

## C-seeking witnesses

### Generated close without retained history

A filtered balance `B1` generates:

```text
selected account  -1
counter account   +1
```

while `admitted = No`.

Observed: **SAT**.

So generated output is not automatically retained Event history.

### Same generated postings, different generation meaning

A close from `B1` and an assignment from prefix `B2` to target `B1` can both generate `-1/+1`.

Observed: **SAT**.

Generated posting values alone do not determine whether the semantics were close or assignment.

### Assignment amount depends on prefix/order

With target `B2` and the same prior `+1` posting:

```text
ParseOnly     -> prior posting visible -> prefix B1 -> assignment +1
DateThenParse -> later-dated posting excluded -> prefix B0 -> assignment +2
```

Observed: **SAT**.

Target balance alone therefore does not determine a balance-assignment posting.

### Generation does not determine retention

The generator inputs can be identical while only admission differs.

Observed: **SAT**.

So generated candidate/output and retained historical fact remain distinct.

### Close assertion depends on matching selection context

Generate close from filtered `B1` while full balance is `B2`:

```text
filtered validation: B1 + (-1) = B0 -> PASS
full validation:     B2 + (-1) = B1 -> FAIL
```

Observed: **SAT**.

The generated assertion therefore depends on the same selected context used to derive the close amount.

### Final balance does not determine prefix assertion result

The model keeps the final balance equal at `B1` but switches only the order policy. The assertion can pass under date-first prefix ordering and fail under parse-only ordering.

Observed: **SAT**.

Final balance is too compressed for prefix-sensitive assertion validation.

## Observed Alloy matrix

Alloy 6.2.0 + Sat4j on exact PR head `648344a73cc7131d173fa4e0fd4835ac53d85088` produced exactly the selected matrix:

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

Dedicated workflow run `34015248485`, job `101437772269`, completed **SUCCESS**.

## Interpretation

Three tempting compressions fail:

```text
generated posting values  -/-> generation meaning
selected target/final balance -/-> prefix-sensitive result
generated output          -/-> retained history
```

But the conservative candidate survives:

```text
selected balances from prior LOAM views
+ generation mode
+ assignment target
+ generation / validation context
+ parse/date ordering evidence
+ explicit order policy
+ explicit admission decision
    -> generated delta
     + balancing delta
     + retained-generated view
     + prefix assertion result
     + generated-close assertion result
```

Fixing those explicit inputs fixed all selected outputs in the bounded model.

Classification:

```text
B / CONSERVATIVE ADDITIVE COMPOSITION
C / CORE-SHAPE PRESSURE NOT DEMONSTRATED
```

The result does not say generation meaning, order, or admission are UI trivia. They are independently observable information. It says the selected Ledger/hledger behavior can be reconstructed above existing Event/Effect rather than by changing the neutral physical occurrence shape.

## Production boundary

This observation does **not** earn:

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

## Next Ledger gate

The remaining large semantic cluster is valuation:

```text
temporal price/rate applicability
+ posting-attached cost
+ valuation policy
+ lot identity / selection
+ realised / unrealised gains
```

That cluster should be split carefully because hledger 1.x preserves cost/lot annotations and performs valuation reporting but does not implement the same automated lot/gain machinery as Ledger 3.
