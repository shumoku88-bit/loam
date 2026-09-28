# Public fixture privacy policy

LOAM is public; household authority is not.

Public source, tests, examples, observations, and research notes must not copy
facts from a private household snapshot merely because those facts were useful
during dogfood qualification.

## Public material may contain

- fully synthetic fixtures chosen to exercise semantics;
- generic vocabulary such as assets, liabilities, food, rent, or a wallet when
  the example is not copied from one household;
- structural conclusions learned from private dogfood after the underlying
  household values have been removed;
- public program revisions and public CI results.

## Public material must not retain

- exact private household balances, income amounts, debt amounts, or transaction
  descriptions;
- family, friend, or counterparty labels copied from household authority;
- a private household repository commit SHA tied to a concrete observation;
- a bundle of account names, dates, and amounts that reconstructs a private
  checkpoint;
- "golden" public tests whose expected values are copied from live household
  data.

Real-household qualification belongs in the private household repository. A
public test that needs the same semantic shape must rebuild it from synthetic
evidence.

## Development rule

When a private observation exposes a bug or earns a design decision:

1. minimize the semantic shape;
2. construct an independent synthetic witness;
3. add the synthetic witness to public tests;
4. keep the private regression in the private qualification boundary when it is
   still operationally useful;
5. publish only the sanitized conclusion.

Do not paste private data into an issue, PR body, test failure, benchmark
artifact, screenshot, or research note as a shortcut.

## History

Sanitizing the current tree does not erase older Git commits. Rewriting public
history is a separate destructive operation and requires an explicit decision;
it must not be folded into an ordinary cleanup PR.
