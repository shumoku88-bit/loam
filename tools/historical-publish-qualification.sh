#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: historical-publish-qualification.sh PREPARE_BIN PUBLISH_BIN DAILY_BIN WORK_ROOT" >&2
  exit 2
fi
prepare_bin="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
publish_bin="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
daily_bin="$(cd "$(dirname "$3")" && pwd)/$(basename "$3")"
root="$(cd "$(dirname "$4")" && pwd)/$(basename "$4")"
rm -rf "$root"
mkdir -p "$root/source" "$root/destination"
source="$root/source/current-actual.journal"
dest="$root/destination"
bundle="$root/PREPARED"

python3 - "$source" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
cardinalities = [2] * 521 + [3] * 34 + [4] * 2 + [5]
seeded = {
    1: [("assets:cash", 100), ("equity:synthetic", -100)],
    2: [("assets:paypay", 200), ("equity:synthetic", -200)],
    3: [("assets:smbc", 300), ("equity:synthetic", -300)],
    4: [("assets:ゆうちょ", 400), ("equity:synthetic", -400)],
    5: [("assets:オルカン積立", 500), ("equity:synthetic", -500)],
}
lines = ["include accounts.journal", ""]
for i, count in enumerate(cardinalities, 1):
    lines.append(f"2026-04-04 synthetic-{i}")
    if i == 490:
        lines.append("    ; event-id: synthetic-explicit-actual")
    if i <= 20:
        lines.append(f"    ; plan-id: synthetic-plan-{i}")
    posts = seeded.get(i)
    if posts is None:
        posts = [(f"expenses:synthetic:{j}", 1) for j in range(count - 1)]
        posts.append(("equity:synthetic", -(count - 1)))
    for account, quantity in posts:
        lines.append(f"    {account}  {quantity} JPY")
    lines.append("")
out.write_text("\n".join(lines), encoding="utf-8")
PY

cat >"$dest/memory.loam" <<'EOF'
LOAM-EVENT-MEMORY	1
EVENT	old-root
EFFECT	old-effect	cash	jpy	5
EVENT	old-replacement
EFFECT	old-replacement-effect	cash	jpy	9
EOF
cat >"$dest/memory.loam.actual-validity" <<'EOF'
LOAM-ACTUAL-VALIDITY-HISTORY	1
FACT	old-v0	old-root	2025-01-01
FACT	old-v1	old-replacement	2025-01-02
EOF
cat >"$dest/corrections.loam" <<'EOF'
LOAM-EVENT-CORRECTION-MEMORY	1
CORRECTION	old-correction	old-root	old-replacement
EOF
cat >"$dest/basis.loam" <<'EOF'
LOAM-QUANTITY-BASIS-MEMORY	1
BASIS	old-basis	cash	jpy	10
BASIS	old-paypay	paypay	jpy	0
BASIS	old-smbc	smbc	jpy	0
BASIS	old-yucho	yucho	jpy	0
BASIS	old-all-country	all-country	jpy	0
EOF
printf 'old-basis\told-root\n' >"$dest/basis-cut.tsv"
cat >"$dest/balance-view.tsv" <<'EOF'
cash	jpy
paypay	jpy
smbc	jpy
yucho	jpy
all-country	jpy
EOF
{
  printf 'LOAM-SCHEDULED-MEMORY\t1\n'
  for i in $(seq 1 11); do
    printf 'SCHEDULED\tscheduled-%s\t2030-01-%02d\tjpy\n' "$i" "$i"
    printf 'CHANGE\tfuture-source\t-1\nCHANGE\tfuture-use\t1\n'
  done
} >"$dest/scheduled.loam"

