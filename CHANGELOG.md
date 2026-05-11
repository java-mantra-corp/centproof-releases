# Changelog

User-facing release notes for CentProof. Each section maps to a
[GitHub Release][releases] of the same name; the body becomes the
release description shown on the Releases page and in the in-app
"Check for Updates" dialog.

Format guidelines:
- Newest version on top.
- Write for end users, not developers. "Faster import" not "switched
  the inner loop to streamSync".
- Group changes under `### Added`, `### Changed`, `### Fixed`, or
  `### Removed`.
- One short line per change. Detail goes in the linked GitHub issue
  if needed.

The `scripts/publish-release.sh` script reads sections from this
file when creating GitHub Releases, so the formatting matters: each
version must start with `## <version>` on its own line.

[releases]: https://github.com/java-mantra-corp/centproof-releases/releases

---

## v0.1.1 — _unreleased_

### Changed

- License verification now backed by LemonSqueezy's License API
  instead of offline ed25519 signatures. Real per-device activation
  enforcement: Pro Lifetime works on up to 2 Macs (was honor-system 3
  in v0.1.0).
- Pricing: Pro Lifetime is now $49 ($30 with the `LAUNCH2026` launch
  coupon, down from $59 / $39).
- App version label on the About panel now reads "0.1.1".

### Added

- License section in Preferences shows live activation count
  ("1 of 2 devices used") pulled from LemonSqueezy.
- Re-validation runs once per app launch against the LemonSqueezy
  API. Within a 7-day offline-grace window the cached state still
  works without internet.

### Fixed

- Native CSV save dialog now shown for the Search → Export CSV
  button (was silently downloading to `~/Downloads`).
- AI model-download progress survives navigating away from
  Preferences → AI and back (was resetting to "Download" button).
- Settlement → Export CSV uses native save dialog.

### Removed

- v0.1.0 ed25519 license signing / verification code paths.
- Legacy `gen-keypair` developer script.

---

## v0.1.0 — 2026-05-11

Initial signed and notarized release.

### Added

- Local-first reconciliation for Bank of America, Capital One,
  Chase, Wells Fargo bank + credit-card PDF statements.
- Smart tagging — entity, category, and notes suggestions for new
  transactions, fully offline via local LLM.
- Ask CentProof — natural-language queries against your imported
  history, answered with supporting source rows.
- Recurring subscriptions detector, anomaly detection, what-changed
  diffs, price-watch.
- Cash-flow calendar, trip reports, settlement reports, search
  exports, PDF previews of original statement pages.
- Native macOS menubar with standard shortcuts (`⌘O` import, `⌘F`
  find, `⌘,` preferences, `⌘Q` quit).
- Apple Developer ID signed, Apple-notarized — clean Gatekeeper
  install.
- Bundled auto-updater (ed25519-signed update tarballs).

### Known limitations

- Apple Silicon only (M1, M2, M3, M4). No Intel Mac build.
- Free Test Mode caps at 2 active statements + 5 lifetime imports.
- Pro Lifetime device limit was advertised as 3 but not technically
  enforced. Fixed in v0.1.1 (LS License API).
