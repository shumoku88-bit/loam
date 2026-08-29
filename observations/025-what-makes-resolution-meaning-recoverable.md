# Observation 025: What Makes Resolution Meaning Recoverable?

## Question

Observation 024 showed that the correction frontier can determine what a Resolution receives without determining what meaning that Resolution carries.

What additional information is sufficient to make the Resolution meaning recoverable?

This observation asks a smaller question than "what justifies a Resolution?" It first separates two cases:

1. selecting a meaning that is already present in the parents, and
2. allowing a meaning that is not present in either parent.

## Why Alloy only

The question is about possible worlds and whether fixed inputs can still admit different Resolution meanings.

- No quantitative projection is involved, so J is not needed.
- No temporal ordering or liveness property is central, so TLA+ is not needed.
- No inverse synthesis search is needed yet, so miniKanren is not needed.
- No general law has yet earned preservation as a theorem, so Lean is not needed.

Alloy is the smallest useful tool.

## Model

The correction structure is held fixed:

```text
KA -> C0
KB -> C0
R0 -> {KA, KB}
```

The prior meanings are also fixed in every world:

```text
C0 = M0
KA = MA
KB = MB
```

Observation 025 adds only a `Rule` and, when needed, one neutral semantic input called `offered`.

The rules are deliberately content-neutral:

```text
TakeKA       -> R0 means what KA means
TakeKB       -> R0 means what KB means
TakeOffered  -> R0 means the separately offered meaning
```

`TakeOffered` requires its offered meaning to differ from both parent meanings. This makes the distinction between selection and genuinely fresh semantic content explicit.

No Evidence, Authority, Decision, support relation, or general merge framework is introduced.

## Executed result

Alloy 6.2.0 with Sat4j, exact scope:

- 4 Interpretation atoms
- 5 Meaning atoms
- 3 Rule atoms
- 2 World atoms

```text
sameRuleDifferentMeaning                         SAT
sameInheritedRuleDifferentMeaning                UNSAT
sameOfferedRuleDifferentInputDifferentMeaning    SAT
sameRuleAndInputDifferentMeaning                 UNSAT

RuleAloneDeterminesResolutionMeaning              SAT
InheritedRuleDeterminesResolutionMeaning          UNSAT
RuleAndInputDetermineResolutionMeaning            UNSAT
FreshMeaningRequiresOfferedInput                  UNSAT
WholeFrontierResolutionStillSettles               UNSAT
```

For checked assertions, `SAT` means Alloy found a counterexample.

## Reading the witnesses

### A rule alone is not sufficient in general

`sameRuleDifferentMeaning` is SAT.

Both worlds can use `TakeOffered` while supplying different offered meanings. The rule is identical but the Resolution meanings differ.

Correspondingly, `RuleAloneDeterminesResolutionMeaning` has a counterexample.

So the word "rule" does not by itself explain where semantic content comes from.

### Selection of existing meaning is recoverable

`sameInheritedRuleDifferentMeaning` is UNSAT, and `InheritedRuleDeterminesResolutionMeaning` has no counterexample.

When the rule is `TakeKA` or `TakeKB`, the prior parent meanings plus the rule determine the Resolution meaning.

```text
existing parent meanings + selection rule
                  |
                  v
          Resolution meaning
```

Nothing semantically new has to enter the world. The rule only selects information already present.

### Fresh meaning requires fresh semantic input

`sameOfferedRuleDifferentInputDifferentMeaning` is SAT.

Two worlds can have the same fixed conflict structure and the same `TakeOffered` rule, yet differ because the offered semantic input differs.

But `sameRuleAndInputDifferentMeaning` is UNSAT, and `RuleAndInputDetermineResolutionMeaning` has no counterexample.

Within this model:

```text
existing parent meanings + rule + offered meaning
                         |
                         v
                 Resolution meaning
```

is sufficient to recover the result.

`FreshMeaningRequiresOfferedInput` also has no counterexample: any Resolution meaning that differs from both parent meanings must be carried by the offered input.

## Finding

> A rule can select semantic content that already exists, but it cannot create fresh semantic content without receiving that content somewhere.

More compactly:

```text
selection:
(parent meanings, rule) -> result

fresh synthesis:
(parent meanings, rule, new semantic input) -> result
```

This sharpens Observation 024. The missing information is not always another object or another provenance stream. If the result merely inherits an existing meaning, a selection rule can be sufficient. If the result may be genuinely new, semantic information must enter somewhere beyond the parent meanings and the content-neutral rule.

## What this does not establish

The neutral name `offered` is intentional.

This observation does **not** establish that an offered meaning is justified, trustworthy, authorized, evidenced, or acceptable. It only identifies information sufficient to reconstruct the chosen Resolution meaning in this bounded vocabulary.

A rule that directly embeds a particular new meaning, such as "always choose MX", would not eliminate the semantic input. It would merely hide that input inside the rule itself.

The experiment is bounded and does not prove a universal theorem about conflict resolution.

## Structural continuity

`WholeFrontierResolutionStillSettles` remains UNSAT.

The semantic distinction introduced here does not disturb Observation 023's structural result: the full-frontier Resolution still leaves `R0` as the unique frontier tip.

## Next question

Recoverability is now separated from justification.

The next useful question is therefore not yet "who has authority?" but something smaller:

> If two worlds have the same conflict structure, the same rule, and the same offered meaning, can they still differ in whether that offered meaning should be accepted?

If such a distinction is future-visible, some further provenance may finally earn existence. If not, adding it would be premature.