source_sha="$(shasum -a 256 "$source" | awk '{print $1}')"
"$prepare_bin" prepare "$source" "$dest" "$bundle" "$source_sha" >"$root/prepare.out"
manifest_sha="$(shasum -a 256 "$bundle/manifest" | awk '{print $1}')"
source_before="$(shasum -a 256 "$source" | awk '{print $1}')"
mkdir "$root/template-destination" "$root/template-prepared"
cp -a "$dest/." "$root/template-destination/"
cp -a "$bundle/." "$root/template-prepared/"
cp -a "$source" "$root/template-source"
identity_before="$(find "$root/template-prepared/candidate-root" -type f -print0 | sort -z | xargs -0 shasum -a 256 | awk '{print $1}' | shasum -a 256 | awk '{print $1}')"
scheduled_before="$(shasum -a 256 "$dest/scheduled.loam" | awk '{print $1}')"
view_before="$(shasum -a 256 "$dest/balance-view.tsv" | awk '{print $1}')"
"$daily_bin" balances \
  "$bundle/candidate-root/memory.loam" "$bundle/candidate-root/corrections.loam" \
  "$bundle/candidate-root/basis.loam" "$bundle/candidate-root/basis-corrections.loam" \
  "$bundle/candidate-root/balance-view.tsv" "$bundle/candidate-root/basis-cut.tsv" \
  >"$root/expected-balances"

reset_case() {
  rm -rf "$dest" "$bundle"
  mkdir -p "$dest" "$bundle"
  cp -a "$root/template-destination/." "$dest/"
  cp -a "$root/template-prepared/." "$bundle/"
  cp -a "$root/template-source" "$source"
}

run_crash_case() {
  local label="$1" expected="$2" out="$root/crash-$1.out"
  reset_case
  set +e
  LOAM_HISTORICAL_PUBLISH_CRASH_AFTER="$label" \
    "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$out" 2>&1
  local rc=$?
  set -e
  [[ $rc -eq 86 ]] || { echo "FAIL: $label did not inject process exit 86 (got $rc)" >&2; exit 1; }
  if [[ -d "$bundle/candidate-root" ]]; then
    local identity_after
    identity_after="$(find "$bundle/candidate-root" -type f -print0 | sort -z | xargs -0 shasum -a 256 | awk '{print $1}' | shasum -a 256 | awk '{print $1}')"
    [[ "$identity_after" == "$identity_before" ]] || { echo "FAIL: $label changed candidate identity" >&2; exit 1; }
  fi
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/restart-$label.out" 2>&1
  grep -Fq "$expected" "$root/restart-$label.out" || {
    echo "FAIL: $label restart did not report $expected" >&2; cat "$root/restart-$label.out" >&2; exit 1;
  }
  [[ ! -e "$bundle" ]] || { echo "FAIL: $label left PREPARED after recovery" >&2; exit 1; }
  [[ ! -e "$dest/corrections.loam" && ! -e "$dest/basis-cut.tsv" ]] || {
    echo "FAIL: $label did not retire old streams" >&2; exit 1;
  }
}

run_crash_case before-v1 ResumePreCommitPublication
run_crash_case v1 ResumePreCommitPublication
run_crash_case d1 ResumePreCommitPublication
run_crash_case b1 ResumePreCommitPublication
run_crash_case s1 ResumePreCommitPublication
run_crash_case e1 ResumePostCommitRetirement
run_crash_case c0-retired ResumePostCommitRetirement
run_crash_case k0-retired ResumePostCommitRetirement
run_crash_case final-verified RecoverReceiptOnly
run_crash_case receipt CleanupLeftoverPrepared
run_crash_case prepared-cleanup 'RestartAction.complete'

echo "PASS: all crash boundaries recover without identity reissuance"

# Final scratch parity and no-rewrite checks.
"$daily_bin" balances \
  "$dest/memory.loam" "$dest/corrections.loam" "$dest/basis.loam" \
  "$dest/basis-corrections.loam" "$dest/balance-view.tsv" "$dest/basis-cut.tsv" \
  >"$root/final-balances"
diff -u "$root/expected-balances" "$root/final-balances"
[[ "$(shasum -a 256 "$dest/scheduled.loam" | awk '{print $1}')" == "$scheduled_before" ]]
[[ "$(shasum -a 256 "$dest/balance-view.tsv" | awk '{print $1}')" == "$view_before" ]]
[[ "$(shasum -a 256 "$source" | awk '{print $1}')" == "$source_before" ]]
echo "PASS: CurrentQuantity parity, source immutability, and no-rewrite fingerprints"

