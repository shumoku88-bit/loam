# Observation 249 — Real CurrentCoverage dogfood with Actual classification frontier

Status: **ACTIVE PROBE — real-data dogfood only; production semantics unchanged**

Baseline:

```text
Observation 248 head
102aaf6501327b260156e815380123003d6ffec1
```

Pinned household data:

```text
shumoku88-bit/loam-data
9aca13c98dd8a479b3817478d603976b9aa32ac4
```

## Question

Observations 247 and 248 established that:

```text
selected managed CurrentCoverage value
!=
Actual classification closure
```

and that the open Actual part can be reconstructed as a pure derived Event-valid unrouted Expense frontier.

The remaining practical question is:

> Does that frontier expose enough real household pressure beside CurrentCoverage to justify graduating one small production projection?

## Dogfood window

The current Pension boundary preset is:

```text
2026-08-14 <= current window < 2026-10-15
```

Observation 249 fixes the explicit current observation coordinate at:

```text
2026-09-13
```

so the Actual elapsed window is the closed interval from 2026-08-14 through 2026-09-13, matching `CurrentCoverageReview` current semantics.

## Expected real frontier

The pinned canonical data has four Expense Loci whose retained route begins on 2026-09-12 but whose current-window Actual contains earlier occurrences:

```text
2026-08-15  rent        64000 jpy
2026-08-15  utilities   20854 jpy
2026-09-05  shipping      720 jpy
2026-09-06  snacks        354 jpy
```

Expected signed aggregate frontier quantity:

```text
85928 jpy
```

The experiment does not assign those occurrences to the later Purpose routes. It only surfaces that their Purpose classification was still open at each Event's own valid coordinate.

## Execution

The dedicated workflow checks out the pinned `loam-data` commit separately, loads the ordinary production `CurrentCoverageReview` snapshot for 2026-09-13, derives the Observation 248 frontier from the same canonical Actual/routing/role evidence, and prints both surfaces side by side.

No production source, canonical household data, Review type, TUI surface, authority, or persistence is changed.

## Graduation gate

A production projection is earned only if the real output demonstrates useful information that the current numeric rows do not already communicate, while remaining cheaply derivable from the same evidence path.

If the four rows are merely historical cleanup noise, stop here and fix data deliberately instead. If they materially change how a user should read CurrentCoverage, a small derived frontier may be justified.
