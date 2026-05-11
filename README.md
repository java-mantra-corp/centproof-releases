# CentProof Releases

Public distribution channel for [**CentProof**](https://centproof.com) —
a privacy-first macOS desktop app for reconciling bank and credit-card
PDF statements entirely on your machine.

Source code is maintained privately by [Java Mantra Corp]. This
repository is **distribution-only** — it hosts the signed and
notarized release binaries that customers download, plus the
auto-updater manifest payload that the in-app updater consumes.

[Java Mantra Corp]: https://github.com/java-mantra-corp

---

## Download CentProof

→ **<https://centproof.com/download>** — direct link to the latest
signed `.dmg`.

Or pick a specific version from the [Releases tab][releases].

### System requirements

- macOS 13 Ventura or later
- Apple Silicon (M1, M2, M3, or M4)
- Intel Macs are not supported in this release

### What's signed / notarized

- Code-signed with our **Apple Developer ID** (Java Mantra Corp,
  Team ID `XCCH67345Y`)
- Notarized by Apple (no Gatekeeper warning on install)
- Auto-updater payloads (`.app.tar.gz`) signed with our ed25519
  updater key (verified by the in-app updater against the embedded
  public key)

---

## Release assets

Each release ships these files attached to the GitHub Release:

| File | Purpose |
|---|---|
| `CentProof_<version>_aarch64.dmg` | The installer customers download. Gatekeeper-accepted, double-click to install. |
| `CentProof.app.tar.gz` | Auto-updater payload. The in-app updater fetches this directly from GitHub Releases when a new version is available. |
| `CentProof.app.tar.gz.sig` | ed25519 signature of the `.app.tar.gz`. The in-app updater verifies this against an embedded public key before applying the update. |
| `latest.json` *(optional)* | Tauri auto-updater manifest. Lists the latest version's URL + signature in the format `tauri-plugin-updater` expects. |

The auto-updater is wired so the in-app **Preferences → About →
Check for Updates** button fetches release info from this repo via
the GitHub Releases API.

---

## Maintainer docs

Releasing a new version: see [`docs/RELEASE_PROCESS.md`][rp].

[releases]: https://github.com/java-mantra-corp/centproof-releases/releases
[rp]: ./docs/RELEASE_PROCESS.md
