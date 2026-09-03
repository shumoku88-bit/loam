#!/usr/bin/env bash
set -euo pipefail

# Reproducible destructive-specimen qualification for Historical Actual prepare.
# Every mutation happens below WORK_ROOT. SOURCE_ROOT and DESTINATION_ROOT are
# read-only inputs.

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <loamHistoricalPrepare-bin> <actual.journal> <destination-root> <work-root>" >&2
  exit 2
fi

BIN="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
SOURCE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
DEST="$(cd "$3" && pwd)"
WORK="$4"

rm -rf "$WORK"
mkdir -p "$WORK"

expect_fail() {
  local name="$1" expected="$2"; shift 2
  local log="$WORK/$name.log"
  if "$@" >"$log" 2>&1; then
    echo "FAIL: $name unexpectedly succeeded" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$log"; then
    echo "FAIL: $name did not report '$expected'" >&2
    cat "$log" >&2
    exit 1
  fi
  echo "PASS: $name"
}

reseal_candidate() {
  local bundle="$1" rel="$2"
  python3 - "$bundle" "$rel" <<'PY'
import hashlib, pathlib, sys
bundle, rel = pathlib.Path(sys.argv[1]), sys.argv[2]
p = bundle / "candidate-root" / rel
b = p.read_bytes()
row = f"CANDIDATE\t{rel}\t{len(b)}\t{hashlib.sha256(b).hexdigest()}"
manifest = bundle / "manifest"
lines = manifest.read_text(encoding="utf-8").splitlines()
for i, line in enumerate(lines):
    if line.startswith(f"CANDIDATE\t{rel}\t"):
        lines[i] = row
        break
else:
    raise SystemExit(f"missing candidate row: {rel}")
manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

prepare_copy() {
  local name="$1"
  cp -R "$WORK/base" "$WORK/$name"
}

# Baseline prepared and verified once.
"$BIN" prepare "$SOURCE" "$DEST" "$WORK/base" >"$WORK/base-prepare.log"
"$BIN" verify "$WORK/base" "$SOURCE" "$DEST" >"$WORK/base-verify.log"
echo "PASS: baseline prepare + verify"

# Duplicate EventId: reseal so the production EventMemory loader, not only the
# manifest fingerprint check, must reject it.
prepare_copy duplicate-event-id
python3 - "$WORK/duplicate-event-id/candidate-root/memory.loam" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
idx=[i for i,x in enumerate(lines) if x.startswith("EVENT\t")]
first=lines[idx[0]].split("\t")[1]
parts=lines[idx[1]].split("\t"); parts[1]=first; lines[idx[1]]="\t".join(parts)
p.write_text("\n".join(lines)+"\n")
PY
reseal_candidate "$WORK/duplicate-event-id" memory.loam
expect_fail duplicate-event-id "production loader rejected candidate memory.loam" \
  "$BIN" verify "$WORK/duplicate-event-id" "$SOURCE" "$DEST"

# Duplicate EffectKey across two Events: production loader accepts each Event,
# then the global candidate identity invariant rejects it.
prepare_copy duplicate-effect-key
python3 - "$WORK/duplicate-effect-key/candidate-root/memory.loam" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
events=[i for i,x in enumerate(lines) if x.startswith("EVENT\t")]
first_effect=next(i for i in range(events[0]+1, events[1]) if lines[i].startswith("EFFECT\t"))
second_effect=next(i for i in range(events[1]+1, events[2]) if lines[i].startswith("EFFECT\t"))
first=lines[first_effect].split("\t")[1]
parts=lines[second_effect].split("\t"); parts[1]=first; lines[second_effect]="\t".join(parts)
p.write_text("\n".join(lines)+"\n")
PY
reseal_candidate "$WORK/duplicate-effect-key" memory.loam
expect_fail duplicate-effect-key "duplicate EffectKey" \
  "$BIN" verify "$WORK/duplicate-effect-key" "$SOURCE" "$DEST"

# Duplicate description EventId.
prepare_copy duplicate-description-event-id
python3 - "$WORK/duplicate-description-event-id/candidate-root/memory.loam.descriptions" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
idx=[i for i,x in enumerate(lines) if x.startswith("DESC\t")]
first=lines[idx[0]].split("\t")[1]
parts=lines[idx[1]].split("\t"); parts[1]=first; lines[idx[1]]="\t".join(parts)
p.write_text("\n".join(lines)+"\n")
PY
reseal_candidate "$WORK/duplicate-description-event-id" memory.loam.descriptions
expect_fail duplicate-description-event-id "production loader rejected candidate descriptions" \
  "$BIN" verify "$WORK/duplicate-description-event-id" "$SOURCE" "$DEST"

# Malformed production description escape.
prepare_copy malformed-description-encoding
python3 - "$WORK/malformed-description-encoding/candidate-root/memory.loam.descriptions" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
for i,x in enumerate(lines):
    if x.startswith("DESC\t"):
        lines[i]=x+r"\q"; break
p.write_text("\n".join(lines)+"\n")
PY
reseal_candidate "$WORK/malformed-description-encoding" memory.loam.descriptions
expect_fail malformed-description-encoding "production loader rejected candidate descriptions" \
  "$BIN" verify "$WORK/malformed-description-encoding" "$SOURCE" "$DEST"

# Candidate fingerprint mismatch without resealing.
prepare_copy candidate-fingerprint-mismatch
printf '\n' >> "$WORK/candidate-fingerprint-mismatch/candidate-root/basis.loam"
expect_fail candidate-fingerprint-mismatch "candidate fingerprint mismatch: basis.loam" \
  "$BIN" verify "$WORK/candidate-fingerprint-mismatch" "$SOURCE" "$DEST"

# Missing candidate production file.
prepare_copy candidate-file-missing
rm "$WORK/candidate-file-missing/candidate-root/memory.loam.actual-validity"
expect_fail candidate-file-missing "candidate file missing: memory.loam.actual-validity" \
  "$BIN" verify "$WORK/candidate-file-missing" "$SOURCE" "$DEST"

# Accidental non-zero origin basis, resealed to reach semantic verification.
prepare_copy nonzero-origin-basis
python3 - "$WORK/nonzero-origin-basis/candidate-root/basis.loam" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
for i,x in enumerate(lines):
    if x.startswith("BASIS\t"):
        parts=x.split("\t"); parts[4]="1"; lines[i]="\t".join(parts); break
p.write_text("\n".join(lines)+"\n")
PY
reseal_candidate "$WORK/nonzero-origin-basis" basis.loam
expect_fail nonzero-origin-basis "non-zero origin basis" \
  "$BIN" verify "$WORK/nonzero-origin-basis" "$SOURCE" "$DEST"

# Wrong prepared source fingerprint.
prepare_copy wrong-source-fingerprint
python3 - "$WORK/wrong-source-fingerprint/manifest" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
lines=["SOURCE-SHA256\t"+"0"*64 if x.startswith("SOURCE-SHA256\t") else x for x in lines]
p.write_text("\n".join(lines)+"\n")
PY
expect_fail wrong-source-fingerprint "SOURCE-DRIFT: stale prepared candidate" \
  "$BIN" verify "$WORK/wrong-source-fingerprint" "$SOURCE" "$DEST"

# Malformed / incomplete manifest.
prepare_copy incomplete-manifest
python3 - "$WORK/incomplete-manifest/manifest" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
lines=[x for x in lines if not x.startswith("SOURCE-BYTES\t")]
p.write_text("\n".join(lines)+"\n")
PY
expect_fail incomplete-manifest "manifest missing or malformed SOURCE-BYTES" \
  "$BIN" verify "$WORK/incomplete-manifest" "$SOURCE" "$DEST"

# Malformed source posting.
cp "$SOURCE" "$WORK/source-malformed-posting.journal"
python3 - "$WORK/source-malformed-posting.journal" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
for i,x in enumerate(lines):
    if x.startswith("    assets:paypay"):
        lines[i]="    malformed posting"; break
p.write_text("\n".join(lines)+"\n")
PY
expect_fail malformed-source-posting "malformed source posting" \
  "$BIN" prepare "$WORK/source-malformed-posting.journal" "$DEST" "$WORK/reject-malformed-posting"

# Unbalanced source event.
cp "$SOURCE" "$WORK/source-unbalanced.journal"
python3 - "$WORK/source-unbalanced.journal" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); s=s.replace("192 JPY", "193 JPY", 1); p.write_text(s)
PY
expect_fail unbalanced-source-event "unbalanced source event" \
  "$BIN" prepare "$WORK/source-unbalanced.journal" "$DEST" "$WORK/reject-unbalanced"