expect_refuse() {
  local name="$1"
  shift
  reset_case
  "$@"
  if "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/negative-$name.out" 2>&1; then
    echo "FAIL: negative specimen accepted: $name" >&2
    exit 1
  fi
}

expect_refuse e1-v0 cp "$bundle/candidate-root/memory.loam" "$dest/memory.loam"
expect_refuse e0-k-absent rm "$dest/basis-cut.tsv"
expect_refuse candidate-fingerprint-mismatch bash -c \
  'cp "$1/candidate-root/memory.loam" "$2/memory.loam"; cp "$1/candidate-root/basis.loam" "$2/basis.loam"; printf "unexpected" >>"$2/basis.loam"' _ "$bundle" "$dest"
expect_refuse c0-unexpected-bytes bash -c 'printf "unexpected\n" >>"$1/corrections.loam"' _ "$dest"
expect_refuse k0-unexpected-bytes bash -c 'printf "unexpected\n" >>"$1/basis-cut.tsv"' _ "$dest"

reset_case
set +e
LOAM_HISTORICAL_PUBLISH_CRASH_AFTER=receipt \
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >/dev/null 2>&1
[[ $? -eq 86 ]] || exit 1
set -e
cp "$root/template-destination/corrections.loam" "$dest/corrections.loam"
if "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/negative-receipt-c0.out" 2>&1; then
  echo "FAIL: Receipt with C0 present accepted" >&2; exit 1
fi

reset_case
set +e
LOAM_HISTORICAL_PUBLISH_CRASH_AFTER=receipt \
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >/dev/null 2>&1
[[ $? -eq 86 ]] || exit 1
set -e
cp "$root/template-destination/basis-cut.tsv" "$dest/basis-cut.tsv"
if "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/negative-receipt-k0.out" 2>&1; then
  echo "FAIL: Receipt with K0 present accepted" >&2; exit 1
fi

reset_case
set +e
LOAM_HISTORICAL_PUBLISH_CRASH_AFTER=receipt \
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >/dev/null 2>&1
[[ $? -eq 86 ]] || exit 1
set -e
rm "$dest/historical-admission/actual.journal.snapshot"
if "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/negative-receipt-snapshot.out" 2>&1; then
  echo "FAIL: Receipt with missing snapshot accepted" >&2; exit 1
fi

reset_case
rm -rf "$bundle"
if "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/negative-prepared-missing.out" 2>&1; then
  echo "FAIL: PREPARED missing before Receipt accepted" >&2; exit 1
fi
reset_case
if "$publish_bin" publish "$bundle" "$source" "$dest" "$(printf '0%.0s' {1..64})" >"$root/negative-approval.out" 2>&1; then
  echo "FAIL: manifest approval mismatch accepted" >&2; exit 1
fi
echo "PASS: all unknown/mixed and approval negative specimens refused"

# Source authority boundary specimens:
# 1. Precommit source missing refuses without committing E1
reset_case
set +e
LOAM_HISTORICAL_PUBLISH_CRASH_AFTER=s1 \
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >/dev/null 2>&1
[[ $? -eq 86 ]] || exit 1
set -e
rm "$source"
if "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/precommit-source-missing.out" 2>&1; then
  echo "FAIL: precommit source missing was accepted" >&2; exit 1
fi
dest_e="$(shasum -a 256 "$dest/memory.loam" | awk '{print $1}')"
dest_e_orig="$(shasum -a 256 "$root/template-destination/memory.loam" | awk '{print $1}')"
[[ "$dest_e" == "$dest_e_orig" ]] || { echo "FAIL: E1 was committed despite missing source" >&2; exit 1; }
echo "PASS: precommit source missing refuses without committing E1"

# 2. Postcommit source missing recovers to full completion
reset_case
set +e
LOAM_HISTORICAL_PUBLISH_CRASH_AFTER=e1 \
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >/dev/null 2>&1
[[ $? -eq 86 ]] || exit 1
set -e
rm "$source"
"$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/restart-e1-no-source.out" 2>&1
grep -Fq "ResumePostCommitRetirement" "$root/restart-e1-no-source.out" || {
  echo "FAIL: post-E1 restart without source did not report ResumePostCommitRetirement" >&2
  cat "$root/restart-e1-no-source.out" >&2
  exit 1
}
[[ ! -e "$bundle" ]] || { echo "FAIL: post-E1 restart left PREPARED" >&2; exit 1; }
[[ ! -e "$dest/corrections.loam" && ! -e "$dest/basis-cut.tsv" ]] || {
  echo "FAIL: post-E1 restart did not retire old streams" >&2; exit 1;
}
echo "PASS: postcommit source missing recovers to full completion"

