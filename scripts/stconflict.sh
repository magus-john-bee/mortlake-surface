#!/usr/bin/env bash
# stconflict — find and resolve Syncthing .sync-conflict files interactively.
#
# Usage:
#   stconflict [directory]          # interactive resolution (default: .)
#   stconflict [directory] --kill   # delete all conflict files, keep originals
#   stconflict [directory] --list   # just list conflicts, no action
#
# Requires: delta (for diffs), fzf (optional, for file selection).
set -euo pipefail

DIR="."
MODE="interactive"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --kill)
    MODE="kill"
    shift
    ;;
  --list)
    MODE="list"
    shift
    ;;
  *)
    DIR="$1"
    shift
    ;;
  esac
done

# Find all sync-conflict files
conflicts=()
while IFS= read -r f; do
  conflicts+=("$f")
done < <(find "$DIR" -name '*.sync-conflict-*' -type f 2>/dev/null | sort)

if [[ ${#conflicts[@]} -eq 0 ]]; then
  echo "No .sync-conflict files found in $DIR"
  exit 0
fi

# Strip the Syncthing conflict suffix to recover the original filename.
# Pattern: .sync-conflict-YYYYMMDD-HHMMSS-XXX[.ext]
get_original() {
  sed -E 's/\.sync-conflict-[0-9]{8}-[0-9]{6}-[A-Z0-9]+//' <<<"$1"
}

# ── --list mode ──
if [[ $MODE == "list" ]]; then
  for f in "${conflicts[@]}"; do
    orig=$(get_original "$f")
    echo "  conflict: $f"
    echo "  original: $orig"
    echo
  done
  echo "${#conflicts[@]} conflict(s) found."
  exit 0
fi

# ── --kill mode ──
if [[ $MODE == "kill" ]]; then
  echo "Deleting ${#conflicts[@]} conflict file(s), keeping originals:"
  for f in "${conflicts[@]}"; do
    echo "  rm $f"
    rm "$f"
  done
  echo "Done. All conflicts force-resolved (local/original wins)."
  exit 0
fi

# ── interactive mode ──
echo "${#conflicts[@]} conflict(s) found in $DIR"
echo

resolved=0
skipped=0
for f in "${conflicts[@]}"; do
  orig=$(get_original "$f")

  # If original doesn't exist (deleted on this side), note it
  if [[ ! -f $orig ]]; then
    echo "⚠ $f"
    echo "  Original ($orig) does not exist — file was deleted on this side."
    echo "  [k]eep conflict (restore), [d]elete conflict (confirm deletion)?"
    read -rp "  > " ans
    case "$ans" in
    k)
      mv "$f" "$orig"
      echo "  Restored to $orig"
      ((resolved++))
      ;;
    d)
      rm "$f"
      echo "  Deleted"
      ((resolved++))
      ;;
    *)
      echo "  Skipped"
      ((skipped++))
      ;;
    esac
    echo
    continue
  fi

  echo "── $orig ──"
  # Use delta for a nice side-by-side or unified diff
  diff -u --color=always "$orig" "$f" 2>/dev/null | delta --diff-so-fancy --side-by-side || true
  echo
  read -rp "  [k]eep local, [r]emote(conflict) wins, [m]anual, [s]kip? " ans
  case "$ans" in
  k)
    rm "$f"
    echo "  ✓ Kept local ($orig)"
    ((resolved++))
    ;;
  r)
    mv "$f" "$orig"
    echo "  ✓ Kept remote → $orig"
    ((resolved++))
    ;;
  m)
    "''${EDITOR:-hx}" "$orig" "$f"
    # After manual edit, the conflict file should be removed by the user.
    # Check and offer cleanup.
    if [[ -f $f ]]; then
      read -rp "  Conflict file still exists. Delete it now? [Y/n] " cleanup
      case "$cleanup" in
      n | N) echo "  Left as-is" ;;
      *)
        rm "$f"
        echo "  ✓ Cleaned up"
        ;;
      esac
    fi
    ((resolved++))
    ;;
  *)
    echo "  Skipped"
    ((skipped++))
    ;;
  esac
  echo
done

echo "Done: $resolved resolved, $skipped skipped, ${#conflicts[@]} total."
