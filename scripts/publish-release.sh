#!/usr/bin/env bash
#
# Publish a new CentProof release to GitHub Releases.
#
# Usage:
#   ./scripts/publish-release.sh v0.1.1 <dir-with-release-files>
#
# Where <dir-with-release-files> contains the artifacts CI built and you
# downloaded via `gh run download`.  Expected filenames:
#
#   CentProof_<version>_aarch64.dmg
#   CentProof.app.tar.gz
#   CentProof.app.tar.gz.sig
#
# Plus this script will GENERATE on the fly:
#
#   latest.json     ← Tauri auto-updater manifest (this is what powers
#                     v0.1.0 → v0.1.1 in-app updates)
#
# What it does:
#   1. Validates the version string + the three CI-built files exist
#   2. Generates latest.json from the .sig contents + the predictable
#      GitHub release-asset URL pattern
#   3. Extracts the matching CHANGELOG section as release notes
#   4. Shows a preview, asks for confirmation
#   5. `gh release create` with all four files attached, marks as latest
#
# What it does NOT do:
#   - Build.  Pass in pre-built, pre-signed artifacts from CI.
#   - Push code commits.  Commit CHANGELOG.md updates separately first.
#
# Prereqs:
#   - `gh` CLI installed + authenticated (`gh auth login`)
#   - Write access to centproof-releases (you'll have it as the org owner)
#
# Example (typical):
#
#   mkdir /tmp/cp-v0.1.1 && cd /tmp/cp-v0.1.1
#   gh run download -R java-mantra-corp/PdfFinancialAnalyzer \
#       --name centproof-macos-arm64
#   cd /Users/javamantra/work/centproof-releases
#   ./scripts/publish-release.sh v0.1.1 /tmp/cp-v0.1.1

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <vX.Y.Z> <dir-with-release-files>" >&2
  exit 2
fi

VERSION="$1"
ARTIFACT_DIR="$2"

# ── Validate version format ────────────────────────────────────────────
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "ERROR: version must look like vX.Y.Z (with optional -suffix); got: $VERSION" >&2
  exit 1
fi
VERSION_BARE="${VERSION#v}"

# ── Validate artifact dir + locate expected files ──────────────────────
if [ ! -d "$ARTIFACT_DIR" ]; then
  echo "ERROR: artifact dir not found: $ARTIFACT_DIR" >&2
  exit 1
fi

# Expected files.  CI built them under specific names; we resolve via
# glob so a future version-number change in the .dmg filename doesn't
# break this script (.app.tar.gz is version-agnostic).
DMG_PATH="$(find "$ARTIFACT_DIR" -maxdepth 2 -name "CentProof_${VERSION_BARE}_aarch64.dmg" 2>/dev/null | head -1)"
TARBALL_PATH="$(find "$ARTIFACT_DIR" -maxdepth 2 -name "CentProof.app.tar.gz" 2>/dev/null | head -1)"
SIG_PATH="$(find "$ARTIFACT_DIR" -maxdepth 2 -name "CentProof.app.tar.gz.sig" 2>/dev/null | head -1)"

for label_path in \
    "DMG:$DMG_PATH" \
    "TARBALL:$TARBALL_PATH" \
    "SIG:$SIG_PATH"; do
  label="${label_path%%:*}"
  path="${label_path#*:}"
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    echo "ERROR: $label file not found in $ARTIFACT_DIR" >&2
    echo "       Expected one of:" >&2
    case "$label" in
      DMG)     echo "         CentProof_${VERSION_BARE}_aarch64.dmg" >&2 ;;
      TARBALL) echo "         CentProof.app.tar.gz" >&2 ;;
      SIG)     echo "         CentProof.app.tar.gz.sig" >&2 ;;
    esac
    exit 1
  fi
  if [ ! -s "$path" ]; then
    echo "ERROR: $label file is empty: $path" >&2
    exit 1
  fi
done

# ── Repo root + CHANGELOG.md location ─────────────────────────────────
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

# ── Generate latest.json (the Tauri updater manifest) ─────────────────
#
# Format: https://v2.tauri.app/plugin/updater/
#
# We construct the asset URL using GitHub's predictable per-release
# asset path.  This URL becomes valid the moment `gh release create`
# completes — even though we generate the JSON BEFORE publishing, the
# URL will resolve correctly because GitHub Releases assets are reachable
# via that fixed pattern.
ASSET_BASE="https://github.com/java-mantra-corp/centproof-releases/releases/download/${VERSION}"
TARBALL_URL="${ASSET_BASE}/CentProof.app.tar.gz"
SIGNATURE="$(cat "$SIG_PATH")"
PUB_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

