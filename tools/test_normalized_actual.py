#!/usr/bin/env python3
from __future__ import annotations

import tempfile
from dataclasses import replace
from pathlib import Path

from normalized_actual import (
    Actual,
    ActualError,
    encode,
    load_selected,
    parse,
    select_generation,
    semantic_observation,
    stage_generation,
)


FIXTURE = """LOAM-NORMALIZED-ACTUAL\t1
TX\tcorrection-0\t2026-09-01\tDESC\toriginal
EFFECT\tbank\tjpy\t-100
EFFECT\tfood\tjpy\t100
ENDTX
TX\tcorrection-1\t2026-09-01\tDESC\tfirst correction
REPLACES\tcorrection-0
EFFECT\tbank\tjpy\t-120
EFFECT\tfood\tjpy\t120
ENDTX
TX\tcorrection-2\t2026-09-01\tDESC\tsecond correction
REPLACES\tcorrection-1
EFFECT\tbank\tjpy\t-125
EFFECT\tfood\tjpy\t125
DATE-REV\tdate-revision-1\t2026-09-02\tREPLACES\tROOT
DATE-REV\tdate-revision-2\t2026-09-03\tREPLACES\tREV\tdate-revision-1
ENDTX
TX\tpayment\t2026-09-04\tNODESC
EFFECT\tbank\tjpy\t-500
EFFECT\tmisc\tjpy\t500
ENDTX
TX\tpayment-reversal\t2026-09-05\tDESC\tundo payment
REVERSAL-OF\tpayment
EFFECT\tbank\tjpy\t500
EFFECT\tmisc\tjpy\t-500
ENDTX
TX\trelation-source\t2026-09-06\tDESC\tfriend relation
KEYED-EFFECT\tsource-effect\tbank\tjpy\t-1000
EFFECT\tbank\tjpy\t-250
EFFECT\tfriend\tjpy\t1250
RELATION\trelation-1\tSOURCE\tsource-effect\thousehold\texternal:friend\t400
ENDTX
TX\tdischarge-1\t2026-09-07\tNODESC
EFFECT\tbank\tjpy\t-150
EFFECT\tfriend\tjpy\t150
DISCHARGE\trelation-1\t150
ENDTX
TX\tdischarge-2\t2026-09-08\tDESC\tpartial repayment
EFFECT\tbank\tjpy\t-100
EFFECT\tfriend\tjpy\t100
DISCHARGE\trelation-1\t100
ENDTX
""".encode()


def expect_rejected(label: str, data: bytes) -> None:
    try:
        parse(data)
    except ActualError:
        return
    raise AssertionError(f"expected rejection: {label}")


def main() -> None:
    actual = parse(FIXTURE)
    canonical = encode(actual)
    reparsed = parse(canonical)
    assert reparsed == actual
    before = semantic_observation(actual)
    after = semantic_observation(reparsed)
    assert before == after

    assert "TX\tcorrection-2\t2026-09-03\tDESC=second correction" in before
    assert "CORRECTION\tcorrection-0\tcorrection-1" in before
    assert "CORRECTION\tcorrection-1\tcorrection-2" in before
    assert "REVERSAL\tpayment\tpayment-reversal" in before
    assert (
        "RELATION\trelation-1\trelation-source\tsource-effect\thousehold\t"
        "external:friend\t400\t150"
    ) in before

    # Ordinary Effect list order is representation only.  Reverse the Effects in
    # the relation source, including the duplicate bank/jpy coordinate, and require
    # the semantic observation to stay identical.
    changed_txs = []
    for tx in actual.txs:
        if tx.event == "relation-source":
            changed_txs.append(replace(tx, effects=tuple(reversed(tx.effects))))
        else:
            changed_txs.append(tx)
    permuted = Actual(tuple(changed_txs))
    assert semantic_observation(permuted) == before

    # Unsupported/open topologies fail closed.
    expect_rejected(
        "open correction",
        FIXTURE.replace(b"REPLACES\tcorrection-0", b"REPLACES\tmissing-event", 1),
    )
    cycle = FIXTURE.replace(
        b"TX\tcorrection-0\t2026-09-01\tDESC\toriginal\n",
        b"TX\tcorrection-0\t2026-09-01\tDESC\toriginal\nREPLACES\tcorrection-2\n",
        1,
    )
    expect_rejected("correction cycle", cycle)
    branch = FIXTURE + b"TX\tcorrection-branch\t2026-09-09\tNODESC\nREPLACES\tcorrection-0\nENDTX\n"
    expect_rejected("correction branch", branch)
    date_branch = FIXTURE.replace(
        b"DATE-REV\tdate-revision-2\t2026-09-03\tREPLACES\tREV\tdate-revision-1\n",
        b"DATE-REV\tdate-revision-2\t2026-09-03\tREPLACES\tREV\tdate-revision-1\n"
        b"DATE-REV\tdate-revision-3\t2026-09-04\tREPLACES\tROOT\n",
        1,
    )
    expect_rejected("date correction branch", date_branch)
    expect_rejected(
        "missing date predecessor",
        FIXTURE.replace(b"REV\tdate-revision-1", b"REV\tmissing-revision", 1),
    )
    expect_rejected(
        "non-inverse reversal",
        FIXTURE.replace(b"EFFECT\tbank\tjpy\t500\nEFFECT\tmisc\tjpy\t-500", b"EFFECT\tbank\tjpy\t499\nEFFECT\tmisc\tjpy\t-500", 1),
    )
    expect_rejected(
        "unresolved relation source",
        FIXTURE.replace(b"SOURCE\tsource-effect", b"SOURCE\tmissing-effect", 1),
    )
    expect_rejected(
        "over-discharge",
        FIXTURE.replace(b"DISCHARGE\trelation-1\t100", b"DISCHARGE\trelation-1\t300", 1),
    )
    expect_rejected(
        "unknown discharge relation",
        FIXTURE.replace(b"DISCHARGE\trelation-1\t150", b"DISCHARGE\tmissing-relation\t150", 1),
    )

    # Concrete generation protocol: staging bytes has no semantic authority.  Only
    # one CURRENT replacement changes the readable world.
    with tempfile.TemporaryDirectory() as temp:
        store = Path(temp) / "actual-authority"
        old_id = stage_generation(store, FIXTURE)
        select_generation(store, old_id)
        old_obs = semantic_observation(load_selected(store))
        assert old_obs == before

        new_wire = FIXTURE.replace(b"DESC\tpartial repayment", b"DESC\tpartial repayment revised", 1)
        new_id = stage_generation(store, new_wire)
        assert new_id != old_id
        # Merely staged New is invisible.
        assert semantic_observation(load_selected(store)) == old_obs

        # A junk partial generation is also invisible because discovery/file age is
        # not authority.
        junk = store / "generations" / ("0" * 64)
        junk.mkdir(parents=True)
        (junk / "actual.loam").write_text("partial\n", encoding="utf-8")
        assert semantic_observation(load_selected(store)) == old_obs

        select_generation(store, new_id)
        new_obs = semantic_observation(load_selected(store))
        assert new_obs != old_obs
        assert "DESC=partial repayment revised" in new_obs

    print("normalized Actual synthetic qualification PASS")
    print(f"fixture bytes: {len(FIXTURE)}")
    print("covered: correction/date-revision/reversal/relation/discharge/duplicate-coordinate/description/publication")


if __name__ == "__main__":
    main()
