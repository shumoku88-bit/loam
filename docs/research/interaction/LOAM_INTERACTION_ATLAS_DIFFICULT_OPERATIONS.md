# LOAM Interaction Atlas — Difficult Operations Catalog

Date: 2026-09-06  
Status: **catalogue-first interaction research; not a UI specification**  
Parent: `LOAM_INTERACTION_ATLAS.md`

---

## 0. Purpose

This shard catalogs household-finance interactions that routinely become confusing, overloaded, or error-prone in existing software.

The point is not to import product features into LOAM. For each difficult operation, the research asks:

1. what happened in the real world,
2. what the human is trying to accomplish,
3. how existing products expose the operation,
4. what semantic distinctions the product UI may collapse,
5. what LOAM would need to distinguish before selecting a flow,
6. what error prevention / recovery / provenance the surface should expose.

A row in this catalog does **not** imply a new retained LOAM concept.

Working rule:

> A convenient UI verb may map to several explicit semantic facts, but it must not invent or erase those distinctions.

---

# 1. Cross-cutting semantic dimensions

Difficult household operations often mix several dimensions that should be observed independently before a UI is selected.

| Dimension | Question |
|---|---|
| Physical movement | What quantity actually moved from where to where? |
| Economic burden | Who ultimately bore the cost or received the benefit? |
| Event identity | Which observations refer to the same real-world event? |
| External evidence | What did a bank/card/wallet/import source actually observe? |
| Lifecycle | Is this initiated, pending, settled, refunded, cancelled, replaced, or completed evidence? |
| Purpose / routing | What household purpose does the event contribute to? |
| Capacity / allocation | What resources were reserved, available, or reassigned? |
| Projection policy | Which facts belong in a particular report or decision view? |
| Correction | Did reality change, or was an earlier record wrong? |
| Provenance | Why does the system believe the current state? |

The UI should resist turning all of these into one generic `type`, `category`, `transfer`, `exclude`, or `undo` flag.

---

# 2. Difficult Operation Catalog

Research states:

- **OBSERVED** — existing-product behavior has been inspected enough to state the pattern.
- **COMPARE** — multiple products show meaningfully different treatments.
- **LOAM-MAP** — candidate LOAM distinctions are clear enough for later mapping.
- **TODO** — more evidence needed.

## A. Internal movement, wallets, and transfer-like events

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-MOV-001 | Move money from bank A to bank B | Most apps expose a special Transfer action so reports do not count income/expense | Can the UI say “move money” while retaining an ordinary balanced movement plus explicit account identities? | COMPARE |
| DO-MOV-002 | Withdraw cash from bank to wallet | Apps usually model as transfer between tracked accounts | Is “cash withdrawal” merely a recognizable interaction preset over the same movement shape? | LOAM-MAP |
| DO-MOV-003 | Deposit wallet cash into bank | Reverse of withdrawal, but often entered separately on each side when imports are involved | Can one human action generate/relate the evidence without hiding external observations? | COMPARE |
| DO-MOV-004 | Charge PayPay/e-money from a bank | Japanese apps frequently classify this as Transfer to avoid treating charge as spending | Does wallet charging remain physical movement even when the wallet is not modelled as ordinary money? | LOAM-MAP |
| DO-MOV-005 | Bank and wallet observe the same charge independently | Import systems must prevent two observations becoming two economic movements | What relation says “these observations witness one movement” without deleting one source? | LOAM-MAP |
| DO-MOV-006 | Transfer settles on different dates in source and destination accounts | Actual permits different dates on the two linked sides | Does LOAM need separate observation dates while retaining one physical-movement identity? | COMPARE |
| DO-MOV-007 | Transfer has a fee | Transfer amount and fee have different household meaning | Can UI collect one real-world operation but preview two effects: movement + expense? | LOAM-MAP |
| DO-MOV-008 | Transfer is interrupted / pending | A source debit may exist before destination credit | Do not force immediate conservation across separately observed external evidence if settlement is not yet established | LOAM-MAP |
| DO-MOV-009 | User picked wrong destination account | Existing apps often edit the linked transfer in place | Should LOAM offer “correct destination” as a history-preserving correction, not destructive edit? | LOAM-MAP |
| DO-MOV-010 | Two same-amount transfers occur close together | Heuristic auto-match can pair the wrong observations | Matching must expose ambiguity and fail closed when identity is not earned | OBSERVED |

### Product evidence

**Actual Budget** links two transaction rows as one transfer. Updating amount/payee/notes propagates across the linked halves, while cleared/reconciled state remains account-specific. Dates may remain different because transfers can take days to settle. Two already-imported transactions can be converted to a transfer only when amounts are exactly inverse and accounts differ.

Source: https://actualbudget.org/docs/transactions/transfers/

**Money Forward ME** explicitly uses `振替` for bank/wallet movement and e-money charging, and excludes transfer rows from household income/expense calculation. It also uses transfer classification to prevent double-counting across connected sources.

Sources:
- https://support.me.moneyforward.com/hc/ja/articles/900003465946
- https://support.me.moneyforward.com/hc/ja/articles/4409270669209

**Zaim** defines Transfer as balance-only movement that is neither income nor expense, including bank → wallet and bank → credit-card payment. Connected points/securities accounts cannot participate in this transfer mechanism.

Sources:
- https://content.zaim.net/manuals/show/20
- https://content.zaim.net/manuals/show/55

