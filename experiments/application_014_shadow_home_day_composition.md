# Application 014: Compose one household day from independent projections

## Question

Can LOAM show one selected household day with both recorded Actual activity and scheduled activity without introducing a shared Home model, Day aggregate, Plan type, Account type, or new persistence?

## Pressure

Private dogfood showed two independently useful read-only projections over the same selected day:

- Application 012 answers what was recorded on the selected day;
- Application 013 answers what was scheduled for the selected day using evidence visible through a known-through horizon.

The practical UI pressure is to see both answers in one terminal interaction, as in an ordinary household home/day view.

The danger is to respond by creating a new canonical `HouseholdHome`, `Day`, or shared report ontology merely because the two answers are displayed together.

## Smallest composition tried

Application 014 adds only a terminal-side composition tool:

```text
selected day ───────┬──> qualified recorded-day reader
                    │
known-through ──────┴──> qualified scheduled-day reader
                              │
                              v
                     one terminal presentation
```

The two readers remain independently qualified and retain their own source-admission rules. The compositor does not parse journal source itself and does not combine their evidence into a new domain object.

The first presentation deliberately preserves each child reader's own provenance banner rather than introducing a shared rendering framework solely to remove repeated text.

## What was not added

No new:

- LOAM Core type;
- canonical Day or Home fact;
- Plan or Account ontology;
- parser framework;
- shared Event identity between readers;
- persistence or mirror data;
- correction relation;
- temporal ordering law;
- source write path.

## Failure behavior

Composition is sequential and fail-closed. If the recorded-day reader refuses its source evidence, the scheduled section is not presented. The compositor does not reinterpret or downgrade a child reader's refusal.

## Result to observe

A useful household screen may be a composition of independent questions rather than evidence that those questions belong to one larger domain model.

The next pressure should come from dogfood. If repeated banners or separate parsing become a real usability or maintenance cost, that pressure can justify a smaller shared presentation or source boundary later. It is not earned merely by co-location on one screen.

## Practical Core impact

None.
