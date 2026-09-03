# Observation 144 — Exact conversion and retained residual

Status: **qualified experiment**

## Question

Observations 142 and 143 qualified two semantic boundaries around Measure-to-Measure relation observations:

```text
which relation applies can depend on time coordinate
same coordinate can retain several source-distinguished candidates
scalar selection may require independent authority
```

Those observations deliberately treated relation values symbolically. They did not ask how an exact selected relation should act on indivisible quantities.

Observation 144 asks the smallest arithmetic question:

> If an exact rational relation is applied to indivisible source quanta, can the visible whole target quantity be safely treated as compositional under splitting, or must conversion preserve the division residual explicitly to avoid information loss?

This is not an FX-specific model. `numerator / denominator` is only experiment-local neutral relation arithmetic over nonnegative quanta.

## Minimal arithmetic

For source quantity `q` and selected exact relation `n / d`:

```text
scaled = q * n
whole  = scaled / d
residual = scaled % d
```

Lean proves the exact decomposition:

```text
d * whole + residual = q * n
```

For positive `d`, the residual is also bounded:

```text
residual < d
```

So integer conversion need not destroy exactness merely because the visible target quantity is integral.

## Split pressure

The important question is whether the whole target quantity alone is additive:

```text
whole(left + right)
    ?=
whole(left) + whole(right)
```

A concrete `1 / 3` specimen rejects that assumption:

```text
aggregate
  source 3
  whole = 1
  residual = 0

split 1 + 2
  whole(1) + whole(2) = 0
  residual(1) + residual(2) = 3
```

Therefore truncating each split independently loses one visible target quantum compared with aggregate conversion.

But the exact scaled representation remains equal:

```text
3 * 0 + 3
    =
3 * 1 + 0
```

The missing visible quantum is carried by the accumulated residual.

## General Lean theorem

Observation 144 proves for arbitrary natural `left`, `right`, `numerator`, and `denominator`:

```text
denominator * (whole left + whole right)
  + (residual left + residual right)
=
denominator * whole (left + right)
  + residual (left + right)
```

So splitting does not break exact conversion if the residual information is retained.

The theorem intentionally does **not** normalize the sum of split residuals. In the concrete specimen the split residual sum equals the denominator itself. That is exactly the next policy boundary: if callers demand only whole target quanta, some carry / placement / rounding choice must decide where that accumulated residual becomes visible.

## Qualified result

Lean 4.33.1 accepts the complete probe:

```text
exact_conversion
residual_lt_denominator
split_preserves_exact_scaled_quantity
```

and all closed `1 / 3` pressure examples, including the explicit inequality between aggregate and independently truncated split whole quantities.

The qualified boundary is:

```text
selected exact Measure relation
+ source quantity
    -> whole target quanta
    + retained residual

whole target quanta alone
    !=
compositional exact conversion

whole target quanta + residual
    -> exact scaled conservation under splitting
```

So exactness does not require a floating-point or currency-specific primitive. It requires that integer projection not silently erase the residual information that distinguishes aggregate from independently split conversion.

## Relationship to existing Allocation core

`Loam.Core.Allocation` already uses quotient + remainder to preserve indivisible quantity exactly when dividing one total across recipients. Observation 144 finds the same mathematical pressure in a relation-conversion setting without promoting new production types.

The conceptual resemblance is useful:

```text
allocation remainder
conversion residual
```

may share mathematics while still answering different domain questions.

Observation 144 therefore does not modify `Loam.Core.Allocation` and does not claim the two concepts should share one production abstraction.

## What is deliberately not modeled

Observation 144 does not decide:

- signed source quantities;
- negative rates;
- decimal display representation;
- round-half-up, bankers rounding, floor, ceiling, or nearest rounding;
- which split receives a carried target quantum;
- residual normalization across more than two pieces;
- residual persistence;
- whether residual belongs to an Event, relation observation, query, or derived receipt;
- accounting-role classification of realised/unrealised gain or loss;
- rate source or scalar-selection authority;
- time-coordinate selection;
- conversion through several Measure relations;
- inverse relation laws.

Those are separate semantic or arithmetic questions.

## Not earned by this observation

Observation 144 does not establish canonical:

- `ExchangeRate`;
- `Money` or `Currency` arithmetic;
- `RoundingPolicy`;
- `Residual` persistent fact;
- `FXGainLoss`;
- conversion receipt;
- Practical Core changes.

The experiment-local `whole` and `residual` functions are mathematical probes only.

## Qualification

- initial executable head `f3cde1ebac0e2554efd71da84f2be7ffdd52d25a` — Observation 144 SUCCESS
- initial run `33779465131`, job `100729286187` — Lean proof check SUCCESS

## Tool choice

**Lean.**

The question is an arithmetic law over all natural quantities in the model:

```text
exact decomposition
bounded remainder
split conservation
```

Alloy would only sample bounded integers. Lean establishes the conservation statement generally.

A later observation may use Lean again if a specific rounding / carry rule is actually demanded. Alloy or TLA+ would become relevant only if residual ownership, authority, or temporal publication becomes the question.