### Early interaction hypothesis

Human-facing action:

```text
Move money
  from: SMBC
  to:   PayPay
  amount: 3000 JPY
```

Possible advanced review:

```text
This records a movement between two owned loci.
It does not create household spending or income.

External observations linked: none
Fee: none

[Record]
```

This is only a presentation hypothesis. It does not establish a new LOAM `Transfer` semantic primitive.

---

## B. Credit-card purchase and settlement

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-CC-001 | Buy something with credit card | Purchase date and bank-settlement date differ | Which event carries household expense, and which later event is liability/asset settlement? | LOAM-MAP |
| DO-CC-002 | Pay card bill from bank | Apps usually treat payment as transfer, not new expense | Can UI show “Pay card” while explaining that spending was already observed earlier? | LOAM-MAP |
| DO-CC-003 | Card and bank both import settlement | Duplicate-looking evidence appears on two accounts | Link evidence rather than count two payments | LOAM-MAP |
| DO-CC-004 | First imported card payment is not recognized | Product needs user to establish relationship once | Could LOAM require explicit identity/relationship instead of learning silent authority? | COMPARE |
| DO-CC-005 | Partial card payment | Liability settlement does not equal all prior purchases | Avoid coupling payment identity to individual expense rows unless evidence exists | LOAM-MAP |
| DO-CC-006 | Credit-card balance transfer | Debt moves between liabilities and may carry a fee | Separate debt movement, fee expense, and budget/capacity reassignment | COMPARE |
| DO-CC-007 | Purchase pending authorization | Available credit/cash can change before settlement | Lifecycle/reservation is not equivalent to physical settlement | LOAM-MAP |
| DO-CC-008 | Authorization released without capture | No final purchase, but temporary availability changed | UI needs truthful pending/released state without fabricating Actual spending | LOAM-MAP |
| DO-CC-009 | Refund lands on credit card | It reverses/reduces burden but is not ordinary income | UI should relate return to original purpose/event when known | COMPARE |
| DO-CC-010 | Refund exceeds current card balance | Card may temporarily carry positive balance | Account state and household income semantics must remain separate | TODO |

### Product evidence

**YNAB** models a credit-card payment as a transfer. The payment appears as outflow from the paying account and inflow to the card account, and manual-first entry can later match imported evidence. YNAB has a dedicated `Record Payment` affordance even though the underlying effect is transfer-like.

Source: https://support.ynab.com/en_us/credit-card-payments-a-guide-r1_506Q1j

YNAB’s balance-transfer workflow separately instructs users to move budget money between Credit Card Payment categories after moving the liability, showing that physical/debt movement and budget allocation are distinct operations.

Source: https://support.ynab.com/en_us/how-to-make-a-credit-card-balance-transfer-ry5ETLWJo

**Money Forward ME** normally counts the card purchase on purchase date and treats the later bank debit as transfer/excluded from household spending. Its support documentation also permits a different grouping policy for users who intentionally want spending recognized at bank-withdrawal time, demonstrating that event evidence and report policy can be separated.

Sources:
- https://support.me.moneyforward.com/hc/ja/articles/900004412703
- https://support.me.moneyforward.com/hc/ja/articles/900003466486

### LOAM interaction pressure

Avoid a surface that asks the user to decide abstractly whether a row is “expense” or “transfer”. Prefer the real-world action:

```text
What happened?

  Purchase
  Card payment
  Move money
  Refund
```

Then show the semantic preview before write.

---

## C. Points, rewards, discounts, and mixed tender

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-PTS-001 | Pay partly with PayPay balance and partly with points | Apps may show net cash payment only or gross purchase + synthetic inflow | Is point consumption a distinct commodity movement, discount, entitlement consumption, or merely external presentation? | TODO |
| DO-PTS-002 | Earn points from purchase | Some products treat points as assets; some ignore until used | Does earning establish a quantity that LOAM should ever make canonical? | TODO |
| DO-PTS-003 | Point balance expires | Asset-like dashboards may track expiry separately | If points become a commodity, expiry is lifecycle/destruction evidence, not spending | TODO |
| DO-PTS-004 | Store discount reduces price directly | No independent point balance exists | Do not manufacture an “income” event merely to make arithmetic convenient | LOAM-MAP |
| DO-PTS-005 | Imported shopping source shows gross price + “points used” as income | Reporting model leaks into transaction representation | Can LOAM preserve source evidence while deriving net household burden separately? | LOAM-MAP |
| DO-PTS-006 | Cashback is credited later | Could be rebate, refund, reward income, or card balance credit | Human intent and source evidence may be insufficient to choose one semantics automatically | TODO |
| DO-PTS-007 | Points are transferred between programs | Not all apps support transfer between point accounts | Commodity conversion/transfer requires stronger quantity semantics than ordinary JPY movement | TODO |
| DO-PTS-008 | Purchase uses points that were never tracked before | Opening stock is unknown | Fail closed on exact point balance while still allowing JPY household purchase observation | LOAM-MAP |

### Product evidence

**Money Forward ME** can link point balances and expiry dates as assets. But for some shopping integrations, point use/discount is represented as gross expense plus an `income` row for the discount so net spending comes out correctly. Its support article explicitly explains this reporting construction.

