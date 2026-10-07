#!/usr/bin/env bash
# EditForth release helper (ROADMAP §1 v1).
# Public domain.
#
# Usage:
#   ./scripts/release.sh validate
#   ./scripts/release.sh emit-smoke
#   ./scripts/release.sh bump <marketing> <build> [--stamp "Mon D, YYYY h:mm AM/PM"]
#   ./scripts/release.sh archive
#   ./scripts/release.sh dmg [--force] [--out /tmp/test.dmg]
#   ./scripts/release.sh prep <marketing> <build> [--stamp "..."] [--force]
#
# Never trashes old DMGs, never git commit/push, never gh release create.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/release-common.sh
source "$SCRIPT_DIR/lib/release-common.sh"

usage() {
  cat <<EOF
EditForth release helper

  validate              ANS-VALIDATE + Hayes against resolved 64Forth.app
  emit-smoke            EMIT Sample/VED64.fth; require VED64.app
  bump <ver> <build>    Lockstep version stamps (+ optional --stamp)
  archive               Archive EditForth (+64Forth if needed); stage apps
  dmg [--force]         Build Releases/EditForth-<ver>-macOS.dmg
  prep <ver> <build>    bump → archive → validate → emit-smoke → dmg

Options:
  --stamp "..."         Banner date/time for bump/prep
  --force               Overwrite same-version DMG if present
  --out PATH            Write DMG to PATH instead of Releases/
  --skip-validate       prep: skip ANS/Hayes (debug only)
  --skip-emit           prep: skip VED64 emit smoke
  -h, --help            This help

Does NOT trash old DMGs, commit, push, or create GitHub releases.
EOF
}

cmd_validate() {
  local ans_log="$LOG_DIR/ans-validate.txt"
  local hayes_log="$LOG_DIR/hayes.txt"
  local app
  app=$(resolve_forth_app)
  note "Using $app"
  note "=== ANS-VALIDATE ==="
  run_agent "$ans_log" -e 'FROMLIB FLOAD ANSValidate/ANS-VALIDATE.fth'
  check_ans_validate "$ans_log"
  note "=== Hayes ==="
  run_agent "$hayes_log" -e 'FROMLIB FLOAD HayesTest/HayesTest.fth'
  check_hayes "$hayes_log"
  ok "validate complete"
}

cmd_emit_smoke() {
  local log="$LOG_DIR/emit-ved64.txt"
  local app
  app=$(resolve_forth_app)
  note "Using $app"
  mkdir -p "$DOCUMENTS_EDITFORTH"
  rm -rf "$DOCUMENTS_EDITFORTH/VED64.app" \
         "$DOCUMENTS_EDITFORTH/VED64.img" \
         "$DOCUMENTS_EDITFORTH/VED64.emit.log"
  # Bundle path inside the app under test (shipped Sample).
  local sample="$app/Contents/Resources/Library/Sample/VED64.fth"
  [[ -f "$sample" ]] || die "missing Sample in app: $sample"
  note "=== EMIT VED64 ==="
  # INCLUDE then EMIT-AUTO-FILE (same idea as editor EMIT Current).
  # cwd for emit artifacts is Documents/EditForth when companion boots there;
  # agent may start in $HOME — chdir via --cwd.
  run_agent "$log" \
    --cwd "$DOCUMENTS_EDITFORTH" \
    -e "EMIT-FLAGS-RESET ANEW VED64_MODULE S\" $sample\" INCLUDED S\" $sample\" EMIT-AUTO-FILE"
  check_emit_ved64 "$log"
  ok "emit-smoke complete"
}

# --- bump -----------------------------------------------------------------

replace_all() {
  local file="$1" old="$2" new="$3"
  [[ -f "$file" ]] || die "missing $file"
  if grep -qF "$old" "$file"; then
    # portable in-place: write temp
    local tmp
    tmp=$(mktemp)
    # Escape for sed - use perl for literal replace
    perl -pe 'BEGIN { $o=shift; $n=shift } s/\Q$o\E/$n/g' "$old" "$new" <"$file" >"$tmp"
    mv "$tmp" "$file"
  fi
}

