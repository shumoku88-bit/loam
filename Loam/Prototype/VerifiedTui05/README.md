# Prototype 05: Recent Actual review pressure test

Status: synthetic UI experiment. No canonical reads. No writes.

This is the second semantic pressure test for the small Lean-owned TUI kernel
introduced by Prototype 04.

Prototype 04 was a spatial month calendar. Prototype 05 deliberately uses a
different shape: a vertical Recent Actual list with a selected-record detail
view.

The household interaction pressure comes from Application 015 and the existing
`Loam/Cli/ReviewCli.lean` review entrance:

- recent records should be easy to scan;
- a remembered record should be easy to find and inspect;
- selection is transient presentation state, never writer authority;
- detail is read-only;
- occurrence date is not entry time.

## What this experiment reuses

Prototype 05 reuses the Prototype 04 semantic widget/screen kernel and, for the
first time, the sparse compiled-row runtime is extracted from the calendar CLI
into `VerifiedTui04/Runtime.lean` because two differently-shaped screens now need
it.

The shared runtime retains the law that a dirty-row patch reconstructs the same
new screen as a complete semantic render.

## What this experiment does not generalize

There is intentionally no generic ListWidget, scrolling framework, search box,
pagination abstraction, form system, mouse layer, or canonical review loader.

The list is five synthetic rows. Up/Down selects, Enter opens detail, `b` returns,
and `q` quits. Selection is represented by `Fin 5`, and Lean checks that opening
and returning preserve it.

If a longer real review surface later creates genuine scrolling pressure, that
can earn another abstraction then.

## Run

From the repository root:

```sh
lake build loamUiPrototype05
./.lake/build/bin/loamUiPrototype05
```

Human questions:

1. Does Up/Down selection feel as immediate as Prototype 04?
2. Is the selected row easy to track visually?
3. Does Enter/detail/Back preserve orientation naturally?
4. Does the extracted sparse runtime feel natural for both calendar and list,
   without either screen needing special-case damage hints?