# Invalid source date.
cp "$SOURCE" "$WORK/source-invalid-date.journal"
python3 - "$WORK/source-invalid-date.journal" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); s=s.replace("2026-04-04", "2026-13-40", 1); p.write_text(s)
PY
expect_fail invalid-source-date "invalid source date" \
  "$BIN" prepare "$WORK/source-invalid-date.journal" "$DEST" "$WORK/reject-invalid-date"

# Explicit source EventId collision with the current destination namespace.
cp -R "$DEST" "$WORK/destination-explicit-collision"
rm -rf "$WORK/destination-explicit-collision/.git"
python3 - "$SOURCE" "$WORK/destination-explicit-collision/memory.loam" <<'PY'
from pathlib import Path
import re, sys
source, memory = map(Path, sys.argv[1:])
match = re.search(r'^\s*;\s*event-id:\s*(.+?)\s*$', source.read_text(), re.M)
if not match:
    raise SystemExit('source has no explicit event-id')
with memory.open('a') as f:
    f.write(f"EVENT\t{match.group(1)}\n")
PY
expect_fail explicit-source-event-id-collision "explicit source event-id collides" \
  "$BIN" prepare "$SOURCE" "$WORK/destination-explicit-collision" "$WORK/reject-explicit-collision"

# Source drift after prepare.
cp "$SOURCE" "$WORK/source-drift.journal"
cp -R "$DEST" "$WORK/destination-source-drift"
rm -rf "$WORK/destination-source-drift/.git"
"$BIN" prepare "$WORK/source-drift.journal" "$WORK/destination-source-drift" "$WORK/source-drift-bundle" >/dev/null
printf '\n; changed after prepare\n' >> "$WORK/source-drift.journal"
expect_fail source-changed-after-prepare "SOURCE-DRIFT: stale prepared candidate" \
  "$BIN" verify "$WORK/source-drift-bundle" "$WORK/source-drift.journal" "$WORK/destination-source-drift"