Sources:
- https://support.me.moneyforward.com/hc/ja/articles/13175406880025
- https://support.me.moneyforward.com/hc/ja/articles/4407798411161

**Zaim** supports connected point accounts but excludes them from the ordinary Transfer feature, which is a useful negative example: “shown as an account-like balance” does not automatically imply identical transfer semantics.

Source: https://content.zaim.net/manuals/show/55

### LOAM research consequence

Do **not** implement points by copying “discount = income”. First ask whether LOAM needs:

1. point quantity as an actual commodity,
2. source-only evidence of a discount,
3. household burden after discount,
4. gross purchase price for item/purpose analysis.

These may be four different questions.

---

## D. Refunds, returns, cancellations, and rebates

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-REF-001 | Full merchant refund after purchase | Common apps enter inflow back to original category | Is this a new physical movement plus relation to original burden/event? | LOAM-MAP |
| DO-REF-002 | Partial refund | Net burden changes while original purchase remains historically true | Preserve original purchase and add refund evidence | LOAM-MAP |
| DO-REF-003 | Order cancelled before settlement | Source may delete pending row rather than send explicit refund | Absence of source row is not evidence of refund/cancellation unless authority supplies it | LOAM-MAP |
| DO-REF-004 | Refund to different account/tender | Refund physical destination differs from original source | Purpose relation and physical movement must not be conflated | LOAM-MAP |
| DO-REF-005 | Store credit instead of cash refund | New entitlement/commodity may arise | Requires explicit treatment if tracked | TODO |
| DO-REF-006 | Refund crosses reporting period | “Return to category” changes period comparison behavior | Projection policy must decide period treatment explicitly | COMPARE |
| DO-REF-007 | Over-refund / goodwill credit | Amount differs from original purchase | Do not force exact inversion relation if evidence says otherwise | LOAM-MAP |
| DO-REF-008 | Chargeback/dispute | Temporary credit may later be reversed | Pending/dispute lifecycle differs from settled merchant refund | TODO |
| DO-REF-009 | Tax rebate / public refund | Looks like refund but may be semantically income/recovery | Human-facing “money back” cannot determine semantics alone | TODO |
| DO-REF-010 | User entered wrong purchase and later “refunds” it to fix ledger | Reality correction vs economic refund are different | Separate correction UX from refund UX | LOAM-MAP |

### Product evidence

**Actual Budget** recommends entering a return as an inflow to the same category used for the original purchase so category availability is restored rather than treating the return as new income.

Source: https://actualbudget.org/docs/budgeting/returns-and-reimbursements/

**YNAB** similarly recommends categorizing a credit-card refund back to the original spending category instead of Ready to Assign.

Source: https://support.ynab.com/en_us/credit-card-refunds-and-returns-H1J7qDWkj

**Money Forward ME** does not support negative expense/income rows. Its support guidance suggests either (a) expense + income, (b) exclude both and hand-enter the net burden, or (c) exclude a fully refunded pair. This is a strong example of projection policy being used to compensate for a transaction model limitation.

Source: https://support.me.moneyforward.com/hc/ja/articles/55527105255577

**Zaim** notes that when a connected provider deletes a cancelled source row rather than exposing a separate cancellation/refund item, Zaim may not be able to retrieve cancellation evidence; the user must edit/delete manually.

Source: https://content.zaim.net/questions/show/1090

---

## E. Shared costs, advances, reimbursements, and settlement

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-SHR-001 | Buy two tickets, one for self and one for friend | Single physical payment but split ultimate burden | Physical payment and burden allocation are not the same relation | LOAM-MAP |
| DO-SHR-002 | Friend reimburses later | Incoming payment should settle claim, not become salary-like income | Explicit settlement relation should be inspectable | LOAM-MAP |
| DO-SHR-003 | Partial reimbursement | Outstanding claim remains | Settlement amount and original claim amount differ | LOAM-MAP |
| DO-SHR-004 | Several expenses reimbursed by one payment | One settlement can satisfy multiple claims | Need many-to-one settlement observation without inventing separate deposits | TODO |
| DO-SHR-005 | One expense is reimbursed by several payments | One claim may be settled incrementally | Need partial settlement history | TODO |
| DO-SHR-006 | Friend pays your share directly | No reimbursement crosses your accounts | Burden exists without a physical payment by you | LOAM-MAP |
| DO-SHR-007 | Alternating shared payments net out informally | No explicit cash settlement occurs | Net social balance is not identical to household cash movement | TODO |
| DO-SHR-008 | Expense shared in unequal proportions | Allocation rule may be 50/50, fixed, or ad hoc | Do not encode policy unless actually needed | TODO |
| DO-SHR-009 | Employer reimbursement | Similar cash pattern, different counterparty/purpose/audit needs | UI can reuse interaction but not force identical semantics | TODO |
| DO-SHR-010 | Reimbursement arrives in PayPay instead of original bank/card | Settlement locus differs from original payment | Settlement relation must survive destination change | LOAM-MAP |
| DO-SHR-011 | Reimbursement is waived / gifted | Claim lifecycle ends without settlement movement | Need distinguish forgiveness/retirement from payment if this becomes necessary | TODO |
| DO-SHR-012 | Reimbursed amount includes fee or extra amount | Settlement amount ≠ original claim | Avoid “must exactly cancel original” invariant unless justified | TODO |

### Product evidence