LATEST_JSON_PATH="$(mktemp -t centproof-latest-XXXXXX.json)"
# Tauri 2's updater plugin reliably parses the platforms-keyed format
# below; the flat format with top-level `url`/`signature` is the Tauri 1
# legacy shape and isn't accepted by all 2.x releases (silently returns
# "no update available" when the parser can't find platforms[target]).
# v0.1.1 launch surfaced this — emit platforms-keyed from now on.
#
# Single platform today (darwin-aarch64).  When we add Intel / Windows
# builds later, add more keys under "platforms" with each platform's
# own url + signature (the .sig files differ per-platform).
#
# `notes` is a short blurb — the GitHub Release page itself shows the
# CHANGELOG body, but the in-app updater UI surfaces `notes` under the
# version number, so keep it brief and informative.
cat >"$LATEST_JSON_PATH" <<EOF
{
  "version": "${VERSION_BARE}",
  "pub_date": "${PUB_DATE}",
  "notes": "CentProof ${VERSION_BARE}. See centproof.com/releases for full notes.",
  "platforms": {
    "darwin-aarch64": {
      "url": "${TARBALL_URL}",
      "signature": $(printf '%s' "$SIGNATURE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    }
  }
}
EOF

# ── Extract release notes from CHANGELOG.md ───────────────────────────
NOTES=""
if [ -f "$CHANGELOG" ]; then
  NOTES="$(awk -v v="$VERSION" '
    /^## / {
      if (in_section) exit
      if ($2 == v) { in_section = 1; print; next }
    }
    in_section { print }
  ' "$CHANGELOG")"
fi

if [ -z "$NOTES" ]; then
  echo "WARN: no CHANGELOG section found for $VERSION (looked for '## $VERSION ...')." >&2
  echo "      Add a section to $CHANGELOG and re-run, OR continue with placeholder." >&2
  read -r -p "Continue with placeholder notes? [y/N] " REPLY
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    rm -f "$LATEST_JSON_PATH"
    exit 1
  fi
  NOTES="CentProof ${VERSION_BARE}. See https://centproof.com/releases for details."
fi

# ── Preview ────────────────────────────────────────────────────────────
echo "────────────────────────────────────────────────────────────────"
echo " Publishing release:  $VERSION"
echo ""
echo " Attached files:"
for f in "$DMG_PATH" "$TARBALL_PATH" "$SIG_PATH" "$LATEST_JSON_PATH"; do
  size=$(du -h "$f" | awk '{print $1}')
  base="$(basename "$f")"
  # latest.json is in /tmp; show its target name as it'll appear on the release
  if [[ "$f" == "$LATEST_JSON_PATH" ]]; then
    base="latest.json  (generated)"
  fi
  echo "   - $base  ($size)"
done
echo ""
echo " Updater manifest preview:"
cat "$LATEST_JSON_PATH" | sed 's/^/   │ /'
echo ""
echo " Release notes (preview, first 25 lines):"
echo "$NOTES" | head -25 | sed 's/^/   │ /'
echo "────────────────────────────────────────────────────────────────"
read -r -p "Publish to GitHub Releases now? [y/N] " REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo "Aborted.  (Generated manifest left at $LATEST_JSON_PATH if you want to inspect.)"
  exit 0
fi

# ── Stage latest.json next to the manifest filename ────────────────────
# `gh release create` uploads files using their basename as the asset
# name on the release.  Make sure the asset is literally named
# "latest.json", not "centproof-latest-abc123.json".
PUBLISH_DIR="$(dirname "$LATEST_JSON_PATH")/$(basename "$LATEST_JSON_PATH" .json)-staged"
mkdir -p "$PUBLISH_DIR"
cp "$LATEST_JSON_PATH" "$PUBLISH_DIR/latest.json"

# ── Create the release ─────────────────────────────────────────────────
# Explicit -R so this script works regardless of cwd.  Without it,
# `gh` infers the target repo from whatever directory you happened to
# be in when you invoked the script — which bit us on v0.1.1 when the
# orchestrator (in pdfApplication/) called publish-release.sh and the
# release landed on the PRIVATE app repo instead of the public
# distribution repo.  Pin to the canonical target by name.
gh release create "$VERSION" \
  -R java-mantra-corp/centproof-releases \
  --title "$VERSION" \
  --notes "$NOTES" \
  --latest \
  "$DMG_PATH" \
  "$TARBALL_PATH" \
  "$SIG_PATH" \
  "$PUBLISH_DIR/latest.json"

# Clean up the temp manifest files now that they're uploaded.
rm -f "$LATEST_JSON_PATH"
rm -rf "$PUBLISH_DIR"

echo ""
echo "✓ Released $VERSION"
echo ""
echo "  Release page:"
echo "    https://github.com/java-mantra-corp/centproof-releases/releases/tag/$VERSION"
echo ""
echo "  Stable URLs (now live):"
echo "    https://github.com/java-mantra-corp/centproof-releases/releases/latest/download/CentProof_${VERSION_BARE}_aarch64.dmg"
echo "    https://github.com/java-mantra-corp/centproof-releases/releases/latest/download/CentProof.app.tar.gz"
echo "    https://github.com/java-mantra-corp/centproof-releases/releases/latest/download/CentProof.app.tar.gz.sig"
echo "    https://github.com/java-mantra-corp/centproof-releases/releases/latest/download/latest.json"
echo ""
echo "  Next steps:"
echo "    1. On Vercel, set NEXT_PUBLIC_LATEST_MANIFEST_URL to:"
echo "       https://github.com/java-mantra-corp/centproof-releases/releases/latest/download/latest.json"
echo "       (one-time, doesn't change between releases)"
echo "    2. Update NEXT_PUBLIC_DOWNLOAD_URL to the new .dmg URL above"
echo "    3. Re-deploy the marketing site"
echo "    4. v0.1.0 users: the in-app updater will detect ${VERSION_BARE} on"
echo "       next launch (or window-focus after the 6h throttle expires)"
