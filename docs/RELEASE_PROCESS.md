# Release Process

How to cut a new public release of CentProof, end-to-end.

## Why this repo and not the app repo?

The CentProof source lives in a **private** GitHub repo
(`java-mantra-corp/PdfFinancialAnalyzer`). Customers can't download
binaries from there — GitHub Releases on private repos require
authentication. This repo (`centproof-releases`) is **public**, so
the marketing-site "Download" button and the in-app auto-updater can
both fetch from `https://github.com/java-mantra-corp/centproof-releases/releases/...`
without any auth dance.

We deliberately **don't commit the `.dmg` to git history** — it's
145 MB per release. Instead the `.dmg` (and other artifacts) live as
GitHub Release **assets**, served by GitHub's CDN at fixed URLs.

---

## Prerequisites (one-time, per maintainer machine)

1. **`gh` CLI installed**
   ```bash
   brew install gh
   ```
2. **`gh` authenticated as a user with write access**
   ```bash
   gh auth login
   # Choose: GitHub.com → HTTPS → Login with browser
   ```
   Verify access:
   ```bash
   gh repo view java-mantra-corp/centproof-releases
   ```
   Should show repo info, not a permission error.

---

## Release checklist

### 1. Build the artifacts (private repo, CI)

In `java-mantra-corp/PdfFinancialAnalyzer`:

```bash
cd /Users/javamantra/work/pdfApplication
git tag v0.1.1            # whatever the new version is
git push origin v0.1.1
```

CI builds + signs + notarizes + uploads a workflow artifact named
`centproof-macos-arm64`. The artifact is a `.zip` containing:

```
CentProof_0.1.1_aarch64.dmg          ← the installer
CentProof.app.tar.gz                 ← auto-updater payload
CentProof.app.tar.gz.sig             ← ed25519 signature of the .app.tar.gz
latest.json                          ← Tauri updater manifest (optional)
```

Wait for the workflow to go green. ~7–10 min total.

### 2. Download the artifact

From the workflow run page in the private repo:

```bash
# In a fresh temp dir, NOT the working tree of either repo
mkdir -p /tmp/centproof-release-v0.1.1
cd /tmp/centproof-release-v0.1.1

# Download via `gh`
gh run download \
    -R java-mantra-corp/PdfFinancialAnalyzer \
    --name centproof-macos-arm64

# The zip auto-extracts into the current directory
ls -la
# Should see CentProof_0.1.1_aarch64.dmg + the updater files
```

### 3. Sanity-check the .dmg

Before publishing — verify what you're about to ship:

```bash
# Gatekeeper says yes?
spctl --assess --type execute --verbose \
    $(hdiutil attach -nobrowse CentProof_0.1.1_aarch64.dmg | \
        grep '/Volumes/' | awk '{print $NF}')/CentProof.app

# Should print: "accepted source=Notarized Developer ID"
# If anything else, STOP — don't publish. Investigate first.
```

Eject the disk image:
```bash
hdiutil detach /Volumes/CentProof
```

### 4. Update CHANGELOG.md

Open `centproof-releases/CHANGELOG.md` and:
1. Find the `## v0.1.1 — _unreleased_` section
2. Change `_unreleased_` to today's ISO date (e.g. `2026-05-12`)
3. Make sure all changes are accurately listed under
   `### Added` / `### Changed` / `### Fixed` / `### Removed`
4. Commit the CHANGELOG change to `main`:
   ```bash
   cd /Users/javamantra/work/centproof-releases
   git add CHANGELOG.md
   git commit -m "Release v0.1.1 changelog"
   git push origin main
   ```

### 5. Publish via the helper script

```bash
cd /Users/javamantra/work/centproof-releases
./scripts/publish-release.sh \
    v0.1.1 \
    /tmp/centproof-release-v0.1.1/CentProof_0.1.1_aarch64.dmg \
    /tmp/centproof-release-v0.1.1/CentProof.app.tar.gz \
    /tmp/centproof-release-v0.1.1/CentProof.app.tar.gz.sig \
    /tmp/centproof-release-v0.1.1/latest.json
```

The script:
- Validates the version string
- Confirms all attached files exist + are non-empty
- Extracts the matching CHANGELOG section as release notes
- Shows you a preview
- Asks for confirmation
- Creates the GitHub Release marked as `latest`

If you only want to publish the `.dmg` (auto-updater wiring not
ready yet):
```bash
./scripts/publish-release.sh v0.1.1 \
    /tmp/centproof-release-v0.1.1/CentProof_0.1.1_aarch64.dmg
```

### 6. Verify the public URLs resolve

```bash
# The download URL the marketing site links to
curl -sILo /dev/null -w "%{http_code} %{url_effective}\n" \
    https://github.com/java-mantra-corp/centproof-releases/releases/latest/download/CentProof_0.1.1_aarch64.dmg

# Should 200 (after a 302 redirect to the actual CDN URL)
```

### 7. Update the marketing site's download pointer

If the new version's `.dmg` filename changed
(`CentProof_0.1.0_aarch64.dmg` → `CentProof_0.1.1_aarch64.dmg`),
update Vercel env vars:

In Vercel → centproof-website → Settings → Environment Variables:
- `NEXT_PUBLIC_DOWNLOAD_URL` →
  `https://github.com/java-mantra-corp/centproof-releases/releases/latest/download/CentProof_0.1.1_aarch64.dmg`
- `NEXT_PUBLIC_DOWNLOAD_VERSION_LABEL` → `v0.1.1 · May 2026`

Trigger a redeploy from the Deployments tab.

### 8. Clean up the temp dir

```bash
rm -rf /tmp/centproof-release-v0.1.1
```

The artifacts now live on GitHub's CDN; no need to keep the local
copy.

---

## Rollback

If a release ships and turns out to be broken:

**Option A — Hide the bad release**
1. GitHub web UI → centproof-releases → Releases → bad version → Edit
2. Untick "Set as the latest release"
3. Tick "Set as a pre-release"
4. Save

The previous release automatically becomes "latest" again, so
`releases/latest/download/...` resolves to the older `.dmg`. Marketing
site and auto-updater fall back automatically.

**Option B — Delete the release entirely**
1. Same edit page → "Delete release"
2. Optionally also delete the tag (`git push --delete origin v0.1.1`)

Useful for: leaked credentials, severe bug. Not normally recommended
— the changelog history is valuable.

**Option C — Hotfix release**
1. Cut v0.1.1.1 with the fix
2. Run through this whole checklist again
3. The hotfix becomes the new "latest"; users on the broken v0.1.1
   pick it up on next auto-update check

---

## Edge cases

- **`.dmg` over 2 GB**: GitHub Releases single-file cap is 2 GB.
  Currently we're at ~145 MB so this isn't an issue, but if the
  bundled model ever ships inside the `.dmg` it could become one.
- **CI artifact retention**: GitHub Actions artifacts auto-delete
  after 90 days by default. Download + publish within that window or
  the artifact disappears. (The CI workflow is configured for 90 days.)
- **Signing identity changed**: If the Apple Developer ID cert is
  rotated, all future releases must be signed under the new identity.
  The old releases stay valid (their signatures don't expire) but
  the cert SHA1 changes.
- **Updater key rotation**: If the ed25519 updater private key ever
  leaks, generate a new pair, ship an app build with the new public
  key embedded, and any signed `.app.tar.gz` from the old key will
  stop being accepted by post-rotation app installs.