**Zaim** documents at least two ways to handle an advance: mark advance outflow/inflow as always excluded from aggregation, or use item-level positive/negative rows to display only the user’s burden. With connected credit cards it may edit the imported purchase to self-burden and add an excluded advance row. This demonstrates how one physical payment is being reshaped to fit reporting.

Source: https://content.zaim.net/manuals/show/79

**YNAB** recommends reimbursement categories and split transactions for partial or multiple reimbursements; its Splitwise guide also offers either keeping the bill-splitting system separate or representing it in the account register.

Sources:
- https://support.ynab.com/en_us/reimbursements-faq-Sy9qDvtvgg
- https://support.ynab.com/en_us/splitwise-and-ynab-a-guide-H1GwOyuCq

**Actual Budget** also treats reimbursements through category-level strategies, including pre-funding versus temporarily carrying negative category balance.

Source: https://actualbudget.org/docs/budgeting/returns-and-reimbursements/

### LOAM interaction pressure

A future LOAM flow should probably ask the real-world question:

```text
You paid ¥3,600.
How much was actually your household's burden?

  My share:     ¥1,800
  Expected back: ¥1,800 from Friend
```

But this must not be implemented until LOAM has earned the needed claim/settlement semantics. UI research alone does not authorize them.

---

## F. Composite purchases and splits

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-SPL-001 | One receipt has food + household goods | One payment, several purposes | Purpose split must not imply several physical payments | LOAM-MAP |
| DO-SPL-002 | Purchase includes tax/fee | Remainder distribution can be tedious | Surface can calculate allocations while exact total invariant remains visible | COMPARE |
| DO-SPL-003 | One child amount left blank | Apps auto-fill remainder | Recognition/minimal input is good if preview shows exact allocation | OBSERVED |
| DO-SPL-004 | Evenly divide total across selected purposes | Apps can distribute automatically | Derived arithmetic should not become retained semantic evidence unless necessary | LOAM-MAP |
| DO-SPL-005 | Proportional tax distribution | Convenience math over already-entered portions | Excellent UI helper; should remain calculation-only | OBSERVED |
| DO-SPL-006 | One receipt includes cashback | Split may include transfer/inflow component | Physical payment shape can contain heterogeneous effects | COMPARE |
| DO-SPL-007 | Split purchase later gets partial refund | Refund may correspond to one component only | Relation to component/purpose matters if known | TODO |
| DO-SPL-008 | Imported bank record is one charge but merchant imports multiple shipments | One-to-one matching may fail | Observation identity cannot be based solely on split structure | COMPARE |
| DO-SPL-009 | User unsplits after realizing receipt detail was wrong | Existing apps destructively reshape transaction | LOAM needs correction story that preserves evidence | TODO |
| DO-SPL-010 | Parent + child rows appear in queries | Naive sum double-counts | Surface/query contract must make aggregation shape explicit | OBSERVED |

### Product evidence

**Actual Budget** models a split as a parent transaction plus child transactions whose amounts must sum to the parent. Its UI can evenly or proportionally distribute remainder. Actual’s CLI/API documentation explicitly warns that summing both parent and children double-counts the transaction.

Sources:
- https://actualbudget.org/docs/transactions/split-transactions/
- https://actualbudget.org/docs/api/cli/

**YNAB** also supports remainder autofill/even distribution and allows a transfer to appear as one split component, demonstrating that “split” can mix categorization and movement behavior.

Source: https://support.ynab.com/split-transactions-a-guide-SJLEKwY0q

**h-kernel archaeology:** `ActualMultiAddInput` explicitly treated the same two-or-more-posting shape as capable of representing purchases, income, splits, transfers, and corrections. This is valuable evidence against designing one retained domain type per UI verb.

Repository evidence: `shumoku88-bit/h-kernel`, `editor-src/HKernel/Editor/ActualAppend.hs`.

---

## G. Scheduled items, replacement, recurrence, and realization

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-SCH-001 | Create one known future bill | Many apps create schedule/reminder | Scheduled evidence should stay future evidence, not premature Actual | LOAM-MAP |
| DO-SCH-002 | Recurring bill | Series and occurrence identities can blur | Continuation and replacement must remain independent | LOAM-MAP |
| DO-SCH-003 | Change only next occurrence | Mature apps often expose “this one vs future” | UI should show exactly which identity is being replaced | LOAM-MAP |
| DO-SCH-004 | Change all future recurrence | Series policy changes | Do not represent as editing the same occurrence | TODO |
| DO-SCH-005 | Postpone one bill | Looks like date edit | LOAM already has replacement frontier semantics; display as human “reschedule” | LOAM-MAP |
| DO-SCH-006 | Amount changes for one month | Existing apps edit occurrence/expectation | Preserve old evidence and new occurrence identity where replacement is required | LOAM-MAP |
| DO-SCH-007 | Bill amount is approximate | Actual supports approximate/range schedule amount | LOAM must not store fake exact quantity if uncertainty becomes required | TODO |
| DO-SCH-008 | Skip one occurrence | Apps expose Skip Scheduled Date | Is skip retirement/cancellation of occurrence, not deletion of series? | TODO |
| DO-SCH-009 | Actual arrives before expected date | Matching window may fail | Matching is evidence relation, not schedule mutation | LOAM-MAP |
| DO-SCH-010 | Actual differs from expected amount | Schedule should remain expectation evidence | Realization does not rewrite expectation | LOAM-MAP |
| DO-SCH-011 | Auto-create Actual from schedule | Convenience crosses authority boundary | Require explicit policy and inspectable provenance | TODO |
| DO-SCH-012 | Process crashes after relation publish before replacement occurrence | Readers must not double count | Existing LOAM replacement writer deliberately uses relation-first fail-closed recovery | EARNED |
| DO-SCH-013 | Replacement occurrence has no Purpose route yet | Human expects “same bill”, semantics has fresh identity | Do not silently inherit route unless explicit policy/evidence is earned | EARNED |
| DO-SCH-014 | Future transaction is converted into schedule | Existing products may delete the temporary transaction | LOAM should avoid transient fake Actual representation | LOAM-MAP |

