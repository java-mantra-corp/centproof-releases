#!/usr/bin/env bash
#
# Publish a new CentProof release to GitHub Releases.
#
# Usage:
#   ./scripts/publish-release.sh v0.1.1 /path/to/CentProof_0.1.1_aarch64.dmg \
#       [/path/to/CentProof.app.tar.gz] [/path/to/CentProof.app.tar.gz.sig] \
#       [/path/to/latest.json]
#
# What it does:
#   1. Validates the version string + that all attached files exist.
#   2. Extracts the matching section from CHANGELOG.md as release notes.
#   3. Creates a new GitHub Release tagged <version>, attaches the
#      provided files, and marks it as the latest release.
#
# What it does NOT do:
#   - Build anything.  Pass in pre-built, pre-signed artifacts.
#   - Push code commits.  Commit CHANGELOG.md updates separately.
#
# Prereqs:
#   - `gh` CLI installed + authenticated (`gh auth login`)
#   - GH user must have write access to centproof-releases
#
# Example, full release with all 4 assets:
#
#   ./scripts/publish-release.sh \
#     v0.1.1 \
#     ~/Downloads/CentProof_0.1.1_aarch64.dmg \
#     ~/Downloads/CentProof.app.tar.gz \
#     ~/Downloads/CentProof.app.tar.gz.sig \
#     ~/Downloads/latest.json
#
# Example, .dmg-only (auto-updater wires up later):
#
#   ./scripts/publish-release.sh v0.1.1 ~/Downloads/CentProof_0.1.1_aarch64.dmg

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <vX.Y.Z> <dmg-path> [app-tar-gz-path] [sig-path] [latest-json-path]" >&2
  exit 2
fi

VERSION="$1"
shift
FILES=("$@")

# ── Validate version format ────────────────────────────────────────────
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "ERROR: version must look like vX.Y.Z (with optional -suffix); got: $VERSION" >&2
  exit 1
fi

# ── Validate all attached files exist + are non-empty ──────────────────
for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: file not found: $f" >&2
    exit 1
  fi
  if [ ! -s "$f" ]; then
    echo "ERROR: file is empty: $f" >&2
    exit 1
  fi
done

# ── Locate the script's repo root so we can find CHANGELOG.md ─────────
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
if [ ! -f "$CHANGELOG" ]; then
  echo "ERROR: CHANGELOG.md not found at $CHANGELOG" >&2
  exit 1
fi

# ── Extract the changelog section for this version ─────────────────────
# Section header format:  ## v0.1.1 — _unreleased_   or   ## v0.1.0 — 2026-05-11
NOTES="$(awk -v v="$VERSION" '
  /^## / {
    # Compare just the version token (second whitespace-separated field).
    if (in_section) exit
    if ($2 == v) { in_section = 1; print; next }
  }
  in_section { print }
' "$CHANGELOG")"

if [ -z "$NOTES" ]; then
  echo "WARN: no CHANGELOG section found for $VERSION." >&2
  echo "      Add a '## $VERSION — <date>' section to CHANGELOG.md and re-run," >&2
  echo "      OR press Enter to publish with placeholder notes." >&2
  read -r -p "Continue with placeholder notes? [y/N] " REPLY
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    exit 1
  fi
  NOTES="See https://centproof.com/releases for details."
fi

# ── Sanity preview ─────────────────────────────────────────────────────
echo "────────────────────────────────────────────────────────────────"
echo " Publishing release:  $VERSION"
echo " Attached files:"
for f in "${FILES[@]}"; do
  size=$(du -h "$f" | awk '{print $1}')
  echo "   - $(basename "$f")  ($size)"
done
echo ""
echo " Release notes (preview, first 20 lines):"
echo "$NOTES" | head -20 | sed 's/^/   │ /'
echo "────────────────────────────────────────────────────────────────"
read -r -p "Publish to GitHub Releases now? [y/N] " REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# ── Create the release ─────────────────────────────────────────────────
# --latest marks this as the "latest release" pointer that
# centproof.com/releases/latest/download/... resolves against.
gh release create "$VERSION" \
  --title "$VERSION" \
  --notes "$NOTES" \
  --latest \
  "${FILES[@]}"

echo "✓ Released $VERSION"
echo "  https://github.com/java-mantra-corp/centproof-releases/releases/tag/$VERSION"
