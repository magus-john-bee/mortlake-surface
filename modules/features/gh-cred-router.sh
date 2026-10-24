op="${1:-}"
[ "$op" = "get" ] || exit 0
user=""
while IFS= read -r line && [ -n "$line" ]; do
  case "$line" in username=*) user="${line#username=}" ;; esac
done
# No username or the active account: let the stock gh helper
# (first in programs.git config order) answer.
[ -z "$user" ] && exit 0
[ "$user" = "magus-john-bee" ] && exit 0
token="$(gh auth token --user "$user" 2>/dev/null)" || exit 0
if [ -n "$token" ]; then
  printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n' "$user" "$token"
fi
exit 0