### Product evidence

**Actual Budget** supports one-time/recurring schedules, auto-entry or manual approval, exact/approximate/range amounts, schedule discovery from history, matching to transactions, and explicit skipping of a scheduled date.

Source: https://actualbudget.org/docs/schedules/

**GnuCash** scheduled transaction editing includes occurrence limits, recurrence frequency, reminder/auto-create policy, mini calendar, and a template transaction.

Source: https://gnucash.org/docs/v5/C/gnucash-manual/sched-editor.html

**LOAM existing evidence:** replacement-aware readers and practical writer already require relation-first publication and fail closed on an unknown replacement endpoint. This catalog treats those mechanics as earned production evidence, not merely a UI idea.

---

## H. Import matching, duplicate suppression, and source evidence

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-IMP-001 | Manually record now, bank imports later | Mature apps auto-match | Can imported evidence attach to existing event without replacing human provenance? | LOAM-MAP |
| DO-IMP-002 | Same bank transaction imports twice | Products delete/merge duplicate rows | Keep source evidence while ensuring one economic event, if identity is established | TODO |
| DO-IMP-003 | Bank changes date after pending → posted | Heuristic identity may survive date mutation | Date similarity cannot be durable identity authority by itself | LOAM-MAP |
| DO-IMP-004 | Bank changes payee formatting | Matching uses fuzzy payee | Heuristic may propose, not authorize, relation | LOAM-MAP |
| DO-IMP-005 | Same amount/date/payee legitimately occurs twice | Auto-match risks false merge | Ambiguity should surface as review state | LOAM-MAP |
| DO-IMP-006 | Import provides stable external id | Stronger evidence than heuristics | Preserve external identity/provenance explicitly | TODO |
| DO-IMP-007 | Two accounts import both halves of transfer | Transfer can appear doubled | Need relation among observations plus movement identity | LOAM-MAP |
| DO-IMP-008 | Historical bulk import has no manual row to match | Approval/categorization required | Do not infer matching just because one would be convenient | OBSERVED |
| DO-IMP-009 | One manual split corresponds to several imported charges | One-to-one matching fails in YNAB | Matching cardinality must be explicit, not assumed universal | TODO |
| DO-IMP-010 | Deleted imported row reappears on reimport | Product-specific tombstone/reimport policy | LOAM should make source replay and retirement policy explicit if imports arrive | TODO |
| DO-IMP-011 | User manually merges two duplicates | Existing app chooses one “kept” row and deletes other | LOAM should preserve both source observations if they are distinct evidence | LOAM-MAP |
| DO-IMP-012 | Import rule auto-categorizes/reroutes | Automation can silently become semantic authority | Rule provenance and approval boundary need explicit design | TODO |

### Product evidence

**Actual Budget** first uses imported IDs, then heuristics around date, amount, and payee to avoid duplicates. It can match a manually entered transaction to later import evidence and prefers imported date. Its manual Merge action chooses a kept transaction by import provenance and deletes the dropped row after copying missing fields.

Sources:
- https://actualbudget.org/docs/transactions/importing/
- https://actualbudget.org/docs/transactions/merging/

**YNAB** also matches later imported transactions to earlier manual entry. Current guidance notes one-to-one matching and warns that one manual split cannot match several separately imported charges.

Sources:
- https://support.ynab.com/en_us/approving-and-matching-transactions-a-guide-ByYNZaQ1i
- https://support.ynab.com/en_us/my-transactions-are-importing-more-than-once-ByyZUaPge

### Candidate LOAM review vocabulary

```text
Possible same event

Manual record:  ¥2,470  9/5  books
Bank evidence:  ¥2,470  9/6  PAYPAY

Why suggested:
  amount exact
  dates 1 day apart

[Relate as same event] [Keep separate] [Inspect]
```

The suggestion reason must remain visible. Similarity is not authority.

---

