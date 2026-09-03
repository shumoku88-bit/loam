# Observation 115: Does a classified destination preserve what a scheduled payment is for?

## Question

Household dogfood exposed a concrete pressure around scheduled payments.

A source system may retain both:

```text
human subject: one specific service / obligation
classification: a broader expense category
```

LOAM should not inherit that split merely because another household model has it. The narrower question is:

> If canonical Scheduled evidence keeps only the broad classified destination, can it still determine what the obligation is for?

The alternative under test is to let the specific subject itself be the positive Locus of the balanced Scheduled movement:

```text
wallet -> network-service
wallet -> mobile-service
```

rather than collapsing both into a broader destination such as:

```text
wallet -> communications
```

The names in this observation are synthetic. No private household source values are copied into the public repository.

## Model shape

The bounded model fixes everything that should not answer the question:

- one opaque Scheduled identity;
- one day;
- one amount;
- one source Locus;
- one broad classified Locus;
- two distinct service subjects.

Each `World` carries the real obligation subject plus two possible canonical encodings:

```text
ClassifiedRecord
  same opaque identity
  same day
  same source
  same amount
  destination = broad classification

DirectRecord
  same opaque identity
  same day
  same source
  same amount
  destination = specific subject Locus
```

Scheduled identity is deliberately opaque. The model never decodes a token such as `scheduled-network-service` to recover semantic meaning.

## Expected distinction

Two worlds can describe different obligations while having identical classified canonical records:

```text
subject = network-service
subject = mobile-service

classified destination in both worlds = communications
```

Therefore the classified representation should admit a counterexample to:

```text
same canonical record
  implies
same obligation subject
```

The direct-Locus representation should not admit that counterexample because the destination coordinate itself retains the subject distinction.

## Commands

Expected Alloy 6.2.0 / Sat4j results:

```text
classifiedCollapsesDistinctSubjects      SAT
directKeepsDistinctSubjects              SAT
ClassifiedCanonicalDeterminesSubject      SAT counterexample
DirectCanonicalDeterminesSubject          UNSAT counterexample
```

## Interpretation boundary

If the expected results hold, they establish only an information boundary:

```text
broad classification alone
  does not determine
what the scheduled obligation is for
```

and, for this bounded question:

```text
specific subject as Locus
  retains that distinction
```

The observation does **not** establish:

- that every human description is a Locus;
- that Locus tokens are display labels;
- an Account / ExpenseCategory ontology;
- merchant, vendor, ownership, custody, or debit/credit semantics;
- that classification is useless;
- that classification must be canonical rather than a later routing/projection fact;
- recurrence or Series semantics;
- Envelope routing or budget policy.

Classification may still be useful downstream. The point is that it should not replace the more specific subject if household questions need that subject later.

## Practical pressure

The current Practical Scheduled entrance already stores arbitrary neutral Locus changes. No Core extension is required to exercise this representation.

The companion qualification therefore records two synthetic obligations with the same day, source, and amount but different destination Loci. This checks that the existing Scheduled persistence retains the distinction without introducing Account classification.

## Next pressure

If this survives qualification, the next real-data question is not whether to add categories back immediately. It is:

> With `ScheduledId + scheduled coordinate + balanced movement whose destination is the obligation subject`, what household payment-management question still cannot be answered?

That question should earn the next canonical distinction, if any.
