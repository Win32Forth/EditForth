# shellcheck shell=bash
# Shared helpers for EditForth scripts/release.sh
# Public domain.

set -euo pipefail

_EF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$_EF_LIB_DIR/../.." && pwd)"
RELEASES="$ROOT/Releases"
BUILD_ROOT="$ROOT/build/release"
STAGE_APPS="$BUILD_ROOT/apps"
STAGE_DMG="$BUILD_ROOT/dmg-stage"
ARCHIVE_PATH="$BUILD_ROOT/EditForth.xcarchive"
ARCHIVE_64="$BUILD_ROOT/64Forth.xcarchive"
LOG_DIR="${TMPDIR:-/tmp}/editforth-release"
mkdir -p "$LOG_DIR"
shopt -s nullglob 2>/dev/null || true

# Prefer Xcode-beta when present (matches local EditForth practice).
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  fi
fi

DOCUMENTS_EDITFORTH="${HOME}/Documents/EditForth"

die() { echo "error: $*" >&2; exit 1; }
note() { echo "$*"; }
ok() { echo "OK  $*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

# Marketing version from pbxproj (first MARKETING_VERSION =).
read_marketing_version() {
  local v
  v=$(grep -m1 'MARKETING_VERSION =' "$ROOT/EditForth.xcodeproj/project.pbxproj" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/' | tr -d ' ')
  [[ -n "$v" ]] || die "cannot read MARKETING_VERSION"
  echo "$v"
}

read_build_number() {
  local v
  v=$(grep -m1 'CURRENT_PROJECT_VERSION =' "$ROOT/EditForth.xcodeproj/project.pbxproj" \
    | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);/\1/' | tr -d ' ')
  [[ -n "$v" ]] || die "cannot read CURRENT_PROJECT_VERSION"
  echo "$v"
}

dmg_name_for_version() {
  echo "EditForth-$1-macOS.dmg"
}

# Resolve 64Forth.app to validate/emit against.
# Order: staged archive apps → DerivedData Release → DerivedData Debug.
resolve_forth_app() {
  local candidates=(
    "$STAGE_APPS/64Forth.app"
    "$ROOT/DerivedData/EditForth-release/Build/Products/Release/64Forth.app"
    "$ROOT/DerivedData/EditForth-debug/Build/Products/Debug/64Forth.app"
  )
  local dd
  for dd in "$ROOT"/DerivedData/*/Build/Products/*/64Forth.app; do
    [[ -d "$dd" ]] && candidates+=("$dd")
  done
  local c
  for c in "${candidates[@]}"; do
    if [[ -x "$c/Contents/MacOS/64Forth" ]]; then
      echo "$c"
      return 0
    fi
  done
  die "no 64Forth.app found (run archive or build Debug/Release first)"
}

forth_bin() {
  local app
  app=$(resolve_forth_app)
  echo "$app/Contents/MacOS/64Forth"
}

run_agent() {
  local out="$1"
  shift
  local bin
  bin=$(forth_bin)
  note "agent: $bin $*"
  # --autoload loads Emitter so EMIT-AUTO-FILE exists for emit-smoke
  "$bin" --agent --autoload "$@" -o "$out"
}

transcript_has() {
  local file="$1"
  local pat="$2"
  grep -qE "$pat" "$file"
}

check_ans_validate() {
  local log="$1"
  transcript_has "$log" 'ALL PASS' || die "ANS-VALIDATE: missing ALL PASS (see $log)"
  transcript_has "$log" '0 failed' || die "ANS-VALIDATE: missing 0 failed (see $log)"
  if grep -q "can't open:" "$log"; then
    die "ANS-VALIDATE: can't open: in transcript (see $log)"
  fi
  # Host wave prints undefined: BADSELF on purpose before CATCH; uncaught is bad.
  if grep -q 'uncaught THROW' "$log"; then
    die "ANS-VALIDATE: uncaught THROW (see $log)"
  fi
  ok "ANS-VALIDATE"
}

check_hayes() {
  local log="$1"
  # Mid-run "********** HAYES FAIL **********" banners are expected from
  # exception/string self-tests (CATCH/THROW, etc.). Only the HayesTest.fth
  # final summary counts: PASS vs FAILURES DETECTED.
  if grep -qE '\*\*\* HAYES:.*FAILURES DETECTED' "$log"; then
    die "Hayes: FAILURES DETECTED (see $log)"
  fi
  transcript_has "$log" 'HAYES: ALL COUNTS ZERO — PASS' \
    || transcript_has "$log" 'ALL COUNTS ZERO — PASS' \
    || die "Hayes: missing ALL COUNTS ZERO — PASS (see $log)"
  ok "Hayes"
}

check_emit_ved64() {
  local log="$1"
  local outdir="$DOCUMENTS_EDITFORTH/Library/Sample/VED64"
  local app="$outdir/VED64.app"
  local emitlog="$outdir/VED64.emit.log"
  [[ -d "$app" ]] || die "emit-smoke: missing $app (see $log)"
  if [[ -f "$emitlog" ]] && grep -qiE 'ABORT"|Emit failed|uncaught THROW|can.t open' "$emitlog"; then
    die "emit-smoke: failure markers in $emitlog"
  fi
  if grep -q 'Emit failed' "$log"; then
    die "emit-smoke: Emit failed in agent transcript (see $log)"
  fi
  if grep -q 'Emitted ' "$log"; then
    ok "VED64 emit (Emitted line)"
  else
    ok "VED64 emit (.app present)"
  fi
}

create_dmg_from_folder() {
  local src="$1"
  local dest="$2"
  local volname="$3"
  require_cmd diskutil
  rm -f "$dest"
  # UDZO = zlib compressed read-only (good for GitHub assets)
  diskutil image create from --format UDZO --volumeName "$volname" "$src" "$dest"
  [[ -f "$dest" ]] || die "DMG not created: $dest"
  ok "DMG $dest"
}

print_handoff() {
  local ver dmg
  ver=$(read_marketing_version)
  dmg="${1:-$RELEASES/$(dmg_name_for_version "$ver")}"
  cat <<EOF

======== handoff ========
DMG ready: $dmg
Next (human):
  1. Trash older Releases/EditForth-*-macOS.dmg (keep the new one)
  2. Spot-check mount / Gatekeeper collage
  3. Ask agent: commit, push, GitHub release v${ver}
Do not stage HYPER.NDX.
=========================
EOF
}
