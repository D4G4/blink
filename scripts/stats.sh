#!/usr/bin/env bash
# Blink usage numbers. Run from anywhere:  ~/GitHub/D4G4/Blink/scripts/stats.sh [--days N]
#
# Sources:
#   - GitHub Releases      → DMG download counts per release (all time)
#   - Cloudflare D1        → daily counters written by worker/index.js:
#                            Sparkle update checks (≈ active installs, by version)
#                            and website /download clicks. No IPs, no per-request rows.
# Needs: gh (logged in), npx wrangler (logged in). Both already are on this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

DAYS=30
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
SINCE=$(date -u -v-"${DAYS}"d +%Y-%m-%d)
TODAY=$(date -u +%Y-%m-%d)

q() {
  npx wrangler d1 execute blink-analytics --remote --json --command "$1" 2>/dev/null \
  | python3 -c '
import sys, json
raw = sys.stdin.read()
d = json.loads(raw[raw.find("["):]) if "[" in raw else []
rows = d[0]["results"] if isinstance(d, list) and d else (d.get("results", []) if isinstance(d, dict) else [])
if not rows:
    print("(no data yet)")
else:
    print("\t".join(rows[0].keys()))
for r in rows:
    print("\t".join(str(v) for v in r.values()))
' | column -t -s $'\t'
}

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
dim()  { printf '\033[2m%s\033[0m\n' "$*"; }

echo
bold "Blink — usage numbers (UTC day $TODAY; window: last $DAYS days)"
echo

# Headline: real installs = requests carrying Sparkle's user agent (app_version set).
bold "Active installs (Sparkle update checks, one per install per day)"
q "SELECT day, SUM(count) AS installs
   FROM events WHERE event='appcast' AND app_version!='' AND day >= '$SINCE'
   GROUP BY day ORDER BY day DESC LIMIT 14"
echo
bold "By installed version (last $DAYS days)"
q "SELECT app_version AS version, SUM(count) AS checks
   FROM events WHERE event='appcast' AND app_version!='' AND day >= '$SINCE'
   GROUP BY app_version ORDER BY checks DESC"
echo
bold "Website downloads per day (blink20.net /download)"
q "SELECT day, SUM(count) AS downloads,
          SUM(CASE WHEN os='mac' THEN count ELSE 0 END) AS mac,
          SUM(CASE WHEN os!='mac' THEN count ELSE 0 END) AS other
   FROM events WHERE event='download' AND day >= '$SINCE'
   GROUP BY day ORDER BY day DESC LIMIT 14"
dim "  'other' = non-Mac user agents (bots, curl, Windows browsers) — treat as noise."
echo
bold "GitHub release downloads (all time; website + Sparkle updates + Homebrew)"
gh api repos/D4G4/blink/releases --paginate \
  --jq '.[] | select(.assets|length>0) | "\(.tag_name)\t\(.assets[]|select(.name=="Blink.dmg")|.download_count)"' \
  | head -12 | column -t -s $'\t'
echo
dim "Non-Sparkle appcast fetches (curl, crawlers) today: $(q "SELECT SUM(count) FROM events WHERE event='appcast' AND app_version='' AND day='$TODAY'" | tr -d ' ')"
echo