## I. Correction, reversal, deletion, and “undo”

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-COR-001 | Typo noticed immediately before publication | Ordinary form editing is enough | Draft editing need not create durable correction history | LOAM-MAP |
| DO-COR-002 | Wrong amount discovered after publication | Apps usually edit original row | LOAM should retain original and explicit correction relation | EARNED |
| DO-COR-003 | Wrong account discovered after publication | Destructive edit changes historical source shape | Human “Fix account” can be correction UI over retained evidence | LOAM-MAP |
| DO-COR-004 | Entire event was entered by mistake | Delete is common expectation | UI must distinguish “record was wrong” from “real event was economically reversed” | LOAM-MAP |
| DO-COR-005 | Real purchase later refunded | Not a correction | Refund relation/event stays economically real | LOAM-MAP |
| DO-COR-006 | Accounting error should be reversed | GnuCash offers reversing transaction | Human reversal can map to additive counter-effect while preserving original | COMPARE |
| DO-COR-007 | User wants Ctrl-Z immediately after a write | Conventional expectation is destructive undo | Could surface “Undo” as a previewed correction/reversal action with explicit consequence? | TODO |
| DO-COR-008 | User edits reconciled historical evidence | Products often warn or unlock status | LOAM should make external-confirmation consequences visible before correction | TODO |
| DO-COR-009 | Correction chain itself is wrong | Need correction-of-correction / current frontier | Ordered relation semantics already exist in h-kernel/LOAM research | LOAM-MAP |
| DO-COR-010 | Crash midway through multi-file correction publication | Partial visibility must fail closed | WriterOwnership + publication order should shape UI recovery messaging | LOAM-MAP |
| DO-COR-011 | User asks to “delete” old data for privacy | Semantic correction is not data-erasure/privacy deletion | Separate product/privacy operation from accounting correction | TODO |
| DO-COR-012 | Imported source retracts/corrects a row | External evidence lifecycle differs from human correction | Preserve source provenance and retraction/correction relation if supported | TODO |

### Product evidence

**GnuCash** exposes both direct edit/delete and `Add Reversing Transaction`. Its manual explicitly explains formal-accounting practice: keep the original and add a reversing transaction. The reversal is created immediately and may then receive explanatory notes.

Source: https://www.gnucash.org/docs/v5/C/gnucash-manual.pdf

**h-kernel archaeology** explicitly distinguishes ordered correction chains from commutative balance reductions and retains correction relations in `actual.journal`.

Repository evidence:
- `shumoku88-bit/h-kernel/docs/ARCHITECTURE.md`
- `shumoku88-bit/h-kernel/docs/HOUSEHOLD_CANONICAL_SOURCE.md`

### LOAM-specific human-factors requirement

A button labelled `Undo` is acceptable only if the preview makes the durable meaning predictable, e.g.:

```text
Undo this recording?

The original evidence will remain in history.
LOAM will publish a correction that makes the corrected event current.

Current effect: PayPay -638 JPY
After correction: PayPay -500 JPY

[Review provenance] [Correct]
```

Exact wording is not selected yet.

---

## J. Reconciliation and external confirmation

| ID | Human scenario | Existing UI pressure | LOAM question | State |
|---|---|---|---|---|
| DO-REC-001 | Compare LOAM balance with bank | Dedicated reconcile workspace is common | External confirmation should be evidence, not silent mutation of economic facts | LOAM-MAP |
| DO-REC-002 | Mark a transaction cleared | Apps use simple icon/status | What authority/source does “cleared” represent? | TODO |
| DO-REC-003 | Lock transactions after reconciliation | Products visually mark/limit edits | LOAM could make evidence frontier explicit instead of mutable lock status | TODO |
| DO-REC-004 | Bank and LOAM balances differ | Products guide troubleshooting | UI should first expose contributing unmatched evidence, not immediately manufacture adjustment | LOAM-MAP |
| DO-REC-005 | User chooses balance adjustment | YNAB can create an adjustment automatically | Adjustment must be clearly labelled as inferred balancing evidence, not discovered transaction | TODO |
| DO-REC-006 | Reconcile can be postponed | GnuCash supports Postpone | Useful interaction state need not become accounting fact | OBSERVED |
| DO-REC-007 | Reconciled item later corrected | Need explain which external checkpoint is invalidated/affected | Provenance should make consequence explicit | TODO |
| DO-REC-008 | Pending transaction exists at bank | Cleared/current balance excludes it | Pending external evidence and settled balance need separate display | LOAM-MAP |
| DO-REC-009 | Cash account has no external statement | Reconciliation authority differs | Do not force bank-style reconcile on all loci | TODO |
| DO-REC-010 | Reconciliation itself was mistaken | Need unreconcile/reopen | Treat external confirmation relation as correctable evidence | TODO |

### Product evidence

**Actual Budget** exposes Cleared/Uncleared totals and reconciliation from the account register. Cleared state means the transaction is confirmed against the external account statement, while reconciliation establishes a stronger checkpoint.

Source: https://actualbudget.org/docs/accounts/reconciliation/

**YNAB** presents cleared, uncleared, and reconciled states, asks the user to compare a cleared bank balance, and can create a Reconciliation Balance Adjustment when balances do not match. Reconciliation also influences duplicate-import suppression.

Sources:
- https://support.ynab.com/en_us/reconciling-accounts-a-guide-BJFE3fHys
- https://support.ynab.com/getting-started-with-reconciling-accounts-an-overview-Sy3JWx4Js

**GnuCash** uses a dedicated Reconcile window with statement date, ending balance, deposit/withdrawal comparison, and a Difference value. `Finish` is disabled until the difference is zero, while Postpone and Cancel remain available.

Source: https://www.gnucash.org/docs/v5/C/gnucash-manual/gui-reconcile.html

### Strong HCI pattern

GnuCash’s “Finish disabled until Difference = 0” is a useful error-prevention pattern independent of its accounting ontology:

> consequential completion becomes available only when the precondition the human is trying to establish is visibly satisfied.

LOAM may be able to generalize this to several flows without creating a generic framework.

---

# 3. Failure / ambiguity states to catalog explicitly

