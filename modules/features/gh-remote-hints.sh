repo=/home/john/src/mortlake
if [ -d "$repo/.git" ] && command -v git >/dev/null 2>&1; then
  origin=$(git -C "$repo" remote get-url origin 2>/dev/null || printf "")
  case "$origin" in
  https://uriel-mortlake@github.com/*) : ;;
  *) git -C "$repo" remote set-url origin https://uriel-mortlake@github.com/uriel-mortlake/mortlake.git 2>/dev/null || true ;;
  esac
  public=$(git -C "$repo" remote get-url public 2>/dev/null || printf "")
  case "$public" in
  https://magus-john-bee@github.com/*) : ;;
  *) git -C "$repo" remote set-url public https://magus-john-bee@github.com/magus-john-bee/mortlake.git 2>/dev/null || true ;;
  esac
fi