# 3. Postcommit source changed recovers to full completion
reset_case
set +e
LOAM_HISTORICAL_PUBLISH_CRASH_AFTER=e1 \
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >/dev/null 2>&1
[[ $? -eq 86 ]] || exit 1
set -e
printf "drift after authority commit\n" >>"$source"
"$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/restart-e1-drift-source.out" 2>&1
grep -Fq "ResumePostCommitRetirement" "$root/restart-e1-drift-source.out" || {
  echo "FAIL: post-E1 restart with modified source did not report ResumePostCommitRetirement" >&2
  cat "$root/restart-e1-drift-source.out" >&2
  exit 1
}
[[ ! -e "$bundle" ]] || { echo "FAIL: post-E1 restart left PREPARED" >&2; exit 1; }
echo "PASS: postcommit source drift recovers to full completion"

# 4. RecoverReceiptOnly without source completes
reset_case
set +e
LOAM_HISTORICAL_PUBLISH_CRASH_AFTER=final-verified \
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >/dev/null 2>&1
[[ $? -eq 86 ]] || exit 1
set -e
rm "$source"
"$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/restart-receipt-no-source.out" 2>&1
grep -Fq "RecoverReceiptOnly" "$root/restart-receipt-no-source.out" || {
  echo "FAIL: final-verified restart without source did not report RecoverReceiptOnly" >&2
  cat "$root/restart-receipt-no-source.out" >&2
  exit 1
}
[[ ! -e "$bundle" ]] || { echo "FAIL: final-verified restart left PREPARED" >&2; exit 1; }
echo "PASS: RecoverReceiptOnly without source completes"

# 5. Completed state verification without source
reset_case
"$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/first-complete.out" 2>&1
[[ ! -e "$bundle" ]] || { echo "FAIL: first publish left PREPARED" >&2; exit 1; }
rm "$source"
"$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/complete-no-source.out" 2>&1
grep -Fq "RestartAction.complete" "$root/complete-no-source.out" || {
  echo "FAIL: completed state without source did not report complete" >&2
  cat "$root/complete-no-source.out" >&2
  exit 1
}
echo "PASS: completed state verification without source"

# 6. Completed state with damaged archived snapshot refuses
cp "$root/template-source" "$source"
printf "damaged-archived-snapshot\n" >>"$dest/historical-admission/actual.journal.snapshot"
if "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/damaged-snapshot.out" 2>&1; then
  echo "FAIL: completed state with damaged archived snapshot was accepted" >&2
  exit 1
fi
echo "PASS: completed state with damaged archived snapshot refuses"

# Two processes contend for the existing OS writer lock.  The second cannot
# inspect/publish until the deliberately held first process exits.
reset_case
set +e
LOAM_HISTORICAL_PUBLISH_HOLD_MILLIS=1500 \
LOAM_HISTORICAL_PUBLISH_CRASH_AFTER=before-v1 \
  "$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/lock-first.out" 2>&1 &
first_pid=$!
sleep 0.2
start_ms="$(python3 -c 'import time; print(int(time.monotonic()*1000))')"
"$publish_bin" publish "$bundle" "$source" "$dest" "$manifest_sha" >"$root/lock-second.out" 2>&1
end_ms="$(python3 -c 'import time; print(int(time.monotonic()*1000))')"
wait "$first_pid"
first_rc=$?
set -e
[[ $first_rc -eq 86 ]]
[[ $((end_ms-start_ms)) -ge 1000 ]] || { echo "FAIL: second publisher bypassed writer ownership" >&2; exit 1; }
echo "PASS: writer exclusion"

echo "PASS: scratch Historical Actual publisher qualification complete"