A mature LOAM UI should eventually have deliberate presentation for at least these states.

| ID | State | Bad UI outcome | Better research direction |
|---|---|---|---|
| FAIL-001 | external evidence missing | show 0 | show “not observed” / unknown |
| FAIL-002 | two candidate matches | auto-pick first | show ambiguity + evidence |
| FAIL-003 | replacement endpoint retained but occurrence missing | hide item / double count | fail closed + recovery action |
| FAIL-004 | imported row has unknown purpose | force category | retain unrouted state visibly |
| FAIL-005 | split children do not sum exactly | silently save | show exact remainder/prevent publish |
| FAIL-006 | reconciliation difference nonzero | “fix automatically” primary CTA | explain difference first |
| FAIL-007 | transfer counterpart not yet observed | create fake matching observation | show pending/unpaired external evidence |
| FAIL-008 | refund not linked to original purchase | classify as generic income | allow unresolved return relation |
| FAIL-009 | reimbursement amount differs from expected | force claim closed | partial/ambiguous settlement state |
| FAIL-010 | point balance unknown | assume zero | unknown commodity balance |
| FAIL-011 | stale UI snapshot before write | overwrite | re-read under writer ownership and reject/retry visibly |
| FAIL-012 | automation suggestion low-confidence | silently apply | require approval / show rationale |

---

# 4. Cross-product patterns worth preserving as interaction ideas

These are interaction patterns, not semantic imports.

## P1. Use real-world verbs for common actions

Examples:

- `Record payment`
- `Move money`
- `Refund`
- `Reschedule`
- `Reconcile`

Then preview the exact semantic effect.

This is preferable to asking the user to manipulate low-level flags such as `income/expense/transfer/excluded` when the real-world event is known.

## P2. Recognition over identifier recall

Prefer:

```text
9/10  Rent  ¥50,000
```

over:

```text
scheduled-17
```

Durable IDs remain inspectable provenance, not everyday input burden.

## P3. Explain automation proposals

For matching/routing/schedule detection, show why the suggestion exists.

```text
Suggested because:
  exact amount
  same payee
  1 day apart
```

Do not make heuristic confidence into authority.

## P4. Separate “what happened?” from “how should this report?”

Existing apps frequently use `exclude from calculation` as a repair tool for model/report mismatch. LOAM should prefer explicit projection policy and preserve the underlying event/evidence.

## P5. Preview semantic consequence, not file diff

A human should see:

```text
After this correction:
  PayPay balance: ¥8,224 → ¥8,362
  coffee burden: ¥138 → ¥0
```

rather than persistence rows unless they request provenance details.

## P6. Make invariant completion visible

Examples:

- split remainder = 0,
- reconciliation difference = 0,
- movement balanced,
- replacement frontier valid,
- referenced identity known.

The UI can turn proof/admission conditions into understandable completion signals.

---

# 5. Surface-specific pressure from difficult operations

| Operation | CLI | TUI | GUI/Web | ChatGPT | Mobile |
|---|---|---|---|---|---|
| simple move money | excellent explicit command | excellent picker flow | good | excellent natural-language proposal | excellent |
| imported duplicate review | good batch/script | good dense queue | excellent comparison | good explanation | acceptable |
| complex split | precise but verbose | strong keyboard grid | excellent | good if structured confirmation is shown | moderate |
| schedule replacement | precise | excellent | excellent | excellent conversational intent + preview | good |
| reimbursement settlement | precise if semantics known | good | excellent relation inspection | excellent natural-language capture | good |
| reconciliation | good expert mode | excellent dense workspace | excellent | useful guide, not sole surface | moderate |
| provenance inspection | excellent | excellent | excellent graph/drill-down | excellent explanation | secondary |
| correction chain | good | good | excellent | excellent intent disambiguation | moderate |
| points/mixed tender | verbose until semantics stabilize | good | good | potentially excellent | excellent capture |

No surface is required to expose every advanced operation equally.

---

# 6. LOAM / HRA / h-kernel archaeology notes

The predecessor systems are comparison specimens, not mandatory templates.

## h-kernel

Relevant surviving design evidence includes:

- multi-posting Actual input that can express purchases, income, splits, transfers, and corrections without one retained type per UI verb,
- non-destructive reversal/correction direction,
- explicit Plan lifecycle,
- explicit Entitlement transfer,
- ordered correction/routing/lifecycle histories separated from commutative balance reductions.

Useful files include:

- `editor-src/HKernel/Editor/ActualAppend.hs`
- `docs/ARCHITECTURE.md`
- `docs/HOUSEHOLD_CANONICAL_SOURCE.md`
- `README.md`

## HRA

Relevant surviving pressure includes:

- native Entitlement history with explicit transfer endpoints,
- UI-neutral Home presentation models,
- explicit issue lifecycle,
- calendar attention facts,
- fail-closed admission and source exactness.

This catalog should later excavate the concrete HRA Actual/Plan/Issue input flows and compare them against the external difficult-operation rows above.

---

# 7. Most important early conclusions

## C1. `Transfer` is a UI word, not yet a universal LOAM semantic primitive

Existing software overloads Transfer for:

- bank ↔ bank movement,
- bank ↔ wallet charge,
- cash withdrawal,
- card settlement,
- de-duplication across connected sources,
- sometimes report exclusion.

LOAM should keep asking which relation is actually needed.

