#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("unified_actual_wire", HERE / "unified-actual-wire.py")
assert SPEC and SPEC.loader
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


def b(text: str) -> bytes:
    return text.encode("utf-8")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_fixture(root: Path) -> None:
    movement = root / "movement-authority"
    objects = movement / "objects"
    objects.mkdir(parents=True)

    event = b("""LOAM-EVENT-MEMORY\t1
EVENT\tdup
EFFECT\tdup-a\tcash\tjpy\t10
EFFECT\tdup-b\tcash\tjpy\t10
EFFECT\tdup-c\tmisc\tjpy\t-20
EVENT\told
EFFECT\told-a\tcash\tjpy\t-100
EFFECT\told-b\tfood\tjpy\t100
EVENT\tnew
EFFECT\tnew-a\tcash\tjpy\t-100
EFFECT\tnew-b\tfood\tjpy\t100
EVENT\tdated
EFFECT\tdate-a\tcash\tjpy\t-50
EFFECT\tdate-b\tbook\tjpy\t50
EVENT\trev-target
EFFECT\trt-a\tcash\tjpy\t-25
EFFECT\trt-b\tmisc\tjpy\t25
EVENT\trev-event
EFFECT\trv-a\tcash\tjpy\t25
EFFECT\trv-b\tmisc\tjpy\t-25
EVENT\trel-src
EFFECT\tsource-key\tcash\tjpy\t-1000
EFFECT\trel-other\tmisc\tjpy\t1000
EVENT\trel-pay
EFFECT\tpay-a\tcash\tjpy\t-40
EFFECT\tpay-b\tmisc\tjpy\t40
""")
    validity = b("""LOAM-ACTUAL-VALIDITY-HISTORY\t3
BASE\tdup\t2026-01-01
BASE\told\t2026-01-02
BASE\tnew\t2026-01-02
BASE\tdated\t2026-01-03
BASE\trev-target\t2026-01-04
BASE\trev-event\t2026-01-05
BASE\trel-src\t2026-01-06
BASE\trel-pay\t2026-01-07
REVISION\trev-1\tdated\t2026-02-02
REVISION\trev-2\tdated\t2026-02-03
CORRECTION\tROOT\tdated\trev-1
CORRECTION\tREVISION\trev-1\trev-2
""")
    descriptions = b("""LOAM-EVENT-DESCRIPTION-MEMORY\t1
DESC\tdup\tduplicate payload
DESC\told\toriginal
DESC\tnew\treplacement\\ttext
DESC\tdated\tdate\\ncorrected
DESC\trel-src\tshared relation source
""")
    relations = b("""LOAM-RELATION-UNIT-MEMORY\t1
RELATION\trel-1\trel-src\tsource-key\tE\tfriend\tH\t\t400
""")
    discharges = b("""LOAM-RELATION-DISCHARGE-MEMORY\t1
DISCHARGE\trel-pay\trel-1\t40
""")
    blobs = {
        "Event": ("objects/event", event),
        "ActualValidity": ("objects/validity", validity),
        "EventDescription": ("objects/descriptions", descriptions),
        "RelationUnit": ("objects/relations", relations),
        "RelationDischarge": ("objects/discharges", discharges),
    }
    manifest = ["LOAM-MOVEMENT-MANIFEST\t2"]
    for family, (relative, data) in blobs.items():
        (movement / relative).write_bytes(data)
        manifest.append(f"{family}\t{relative}\t{sha(data)}")
    (movement / "CURRENT").write_text("\n".join(manifest) + "\n", encoding="utf-8")

    (root / "corrections.loam").write_text(
        "LOAM-EVENT-CORRECTION-MEMORY\t2\nCORRECTION\told\tnew\n",
        encoding="utf-8",
    )
    (root / "actual-reversals.loam").write_text(
        "LOAM-ACTUAL-REVERSAL-MEMORY\t1\nREVERSE\trev-target\trev-event\n",
        encoding="utf-8",
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        write_fixture(root)
        split = m.load_split(root)
        wire = m.encode(split)
        unified = m.decode(wire)
        assert m.normal(split) == m.normal(unified)

        tx = {row.event: row for row in unified.txs}
        assert tx["new"].replaces == "old"
        assert tx["rev-event"].reversal_of == "rev-target"
        assert tx["old"].replaces is None
        assert tx["dated"].description == "date\ncorrected"
        assert [r.id for r in tx["dated"].revisions] == ["rev-1", "rev-2"]
        assert tx["dated"].revisions[0].predecessor_kind == "ROOT"
        assert tx["dated"].revisions[0].predecessor == "dated"
        assert tx["dated"].revisions[1].predecessor_kind == "REVISION"
        assert tx["dated"].revisions[1].predecessor == "rev-1"

        # Relation source keeps durable identity; unrelated Effects lose eager keys.
        keyed = [e for e in tx["rel-src"].effects if e.key is not None]
        assert len(keyed) == 1 and keyed[0].key == "source-key"
        assert all(e.key is None for e in tx["rel-pay"].effects)
        assert tx["rel-src"].relations[0].id == "rel-1"
        assert tx["rel-src"].relations[0].source_key == "source-key"
        assert tx["rel-pay"].discharges == (m.Discharge("rel-1", 40),)

        # Erasing unreferenced identity must preserve multiplicity, not collapse rows.
        dup_cash = [e for e in tx["dup"].effects if e.locus == "cash" and e.quanta == 10]
        assert len(dup_cash) == 2 and all(e.key is None for e in dup_cash)

        # Split open-reference residue is not admitted canonical Actual.
        (root / "corrections.loam").write_text(
            "LOAM-EVENT-CORRECTION-MEMORY\t2\nCORRECTION\told\tabsent-event\n",
            encoding="utf-8",
        )
        try:
            m.load_split(root)
        except m.Error:
            pass
        else:
            raise AssertionError("expected absent correction endpoint to fail closed")

        print(f"synthetic unified Actual: {len(wire)} bytes")
        print("synthetic unified Actual edge-case parity passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
