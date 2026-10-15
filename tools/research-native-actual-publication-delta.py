#!/usr/bin/env python3
"""Native Actual publication-delta / logical-year research, NOT production.

Uses real Lean-published, qualified HouseholdImage snapshots from the existing
NativeHouseholdSectionBridge fixture. Models a base + immutable Actual TX
block updates under externally supplied *test* knowledge-year labels.
Does NOT infer historical learned times from actual event dates.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BRIDGE_FILE = ROOT / "tools" / "research-native-annual-section-bridge.py"


def bridge_module():
    spec = importlib.util.spec_from_file_location("loam_native_section_bridge", BRIDGE_FILE)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def require(condition: bool, message: str):
    if not condition:
        raise ValueError(message)


def actual_blocks(wire: str) -> tuple[str, list[tuple[str, str]], str]:
    """Lossless scan of real normalized-Actual outer TX block boundaries.

    Intra-TX data and opaque document-level settlement trailer are *never*
    interpreted as new canonical facts. Full decoded admission remains Lean's
    responsibility after reassembly.
    """
    require(wire.endswith("\n"), "normalized Actual lacks final newline")
    lines = wire.split("\n")[:-1]
    require(bool(lines) and lines[0] in {
        f"LOAM-NORMALIZED-ACTUAL\t{version}" for version in (1, 2, 3, 4)
    }, "unknown Actual wire header")
    header = lines[0] + "\n"
    blocks: list[tuple[str, str]] = []
    seen: set[str] = set()
    current: list[str] | None = None
    current_id = ""
    trailer: list[str] = []
    for row in lines[1:]:
        if current is None:
            if row.startswith("TX\t"):
                require(not trailer, "a TX occurs after settlement tail")
                tokens = row.split("\t")
                require(len(tokens) >= 4 and tokens[1] and tokens[1] not in seen,
                        "invalid or duplicate TX identity")
                current_id = tokens[1]
                current = [row]
            elif row == "ENDTX":
                raise ValueError("orphan ENDTX")
            elif row:
                trailer.append(row)
            else:
                raise ValueError("blank normalized Actual row")
        else:
            if row.startswith("TX\t"):
                raise ValueError("nested TX without ENDTX")
            current.append(row)
            if row == "ENDTX":
                seen.add(current_id)
                blocks.append((current_id, "\n".join(current) + "\n"))
                current = None
    require(current is None, "unterminated TX block")
    return header, blocks, "".join(row + "\n" for row in trailer)


def assembled(header: str, blocks: list[tuple[str, str]], trailer: str) -> str:
    require(header.startswith("LOAM-NORMALIZED-ACTUAL\t"), "header malformed")
    require(len({k for k, _ in blocks}) == len(blocks), "duplicate TX ID")
    return header + "".join(body for _, body in blocks) + trailer


def hash_blob(fs, folder: Path, body: bytes) -> str:
    return fs.store_immutable(folder, body)


def get_blob(fs, folder: Path, hash_id: str) -> bytes:
    if not fs.HASH.fullmatch(hash_id):
        raise fs.Unavailable("malformed referenced immutable blob ID")
    try:
        data = (folder / hash_id).read_bytes()
    except OSError as ex:
        raise fs.Unavailable("referenced blob missing") from ex
    if fs.digest(data) != hash_id:
        raise fs.Unavailable("referenced blob corrupted")
    return data


def json_blob(fs, folder: Path, h: str) -> dict:
    try:
        value = json.loads(get_blob(fs, folder, h))
        if not isinstance(value, dict):
            raise ValueError("not a JSON object")
        return value
    except (ValueError, UnicodeError) as ex:
        raise fs.Unavailable("referenced JSON blob malformed") from ex


def initial(fs, repo: Path, whole: bytes) -> tuple[str, dict]:
    """Store only one fully admitted initial household as immutable section blobs."""
    from_base = bridge_module()
    sections = from_base.parse_wire(whole)
    refs = [{"name": name, "hash": hash_blob(fs, repo / "blobs", body.encode("utf-8"))}
            for name, body in sections]
    manifest = {"version": 1, "basis": refs, "basis_wire": fs.digest(whole),
                "changes": []}
    head = hash_blob(fs, repo / "manifests", fs.canonical(manifest))
    fs.head_write(repo, head)
    return head, manifest


def delta(fs, repo: Path, before: bytes, after: bytes, year: int) -> dict:
    """Compare two externally qualified generations, storing changed TX only.

    This deliberately duplicates one changed transaction's full text after
    DATE-REV. A smaller operation grammar would need typed admission proofs.
    """
    from_base = bridge_module()
    previous = from_base.parse_wire(before)
    proposed = from_base.parse_wire(after)
    require([n for n, _ in previous] == [n for n, _ in proposed],
            "section presence/order changed: outside narrow delta lane")
    earlier = dict(previous)
    newer = dict(proposed)
    require([n for n in earlier if earlier[n] != newer[n]] == ["Actual"],
            "unsupported cross-family or no-op publication in narrow lane")

    h0, b0, tail0 = actual_blocks(earlier["Actual"])
    h1, b1, tail1 = actual_blocks(newer["Actual"])
    prior_ids = [name for name, _ in b0]
    after_ids = [name for name, _ in b1]
    require(after_ids[:len(prior_ids)] == prior_ids,
            "non-append original order or missing old TX identity")
    old_map = dict(b0)
    replacements = []
    for name, body in b1:
        if old_map.get(name) != body:
            replacements.append({
                "id": name,
                "hash": hash_blob(fs, repo / "blobs", body.encode("utf-8")),
                "mode": "replace" if name in old_map else "append"})
    require(bool(replacements) or h0 != h1 or tail0 != tail1,
            "Actual changed but no supported TX/trailer delta")
    return {
        "learned_year_test_label": year,
        "before_wire": fs.digest(before),
        "after_wire": fs.digest(after),
        "tx_changes": replacements,
        "header": h1 if h0 != h1 else None,
        "trailer": hash_blob(fs, repo / "blobs", tail1.encode("utf-8"))
                   if tail0 != tail1 else None,
    }


def publish_delta(fs, repo: Path, expected_head: str, patch: dict) -> str:
    """One immutable delta blob then new manifest; replace only single HEAD."""
    current, manifest = read_manifest(fs, repo)
    if current != expected_head:
        raise fs.Unavailable("stale observed manifest refused")
    old_years = [c["year"] for c in manifest["changes"]]
    year = patch["learned_year_test_label"]
    if not isinstance(year, int) or (old_years and year < old_years[-1]):
        raise fs.Unavailable("nonmonotonic externally assigned publication year")
    blob = hash_blob(fs, repo / "blobs", fs.canonical(patch))
    newer = {**manifest, "changes": manifest["changes"] + [
        {"year": year, "delta": blob}]}
    h = hash_blob(fs, repo / "manifests", fs.canonical(newer))
    fs.head_write(repo, h)
    return h


def read_manifest(fs, repo: Path) -> tuple[str, dict]:
    try:
        h = (repo / "HEAD").read_text("ascii").strip()
        m = json_blob(fs, repo / "manifests", h)
        if m["version"] != 1 or not isinstance(m["basis"], list) \
                or not isinstance(m["changes"], list):
            raise fs.Unavailable("unsupported manifest")
        years = [r["year"] for r in m["changes"]]
        if years != sorted(years):
            raise fs.Unavailable("unordered knowledge-year labels")
        if any(not isinstance(y, int) for y in years):
            raise fs.Unavailable("unqualified year labels")
        return h, m
    except (OSError, ValueError, TypeError, KeyError) as ex:
        raise fs.Unavailable("missing or malformed selected manifest") from ex


def rebuild(fs, repo: Path, upto: int | None = None) -> bytes:
    """Replay the complete committed source prefix, fail-closed on missing data.

    No selective year skipping yet; this is a full qualified-generation
    assembly experiment. Partial yearly lookup would require a source graph
    completeness index as in #2009 and native qualification of its claims.
    """
    from_base = bridge_module()
    _, manifest = read_manifest(fs, repo)
    try:
        names = [part["name"] for part in manifest["basis"]]
        if not names or len(set(names)) != len(names) or "Actual" not in names:
            raise fs.Unavailable("invalid base section coverage")
        parts = [(part["name"], get_blob(fs, repo / "blobs", part["hash"]).decode("utf-8"))
                 for part in manifest["basis"]]
        result = from_base.encode(parts)
        if fs.digest(result) != manifest["basis_wire"]:
            raise fs.Unavailable("base qualified generation differs")
        changes = manifest["changes"]
        if upto is not None:
            if upto < 0 or upto > len(changes):
                raise fs.Unavailable("unknown committed generation")
            changes = changes[:upto]
        for record in changes:
            patch = json_blob(fs, repo / "blobs", record["delta"])
            if patch["learned_year_test_label"] != record["year"]:
                raise fs.Unavailable("delta publication-year mismatch")
            if patch["before_wire"] != fs.digest(result):
                raise fs.Unavailable("noncontiguous or wrong-source patch")
            actual = dict(parts)["Actual"]
            header, txs, trailer = actual_blocks(actual)
            indexed = dict(txs)
            ids = [name for name, _ in txs]
            for update in patch["tx_changes"]:
                txid = update["id"]
                body = get_blob(fs, repo / "blobs", update["hash"]).decode("utf-8")
                parsed_header, parsed_txs, parsed_tail = actual_blocks(
                    "LOAM-NORMALIZED-ACTUAL\t1\n" + body)
                if parsed_tail or len(parsed_txs) != 1 or parsed_txs[0] != (txid, body):
                    raise fs.Unavailable("TX identity or framing mismatch")
                if update["mode"] == "replace" and txid in indexed:
                    indexed[txid] = body
                elif update["mode"] == "append" and txid not in indexed:
                    ids.append(txid)
                    indexed[txid] = body
                else:
                    raise fs.Unavailable("unjustified TX replacement or append")
            if patch["header"] is not None:
                header = patch["header"]
            if patch["trailer"] is not None:
                trailer = get_blob(fs, repo / "blobs", patch["trailer"]).decode("utf-8")
            regenerated = assembled(header, [(x, indexed[x]) for x in ids], trailer)
            parts = [(name, regenerated if name == "Actual" else body)
                     for name, body in parts]
            result = from_base.encode(parts)
            if fs.digest(result) != patch["after_wire"]:
                raise fs.Unavailable("reconstructed committed generation differs")
        return result
    except (UnicodeError, OSError, KeyError, TypeError, ValueError) as ex:
        raise fs.Unavailable("incomplete or corrupt native Actual source delta") from ex


def must_refuse(fs, action, label: str) -> None:
    try:
        action()
    except fs.Unavailable:
        return
    raise AssertionError(f"unsafe acceptance: {label}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        parser.print_help()
        return
    native = bridge_module()
    fs = native.storage()
    with tempfile.TemporaryDirectory(prefix="loam-real-actual-delta-") as temporary:
        work = Path(temporary)
        source = work / "source"
        snapshots = work / "snapshots"
        native.checked_run(native.FIXTURE, "setup", source)
        native.checked_run(native.NATIVE, "produce", source, snapshots)
        whole = [(snapshots / f"snapshot-{n}.wire").read_bytes() for n in range(4)]
        repo = work / "delta-repo"
        for folder in (repo, repo / "blobs", repo / "manifests"):
            folder.mkdir()
        old, _ = initial(fs, repo, whole[0])
        assert rebuild(fs, repo) == whole[0]
        changed_tx_counts = []
        heads = [old]
        # These are user-UNSEEN fixture labels, not observed canonical learned times.
        # 2027's two semantic writes may share a calendar year, no year-close.
        for index, year in enumerate((2027, 2027, 2028), 1):
            patch = delta(fs, repo, whole[index-1], whole[index], year)
            changed_tx_counts.append(len(patch["tx_changes"]))
            new = publish_delta(fs, repo, old, patch)
            assert new != old
            assert rebuild(fs, repo) == whole[index]
            recovered = work / f"restored-{index}"
            recovered.mkdir()
            (recovered / "household.loam").write_bytes(rebuild(fs, repo))
            native.checked_run(native.NATIVE, "verify", recovered)
            heads.append(new)
            old = new

        final = rebuild(fs, repo)
        assert final == whole[-1]
        # Check each prefix at one exact committed HEAD, not a reconstruction
        # based on effective date or LatestWins from partial files.
        for index, head in enumerate(heads):
            fs.head_write(repo, head)
            assert rebuild(fs, repo) == whole[index]
        fs.head_write(repo, heads[-1])

        # One delta file or a changed TX blob must never be silently skipped.
        final_m = read_manifest(fs, repo)[1]
        patch_h = final_m["changes"][-1]["delta"]
        patch = json_blob(fs, repo / "blobs", patch_h)
        changed_h = patch["tx_changes"][0]["hash"]
        (repo / "blobs" / changed_h).rename(repo / "blobs" / (changed_h + ".missing"))
        must_refuse(fs, lambda: rebuild(fs, repo), "missing revised TX evidence")
        (repo / "blobs" / (changed_h + ".missing")).rename(repo / "blobs" / changed_h)
        assert rebuild(fs, repo) == whole[-1]

        (repo / "blobs" / patch_h).rename(repo / "blobs" / (patch_h + ".missing"))
        must_refuse(fs, lambda: rebuild(fs, repo), "missing committed knowledge-year delta")
        (repo / "blobs" / (patch_h + ".missing")).rename(repo / "blobs" / patch_h)

        current = read_manifest(fs, repo)[0]
        assert current == heads[-1]
        try:
            publish_delta(fs, repo, heads[0], {"learned_year_test_label": 2028})
        except fs.Unavailable:
            pass
        else:
            raise AssertionError("stale head accepted additional delta")

        first = dict(native.parse_wire(whole[0]))["Actual"]
        last = dict(native.parse_wire(whole[-1]))["Actual"]
        old_ids = [x[0] for x in actual_blocks(first)[1]]
        new_ids = [x[0] for x in actual_blocks(last)[1]]
        assert len(new_ids) > len(old_ids)
        # Only content-addressed new blobs were stored; accepted past blobs stay.
        blob_bytes = sum(p.stat().st_size for p in (repo / "blobs").iterdir())
        manifest_bytes = sum(p.stat().st_size for p in (repo / "manifests").iterdir())
        print(json.dumps({
            "status": "PASS: native Actual TX delta replay equals every qualified HouseholdImage generation",
            "qualified_generations": len(whole),
            "tx_ids_base": old_ids,
            "tx_ids_final": new_ids,
            "changed_transaction_blobs_per_publication": changed_tx_counts,
            "assigned_test_publication_years": [2027, 2027, 2028],
            "full_image_snapshots_bytes": sum(map(len, whole)),
            "unique_base_and_tx_delta_blob_bytes": blob_bytes,
            "immutable_manifest_bytes": manifest_bytes,
            "total_research_store_bytes_excluding_head": blob_bytes + manifest_bytes,
            "missing_delta_and_changed_tx_refused": True,
            "stale_head_refused": True,
            "same_generation_native_Actual_and_Scheduled_verified": True,
            "limitations": (
                "Not a qualified learned-time archive; reconstructs full Actual before Lean admission; "
                "TX replacement repeats its original effect amounts and there is no lazy-year partial query."
            ),
        }, indent=2))


if __name__ == "__main__":
    main()
