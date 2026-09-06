# LOAM interaction prototype 01

Status: **synthetic interaction experiment only**

This prototype moves the Interaction Atlas from E1 paper traces toward the smallest possible E2 human dogfood evidence.

It is deliberately **not** a production TUI.

## Safety boundary

`InteractionShellMain.lean`:

- does not read canonical household data;
- does not write any file;
- does not call LOAM publishers;
- does not add accounting semantics;
- uses only synthetic rows and mock publication results;
- keeps `SYNTHETIC / NO WRITES` visible on every surface.

The point is to test navigation and discoverability before paying for a TUI framework or connecting real publication.

## Run

From the repository root:

```sh
lake env lean --run Loam/Prototype/InteractionShellMain.lean
```

Input is intentionally simple: type a command and press Enter.

Choose either:

1. `HRA-derived flat`
2. `flat + palette hybrid`

Press `m` at any point to switch candidates. Structural counters are kept separately for each candidate.

## Shared controls

```text
h / l   move selected day
j / k   select visible Actual/Scheduled row
Enter   open selected row
r       Record what happened
?       contextual help
m       switch candidate
z       counters
q       quit and show comparison questions
```

HRA-derived flat adds direct Home entries:

```text
a       Actual
s       Scheduled
```

Hybrid instead exposes:

```text
/       More actions / intent search
```

The palette accepts a deliberately tiny human-language vocabulary including:

```text
record
purchase
correct
fix
wrong amount
scheduled
rent
reschedule
change scheduled
```

## Dogfood pass A — ordinary use

For each candidate:

1. move to another day with `h` or `l`;
2. use `r` to start an Actual draft;
3. verify whether the selected date is obvious before mock publication;
4. press Enter to simulate publication;
5. select the Scheduled row with `j/k`, open it with Enter, then try realization and replacement;
6. notice whether returning Home preserves enough orientation.

Do not judge only command count. Record hesitation and wrong-date risk.

## Dogfood pass B — rare Correction cold start

Pretend you have not used Correction for a week.

### HRA-flat

Start from Home and try to rediscover Correction without reading this file.

### Hybrid

Start from Home, open `/ More actions`, and search with whatever human wording comes naturally, for example `wrong amount`.

Observe:

- whether the rare action is discoverable;
- whether you needed `?` help;
- whether you entered an unknown command;
- whether the path felt like remembering software vocabulary or stating intent.

## Dogfood pass C — useful friction

Open a correction, Scheduled realization, or replacement mock draft.

Ask:

- does the preview explain enough to trust the next action?
- is anything shown that feels like useless ceremony?
- would removing a step make the meaning less clear?

The prototype intentionally keeps mock draft/publication boundaries visible even when that costs an extra Enter.

## Counters

`z` shows per-candidate structural counters:

- commands;
- palette opens;
- help opens;
- unknown commands;
- day moves;
- surface changes.

They are observations, **not usability scores**.

## Human evidence to report

After quitting, answer these five questions from the prototype:

1. Where did you hesitate?
2. Which path could you rediscover after pretending you forgot it?
3. Was the selected date obvious before mock publication?
4. Did any extra step feel protective rather than annoying?
5. Which candidate would you willingly use again tomorrow?

Those answers matter more than a tiny difference in action count.

## Explicit non-goals

Do not add in prototype 01:

- persistent drafts;
- canonical household loading;
- WriterOwnership or publisher calls;
- mouse support;
- raw terminal mode;
- a widget framework;
- charts/reports;
- settings/personalization;
- a universal action framework;
- new retained household concepts.

If this tiny shell exposes a real navigation/discoverability advantage, the next experiment can connect only the relevant path to existing LOAM application/publication machinery.