## C2. Physical payment, household burden, and settlement repeatedly diverge

Shared expenses and reimbursements provide especially clear counterexamples to “one transaction row = one household expense”.

## C3. Existing apps often repair model limitations with projection flags

`exclude`, `ignore`, `hide`, or synthetic income can produce useful reports, but they are not automatically good retained semantics.

## C4. Matching requires two modes

1. heuristic **proposal**, and
2. durable **relation/evidence**.

Conflating the two would make automation authority too strong.

## C5. History-preserving semantics create an opportunity for unusually trustworthy Undo UX

LOAM can potentially offer familiar recovery verbs while being clearer than destructive editors about what actually changes.

## C6. The best error-prevention patterns expose semantic invariants to humans

Examples such as exact split remainder, zero reconciliation difference, or a valid replacement frontier can become interaction feedback rather than hidden implementation checks.

---

# 8. Next expansion queue

This shard is intentionally incomplete. Next expansion should add:

1. **Home / Attention Atlas**
   - what deserves interruption,
   - overdue vs upcoming vs unknown,
   - calendar vs task-list vs dashboard,
   - attention fatigue,
   - cycle boundary visibility.

2. **Transaction Entry Atlas**
   - one concrete household event across CLI/TUI/GUI/chat/mobile,
   - keystrokes/taps,
   - required recall,
   - defaults,
   - preview,
   - cancel/recovery.

3. **Difficult Operations Wave 2**
   - loans and interest,
   - cash rounding,
   - foreign currency / exchange,
   - chargebacks/disputes,
   - authorization holds,
   - subscriptions/trials,
   - tips and post-authorisation amount changes,
   - payroll deductions,
   - taxes,
   - gift cards/store credit,
   - joint accounts,
   - investment cash flows.

4. **HRA/h-kernel concrete flow archaeology**
   - exact keys/clicks,
   - Home → Actual,
   - Plan realization,
   - correction/reversal,
   - Issue realization,
   - Envelope/Entitlement movement.

---

# 9. Source index — current batch

External product documentation consulted in this shard:

- Actual Budget — Transfers: https://actualbudget.org/docs/transactions/transfers/
- Actual Budget — Importing: https://actualbudget.org/docs/transactions/importing/
- Actual Budget — Merge duplicates: https://actualbudget.org/docs/transactions/merging/
- Actual Budget — Split transactions: https://actualbudget.org/docs/transactions/split-transactions/
- Actual Budget — Returns and reimbursements: https://actualbudget.org/docs/budgeting/returns-and-reimbursements/
- Actual Budget — Schedules: https://actualbudget.org/docs/schedules/
- Actual Budget — Reconciliation: https://actualbudget.org/docs/accounts/reconciliation/
- Actual Budget — CLI: https://actualbudget.org/docs/api/cli/
- YNAB — Split transactions: https://support.ynab.com/split-transactions-a-guide-SJLEKwY0q
- YNAB — Credit card payments: https://support.ynab.com/en_us/credit-card-payments-a-guide-r1_506Q1j
- YNAB — Credit card balance transfers: https://support.ynab.com/en_us/how-to-make-a-credit-card-balance-transfer-ry5ETLWJo
- YNAB — Credit card refunds: https://support.ynab.com/en_us/credit-card-refunds-and-returns-H1J7qDWkj
- YNAB — Reimbursements FAQ: https://support.ynab.com/en_us/reimbursements-faq-Sy9qDvtvgg
- YNAB — Splitwise guide: https://support.ynab.com/en_us/splitwise-and-ynab-a-guide-H1GwOyuCq
- YNAB — Matching: https://support.ynab.com/en_us/approving-and-matching-transactions-a-guide-ByYNZaQ1i
- YNAB — Reconciliation: https://support.ynab.com/en_us/reconciling-accounts-a-guide-BJFE3fHys
- Money Forward ME — Transfer: https://support.me.moneyforward.com/hc/ja/articles/900003465946
- Money Forward ME — Transfer troubleshooting: https://support.me.moneyforward.com/hc/ja/articles/4409270669209
- Money Forward ME — Card settlement: https://support.me.moneyforward.com/hc/ja/articles/900004412703
- Money Forward ME — Point/discount as income: https://support.me.moneyforward.com/hc/ja/articles/4407798411161
- Money Forward ME — Point expiry: https://support.me.moneyforward.com/hc/ja/articles/13175406880025
- Money Forward ME — Refund/cancellation negative-entry limitation: https://support.me.moneyforward.com/hc/ja/articles/55527105255577
- Zaim — Transfer entry: https://content.zaim.net/manuals/show/20
- Zaim — Transfer rules: https://content.zaim.net/manuals/show/55
- Zaim — Advances/reimbursements: https://content.zaim.net/manuals/show/79
- Zaim — Refund/cancellation import behavior: https://content.zaim.net/questions/show/1090
- GnuCash — Reconcile window: https://www.gnucash.org/docs/v5/C/gnucash-manual/gui-reconcile.html
- GnuCash — Manual / reversing transaction / scheduled transactions: https://www.gnucash.org/docs/v5/C/gnucash-manual.pdf

Repository archaeology:

- `shumoku88-bit/h-kernel`
- `shumoku88-bit/hra`

---

> Observe broadly. Keep ambiguity visible. Implement only after semantics and practical pressure agree.