# Destination base drift after prepare.
cp "$SOURCE" "$WORK/source-destination-drift.journal"
cp -R "$DEST" "$WORK/destination-drift-root"
rm -rf "$WORK/destination-drift-root/.git"
"$BIN" prepare "$WORK/source-destination-drift.journal" "$WORK/destination-drift-root" "$WORK/destination-drift-bundle" >/dev/null
printf '\n' >> "$WORK/destination-drift-root/scheduled.loam"
expect_fail destination-base-fingerprint-mismatch "DESTINATION-DRIFT: scheduled.loam changed" \
  "$BIN" verify "$WORK/destination-drift-bundle" "$WORK/source-destination-drift.journal" "$WORK/destination-drift-root"

# Resume/verify must not rewrite or reissue IDs.
before=$(shasum -a 256 "$WORK/base/candidate-root/memory.loam" | awk '{print $1}')
"$BIN" verify "$WORK/base" "$SOURCE" "$DEST" >/dev/null
"$BIN" verify "$WORK/base" "$SOURCE" "$DEST" >/dev/null
after=$(shasum -a 256 "$WORK/base/candidate-root/memory.loam" | awk '{print $1}')
[[ "$before" == "$after" ]] || { echo "FAIL: resume rewrote candidate identities" >&2; exit 1; }
echo "PASS: prepared resume / verify reissued 0 identities"

# Independent prepare is allowed to issue a different anonymous identity image;
# both candidates must independently verify against the same semantics/source.
"$BIN" prepare "$SOURCE" "$DEST" "$WORK/independent-b" >/dev/null
"$BIN" verify "$WORK/independent-b" "$SOURCE" "$DEST" >/dev/null
sha_a=$(shasum -a 256 "$WORK/base/candidate-root/memory.loam" | awk '{print $1}')
sha_b=$(shasum -a 256 "$WORK/independent-b/candidate-root/memory.loam" | awk '{print $1}')
[[ "$sha_a" != "$sha_b" ]] || { echo "FAIL: independent prepare unexpectedly reused identity image" >&2; exit 1; }
echo "PASS: independent prepare identities differ; semantic verification passes"

echo "PASS: all historical prepare / verify specimens"
