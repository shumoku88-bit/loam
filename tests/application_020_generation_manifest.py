from __future__ import annotations

import hashlib
import os
from pathlib import Path
import tempfile
import threading
import time

FAMILIES = (
    "Event",
    "ActualValidity",
    "EventDescription",
    "RelationUnit",
    "RelationDischarge",
    "ActualRouting",
)
MOVEMENT_FAMILIES = set(FAMILIES[:5])
HEADER = "LOAM-GENERATION-MANIFEST\t1"


def payload(family: str, version: str) -> bytes:
    row = f"{family}\t{version}\t0123456789abcdef\n".encode()
    return f"LOAM-FAMILY-IMAGE\t{family}\t{version}\n".encode() + row * 4096


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def object_rel(family: str, version: str) -> str:
    return f"objects/{family}/{version}.loam"


def write_object(root: Path, family: str, version: str, data: bytes, *, slow: bool = False) -> str:
    rel = object_rel(family, version)
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise AssertionError(f"write-once object path already exists: {rel}")
    chunk = max(1, len(data) // 64) if slow else len(data)
    with path.open("xb", buffering=0) as handle:
        for offset in range(0, len(data), chunk):
            handle.write(data[offset : offset + chunk])
            if slow:
                time.sleep(0.0003)
        os.fsync(handle.fileno())
    if path.read_bytes() != data:
        raise AssertionError(f"object bytes changed after write: {rel}")
    return rel


def manifest_bytes(refs: dict[str, str], root: Path) -> bytes:
    rows = [HEADER]
    for family in FAMILIES:
        rel = refs[family]
        data = (root / rel).read_bytes()
        rows.append(f"{family}\t{rel}\t{sha256(data)}")
    return ("\n".join(rows) + "\n").encode()


def parse_manifest(raw: bytes) -> dict[str, tuple[str, str]]:
    text = raw.decode("utf-8")
    lines = text.splitlines()
    if not lines or lines[0] != HEADER:
        raise AssertionError("manifest header mismatch")
    result: dict[str, tuple[str, str]] = {}
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) != 3:
            raise AssertionError(f"manifest row shape mismatch: {line!r}")
        family, rel, digest = fields
        if family not in FAMILIES or family in result:
            raise AssertionError(f"manifest family mismatch: {family!r}")
        rel_path = Path(rel)
        if rel_path.is_absolute() or ".." in rel_path.parts:
            raise AssertionError(f"unsafe manifest object path: {rel!r}")
        expected_prefix = ("objects", family)
        if rel_path.parts[:2] != expected_prefix:
            raise AssertionError(f"manifest family/path mismatch: {family!r} -> {rel!r}")
        if len(digest) != 64:
            raise AssertionError("manifest digest length mismatch")
        result[family] = (rel, digest)
    if tuple(result.keys()) != FAMILIES:
        raise AssertionError("manifest does not name each family exactly once in canonical order")
    return result


def read_authority(root: Path, current: Path) -> tuple[bytes, ...]:
    # One manifest read is the authority snapshot. Every referenced family image
    # is write-once in this fixture, so a later CURRENT switch cannot mix it.
    refs = parse_manifest(current.read_bytes())
    view: list[bytes] = []
    for family in FAMILIES:
        rel, expected_digest = refs[family]
        data = (root / rel).read_bytes()
        if sha256(data) != expected_digest:
            raise AssertionError(f"referenced object digest mismatch: {family}")
        view.append(data)
    return tuple(view)