cmd_bump() {
  local ver="${1:-}" build="${2:-}"
  shift 2 || true
  local stamp=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stamp) stamp="${2:-}"; shift 2 ;;
      *) die "bump: unknown arg $1" ;;
    esac
  done
  [[ -n "$ver" && -n "$build" ]] || die "usage: bump <marketing> <build> [--stamp \"...\"]"
  if [[ -z "$stamp" ]]; then
    stamp=$(date '+%b %-d, %Y %-I:%M %p')
  fi
  local old_ver old_build
  old_ver=$(read_marketing_version)
  old_build=$(read_build_number)
  note "bump $old_ver/$old_build → $ver/$build"
  note "stamp: $stamp"

  # pbxproj — all MARKETING_VERSION / CURRENT_PROJECT_VERSION
  perl -i -pe "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $ver;/g" \
    "$ROOT/EditForth.xcodeproj/project.pbxproj"
  perl -i -pe "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $build;/g" \
    "$ROOT/EditForth.xcodeproj/project.pbxproj"

  # Forth Info.plist
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $ver" "$ROOT/Forth/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$ROOT/Forth/Info.plist"

  # Banners
  perl -i -pe "s/static let stamp = \".*\"/static let stamp = \"$stamp\"/" \
    "$ROOT/Editor/EditForthConsoleBanner.swift"
  # Fallback version string in banner enum
  perl -i -pe "s/\\?\\? \"[0-9.]+\"/?? \"$ver\"/" \
    "$ROOT/Editor/EditForthConsoleBanner.swift" || true
  perl -i -pe "s/=== 64Forth [0-9.]+ === .* ===/=== 64Forth $ver === $stamp ===/" \
    "$ROOT/Forth/App/ConsoleView.swift"

  # Docs — Current line + light README/DESIGN/Agent-channel version mentions
  if [[ -f "$ROOT/Forth/Resources/Docs/STATUS.md" ]]; then
    perl -i -pe "s/^\\*\\*Current:\\*\\*.*/**Current:** **$ver** (build **$build**) — (release prep)  /" \
      "$ROOT/Forth/Resources/Docs/STATUS.md" || true
  fi
  if [[ -f "$ROOT/README.md" ]]; then
    perl -i -pe "s/\\*\\*Version:\\*\\* \\*\\*[0-9.]+\\*\\* \\(build \\*\\*[0-9]+\\*\\*)/**Version:** **$ver** (build **$build**)/" \
      "$ROOT/README.md" || true
  fi
  if [[ -f "$ROOT/DESIGN.md" ]]; then
    perl -i -pe "s/Marketing \\*\\*[0-9.]+\\*\\* \\/ build \\*\\*[0-9]+\\*\\*/Marketing **$ver** \\/ build **$build**/" \
      "$ROOT/DESIGN.md" || true
  fi
  if [[ -f "$ROOT/Forth/Resources/Docs/Agent-channel.md" ]]; then
    # e.g. current **2.0.2**, build **3**, banner `…`
    perl -i -pe "s/current \\*\\*[0-9.]+\\*\\*, build \\*\\*[0-9]+\\*\\*, banner \`[^\`]*\`/current **$ver**, build **$build**, banner \`$stamp\`/" \
      "$ROOT/Forth/Resources/Docs/Agent-channel.md" || true
  fi

  ok "bumped to $ver / $build"
  note "Touched: pbxproj, Forth/Info.plist, banners, STATUS/README/DESIGN/Agent-channel (best-effort)"
  note "Review STATUS section text before shipping."
}

# --- archive --------------------------------------------------------------

copy_app_from_archive() {
  local archive="$1" name="$2" dest_dir="$3"
  local src="$archive/Products/Applications/$name"
  [[ -d "$src" ]] || return 1
  rm -rf "$dest_dir/$name"
  ditto --norsrc "$src" "$dest_dir/$name"
  ok "staged $name from $(basename "$archive")"
  return 0
}

