# Blink release helpers.
#
# The release pipeline is tag-driven (see RELEASING.md): pushing a `vX.Y.Z`
# tag triggers CI to build, sign, notarize, EdDSA-sign, publish the appcast,
# and bump Homebrew. CI routes the release by tag name:
#   vX.Y.Z-beta.N / -rc.N  → Sparkle BETA channel (opt-in users only)
#   vX.Y.Z                 → STABLE channel (all users) + Homebrew cask bump
#
# `make promote` takes the current pre-release version in project.yml, drops
# the -beta.N / -rc.N suffix, and ships it to the stable channel in one shot.

PROJECT := blink-macos/project.yml
D1_DB   := blink-analytics
STATS_DAYS ?= 30

.PHONY: help version promote stats stats-init

help:
	@echo "Targets:"
	@echo "  make version     Print the current MARKETING_VERSION"
	@echo "  make promote     Promote the current beta/rc to a stable release"
	@echo "                   (drops -beta.N/-rc.N, commits, tags, pushes → CI)"
	@echo "                   Add CONFIRM=1 to skip the interactive prompt."
	@echo "  make stats       Download counts (GitHub) + Sparkle update checks and"
	@echo "                   website downloads by day/version (D1). STATS_DAYS=30"
	@echo "  make stats-init  Apply worker/schema.sql to the D1 database (once)."

version:
	@grep -m1 'MARKETING_VERSION:' $(PROJECT) | sed -E 's/.*"(.*)".*/\1/'

# Counters live in D1 (see worker/index.js): one row per day × event ×
# version. Queries go through wrangler's login — no extra API token.
stats:
	@echo "== GitHub release downloads (all time; website + Sparkle updates + brew) =="
	@gh api repos/D4G4/blink/releases --paginate \
	  --jq '.[] | select(.assets|length>0) | "\(.tag_name)\t\(.assets[]|select(.name=="Blink.dmg")|.download_count)"' \
	  | head -15 | column -t
	@echo
	@q() { npx wrangler d1 execute $(D1_DB) --remote --json --command "$$1" 2>/dev/null \
	     | python3 -c 'import sys,json; rows=json.load(sys.stdin)[0]["results"]; \
	                  [print("\t".join(str(v) for v in r.values())) for r in rows] if rows else print("(no data yet)")' \
	     | column -t; }; \
	since=$$(date -u -v-$(STATS_DAYS)d +%Y-%m-%d); \
	echo "== Sparkle update checks per day (≈ active installs), since $$since =="; \
	q "SELECT day, SUM(count) AS checks FROM events WHERE event='appcast' AND day >= '$$since' GROUP BY day ORDER BY day"; \
	echo; echo "== Update checks by installed version, since $$since =="; \
	q "SELECT app_version, SUM(count) AS checks FROM events WHERE event='appcast' AND day >= '$$since' GROUP BY app_version ORDER BY checks DESC"; \
	echo; echo "== Website downloads per day, since $$since =="; \
	q "SELECT day, SUM(count) AS downloads FROM events WHERE event='download' AND day >= '$$since' GROUP BY day ORDER BY day"

stats-init:
	npx wrangler d1 execute $(D1_DB) --remote --file worker/schema.sql

promote:
	@cur=$$(grep -m1 'MARKETING_VERSION:' $(PROJECT) | sed -E 's/.*"(.*)".*/\1/'); \
	case "$$cur" in \
	  *-beta.*|*-rc.*) ;; \
	  *) echo "✗ Current version '$$cur' is not a pre-release — nothing to promote."; exit 1;; \
	esac; \
	stable=$$(printf '%s' "$$cur" | sed -E 's/-(beta|rc)\.[0-9]+$$//'); \
	tag="v$$stable"; \
	branch=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$branch" != "main" ]; then echo "✗ Not on main (on '$$branch') — promote releases from main."; exit 1; fi; \
	if [ -n "$$(git status --porcelain)" ]; then echo "✗ Working tree not clean — commit or stash first."; exit 1; fi; \
	git fetch -q origin; \
	if [ -n "$$(git rev-list HEAD..origin/main)" ]; then echo "✗ Local main is behind origin/main — pull first."; exit 1; fi; \
	if git rev-parse -q --verify "refs/tags/$$tag" >/dev/null 2>&1 || git ls-remote --exit-code --tags origin "$$tag" >/dev/null 2>&1; then \
	  echo "✗ Tag $$tag already exists locally or on origin."; exit 1; fi; \
	echo "Promote $$cur → $$stable"; \
	echo "  tag $$tag → STABLE channel (all users) + Homebrew cask bump"; \
	if [ "$$CONFIRM" != "1" ]; then \
	  printf "Proceed? [y/N] "; read ans; case "$$ans" in y|Y|yes) ;; *) echo "Aborted."; exit 1;; esac; \
	fi; \
	sed -i '' -E "s/(MARKETING_VERSION: )\".*\"/\1\"$$stable\"/" $(PROJECT); \
	git add $(PROJECT); \
	git commit -q -m "chore(macos): bump to $$stable"; \
	git push origin main; \
	git tag "$$tag"; \
	git push origin "$$tag"; \
	echo "✓ Pushed $$tag — CI is building, notarizing, and publishing to the stable channel (~5 min)."; \
	echo "  Watch: https://github.com/D4G4/blink/actions"