def publish_manifest(root: Path, current: Path, refs: dict[str, str]) -> None:
    stage = root / "CURRENT.loam-stage"
    raw = manifest_bytes(refs, root)
    with stage.open("wb", buffering=0) as handle:
        handle.write(raw)
        os.fsync(handle.fileno())
    if stage.read_bytes() != raw:
        raise AssertionError("staged manifest bytes differ before publication")
    if os.stat(stage).st_dev != os.stat(current).st_dev:
        raise AssertionError("CURRENT stage and authority are not on the same filesystem")
    os.replace(stage, current)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="loam-application-020-") as tmp:
        root = Path(tmp)
        current = root / "CURRENT"

        refs0: dict[str, str] = {}
        bytes0: dict[str, bytes] = {}
        for family in FAMILIES:
            data = payload(family, "v0")
            bytes0[family] = data
            refs0[family] = write_object(root, family, "v0", data)
        current.write_bytes(manifest_bytes(refs0, root))
        if read_authority(root, current) != tuple(bytes0[f] for f in FAMILIES):
            raise AssertionError("initial manifest did not reconstruct the old authority view")

        # Single-family locality: create only a new routing image, then switch one
        # manifest. All other family object references and bytes stay untouched.
        routing1 = payload("ActualRouting", "v1")
        refs1 = dict(refs0)
        refs1["ActualRouting"] = write_object(root, "ActualRouting", "v1", routing1)
        changed01 = {f for f in FAMILIES if refs0[f] != refs1[f]}
        if changed01 != {"ActualRouting"}:
            raise AssertionError(f"routing-only update rewrote unexpected families: {changed01}")
        publish_manifest(root, current, refs1)

        bytes1 = dict(bytes0)
        bytes1["ActualRouting"] = routing1
        view1 = tuple(bytes1[f] for f in FAMILIES)
        if read_authority(root, current) != view1:
            raise AssertionError("routing-only manifest publication reconstructed the wrong view")

        # Interrupted and complete-but-unreferenced objects are operational residue,
        # not authority. CURRENT still reconstructs exactly the routing-only view.
        partial_path = root / object_rel("Event", "interrupted")
        partial_path.parent.mkdir(parents=True, exist_ok=True)
        partial_path.write_bytes(payload("Event", "interrupted")[:4096])
        if read_authority(root, current) != view1:
            raise AssertionError("partial unreferenced object changed authority")

        orphan = payload("EventDescription", "orphan")
        write_object(root, "EventDescription", "orphan", orphan)
        if read_authority(root, current) != view1:
            raise AssertionError("complete unreferenced object changed authority")

        bytes2 = dict(bytes1)
        refs2 = dict(refs1)
        for family in MOVEMENT_FAMILIES:
            bytes2[family] = payload(family, "v2")
        view2 = tuple(bytes2[f] for f in FAMILIES)

        counts = {view1: 0, view2: 0}
        errors: list[str] = []
        lock = threading.Lock()
        start = threading.Event()
        stop = threading.Event()

        def reader() -> None:
            start.wait()
            while not stop.is_set():
                try:
                    view = read_authority(root, current)
                except Exception as exc:
                    with lock:
                        errors.append(f"reader exception: {exc!r}")
                    continue
                if view not in counts:
                    with lock:
                        errors.append("reader observed a mixed or unknown manifest-selected view")
                    continue
                with lock:
                    counts[view] += 1

        readers = [threading.Thread(target=reader, daemon=True) for _ in range(4)]
        for thread in readers:
            thread.start()
        start.set()

        # Build every changed Movement family off-authority. Readers continue to
        # follow refs1 while these files are incomplete or appear one by one.
        for family in FAMILIES:
            if family in MOVEMENT_FAMILIES:
                refs2[family] = write_object(root, family, "v2", bytes2[family], slow=True)

        changed12 = {f for f in FAMILIES if refs1[f] != refs2[f]}
        if changed12 != MOVEMENT_FAMILIES:
            raise AssertionError(f"Movement update changed the wrong object set: {changed12}")
        if refs2["ActualRouting"] != refs1["ActualRouting"]:
            raise AssertionError("Movement publication rewrote routing-only state")

        publish_manifest(root, current, refs2)

        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            with lock:
                if counts[view2] > 0:
                    break
            time.sleep(0.001)

        stop.set()
        for thread in readers:
            thread.join(timeout=2.0)

        if errors:
            raise AssertionError("; ".join(errors[:5]))
        if counts[view1] == 0 or counts[view2] == 0:
            raise AssertionError(
                f"concurrent readers did not observe both complete generations: {counts}"
            )
        if read_authority(root, current) != view2:
            raise AssertionError("final CURRENT did not reconstruct the complete Movement view")
        if (root / "CURRENT.loam-stage").exists():
            raise AssertionError("manifest staging path remained after publication")

        # Write-once provenance boundary for this fixture: every previously
        # published object remains byte-identical after later manifest switches.
        for family in FAMILIES:
            if (root / refs0[family]).read_bytes() != bytes0[family]:
                raise AssertionError(f"old object was mutated: {family}")
        if (root / refs1["ActualRouting"]).read_bytes() != routing1:
            raise AssertionError("routing v1 object was mutated by Movement publication")

        print(
            "Application 020 generation-manifest fixture PASS: "
            f"old_generation_reads={counts[view1]} new_generation_reads={counts[view2]} "
            "mixed_reads=0 routing_rewrite_families=1 movement_rewrite_families=5 "
            "partial_orphan_authority_effect=0"
        )


if __name__ == "__main__":
    main()