cmd_archive() {
  require_cmd xcodebuild
  mkdir -p "$BUILD_ROOT" "$STAGE_APPS"
  rm -rf "$ARCHIVE_PATH" "$ARCHIVE_64" "$STAGE_APPS"
  mkdir -p "$STAGE_APPS"

  note "=== Archive EditForth ==="
  xcodebuild \
    -project "$ROOT/EditForth.xcodeproj" \
    -scheme EditForth \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    | tee "$LOG_DIR/archive-editforth.txt" \
    | tail -20

  if ! copy_app_from_archive "$ARCHIVE_PATH" "EditForth.app" "$STAGE_APPS"; then
    die "EditForth.app missing from archive"
  fi

  if ! copy_app_from_archive "$ARCHIVE_PATH" "64Forth.app" "$STAGE_APPS"; then
    note "64Forth.app not in EditForth archive — archiving 64Forth scheme"
    xcodebuild \
      -project "$ROOT/EditForth.xcodeproj" \
      -scheme 64Forth \
      -configuration Release \
      -archivePath "$ARCHIVE_64" \
      archive \
      | tee "$LOG_DIR/archive-64forth.txt" \
      | tail -20
    copy_app_from_archive "$ARCHIVE_64" "64Forth.app" "$STAGE_APPS" \
      || die "64Forth.app missing from 64Forth archive"
  fi

  [[ -d "$STAGE_APPS/EditForth.app" && -d "$STAGE_APPS/64Forth.app" ]] \
    || die "stage incomplete under $STAGE_APPS"

  # Drop archives after extract (apps kept in STAGE_APPS)
  rm -rf "$ARCHIVE_PATH" "$ARCHIVE_64"
  ok "archive → $STAGE_APPS"
}

# --- dmg ------------------------------------------------------------------

cmd_dmg() {
  local force=0 out=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=1; shift ;;
      --out) out="${2:-}"; shift 2 ;;
      *) die "dmg: unknown arg $1" ;;
    esac
  done
  local ver
  ver=$(read_marketing_version)
  local dest
  if [[ -n "$out" ]]; then
    dest="$out"
  else
    dest="$RELEASES/$(dmg_name_for_version "$ver")"
  fi
  if [[ -f "$dest" && "$force" -ne 1 ]]; then
    die "DMG exists: $dest (pass --force to replace this version only)"
  fi
  [[ -d "$STAGE_APPS/EditForth.app" && -d "$STAGE_APPS/64Forth.app" ]] \
    || die "missing staged apps — run archive first ($STAGE_APPS)"

  local jpg="$RELEASES/Getting EditForth to run.jpg"
  local pdf="$RELEASES/README.pdf"
  [[ -f "$jpg" ]] || die "missing $jpg"
  [[ -f "$pdf" ]] || die "missing $pdf"

  rm -rf "$STAGE_DMG"
  mkdir -p "$STAGE_DMG"
  ditto --norsrc "$STAGE_APPS/EditForth.app" "$STAGE_DMG/EditForth.app"
  ditto --norsrc "$STAGE_APPS/64Forth.app" "$STAGE_DMG/64Forth.app"
  cp "$jpg" "$STAGE_DMG/"
  cp "$pdf" "$STAGE_DMG/"

  create_dmg_from_folder "$STAGE_DMG" "$dest" "EditForth $ver"
  rm -rf "$STAGE_DMG"
  print_handoff "$dest"
}

# --- prep -----------------------------------------------------------------

cmd_prep() {
  local ver="${1:-}" build="${2:-}"
  shift 2 || true
  local stamp="" force=0 skip_validate=0 skip_emit=0
  local bump_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stamp) stamp="${2:-}"; bump_args+=(--stamp "$stamp"); shift 2 ;;
      --force) force=1; shift ;;
      --skip-validate) skip_validate=1; shift ;;
      --skip-emit) skip_emit=1; shift ;;
      *) die "prep: unknown arg $1" ;;
    esac
  done
  [[ -n "$ver" && -n "$build" ]] || die "usage: prep <marketing> <build> [options]"

  cmd_bump "$ver" "$build" "${bump_args[@]+"${bump_args[@]}"}"
  cmd_archive
  if [[ "$skip_validate" -eq 0 ]]; then
    cmd_validate
  else
    note "skipping validate"
  fi
  if [[ "$skip_emit" -eq 0 ]]; then
    cmd_emit_smoke
  else
    note "skipping emit-smoke"
  fi
  if [[ "$force" -eq 1 ]]; then
    cmd_dmg --force
  else
    cmd_dmg
  fi
}

# --- main -----------------------------------------------------------------

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    validate) cmd_validate "$@" ;;
    emit-smoke) cmd_emit_smoke "$@" ;;
    bump) cmd_bump "$@" ;;
    archive) cmd_archive "$@" ;;
    dmg) cmd_dmg "$@" ;;
    prep) cmd_prep "$@" ;;
    -h|--help|help|"") usage ;;
    *) die "unknown command: $cmd (try --help)" ;;
  esac
}

main "$@"
