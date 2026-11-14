# Keep the mortlake checkout's surface remote pointed at the public
# surface repo (inspection convenience). The canonical has no GitHub
# remote — radicle is its only remote home. Absolute paths throughout:
# activation runs with an empty PATH, so `command -v` guards silently
# no-op there.
repo=/home/john/src/mortlake
git=/run/current-system/sw/bin/git
if [ -d "$repo/.git" ] && [ -x "$git" ]; then
  public=$("$git" -C "$repo" remote get-url public 2>/dev/null || printf "")
  case "$public" in
  https://magus-john-bee@github.com/magus-john-bee/mortlake-surface.git) : ;;
  *) "$git" -C "$repo" remote set-url public https://magus-john-bee@github.com/magus-john-bee/mortlake-surface.git 2>/dev/null || true ;;
  esac
fi
