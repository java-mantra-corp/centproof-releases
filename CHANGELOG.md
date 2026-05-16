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

## v0.1.5 — 2026-05-16

### Added

- **Account Summary panel now mirrors your bank statement line-for-line.**
  Chase Total Checking shows separate "Deposits and Additions",
  "Checks Paid", "Electronic Withdrawals", and "Fees" rows (matching
  the PDF's Checking Summary block) instead of a single collapsed
  "Debits (sum)" total. Citi Costco Anywhere Visa shows "Payments"
  and "Credits" on separate rows (matching the PDF's Account Summary).
  Easier to audit side-by-side against your statement.

### Fixed

- **Citi Costco Anywhere Visa statements now reconcile cleanly.** Five
  bugs caused by the right-side rewards-summary column bleeding into
  transaction rows:
  - `Payments` summary line was missed when pdf.js merged it with the
    "Late Payment Warning" paragraph (was undercounting by thousands).
  - APPLE.COM/BILL captured the rewards-balance number ($58.86) instead
    of the actual purchase ($2.99).
  - Rows ending in a rewards trailer like "5% on gas ... +$0.00" or
    "+$0.96" were silently dropped (12/15 AMAZON, 12/16 LAZ PARKING,
    12/19 VEG N CHAAT on the affected fixture).
  - Multi-line merchant names (AMAZON RETA*, COLDSTONE CREAMERY,
    DOORDASH wrap) lost the merchant text and showed only the date.
  - PDF-preview highlight box stopped extending into the rewards column.
- **"Override & Commit" button now works.** Previously a no-op on macOS
  because Tauri's WKWebView doesn't implement `window.prompt()` for
  reason input — clicking the button appeared to do nothing. Replaced
  with a proper React modal that captures the reason in a textarea.

### Internal

- Added 95-row Citi Costco Anywhere Visa regression smoke
  (`npm run smoke:citi-costco`) — 10 sentinel rows lock in the
  v0.1.5 parser fixes so they can't silently regress.
- Added Chase Total Checking Summary-breakdown smoke
  (`npm run smoke:chase`) — asserts the bank-printed labels appear
  in PDF order and that row sums equal the breakdown totals.

---

## v0.1.4 — 2026-05-13

### Fixed

- License section correctly displays "Pro Monthly" vs "Pro Lifetime"
  for buyers on the live LemonSqueezy storefront. The v0.1.3 fix
  only recognised the test-store product IDs because LS keeps test
  and live catalogues as completely separate environments; v0.1.4
  adds the live-store IDs so paying customers see the right tier
  label from day one. No action required from existing customers.

---

## v0.1.3 — 2026-05-13

### Added

- Suggestion Review: full keyboard navigation (arrow keys + Enter to
  accept) plus an "Accept all routine" button that one-clicks every
  high-confidence existing-merchant suggestion so post-import triage
  takes seconds instead of minutes.
- PDF storage key recovery dialog. If your keychain entry for the
  storage encryption key ever goes missing (rare — usually a corrupted
  Keychain or a restored-from-backup state mismatch), CentProof now
  shows a friendly recovery dialog explaining exactly what happened
  and your options, instead of failing imports with a cryptic error.

### Changed

- License section now correctly displays "Pro Monthly" vs "Pro
  Lifetime" based on the actual LemonSqueezy product, not an
  unreliable heuristic. Existing Pro Monthly buyers no longer see
  "Pay once, use forever" in Preferences > License.
- Pricing copy in the License preferences matches the website:
  $49 lifetime, $5/mo subscription, $29 launch promo (was showing
  the old $59/$5/$39 numbers).
- Pro Lifetime device count documented as 2 Macs (matches what the
  license keys are actually issued for; the previous "3 Macs" copy
  was aspirational).

### Fixed

- Smarter rule pattern suggestions. When you save a category /
  entity rule from a transaction, the suggested match pattern now
  correctly handles descriptions with numbers mixed into the
  merchant name (e.g. "Goodleap 14 Agnt Pymnt") — previously the
  generated regex didn't match the original row.
- More defensive encryption-key bootstrap. The orphan-storage check
  now reads the caller's data directory rather than guessing,
  preventing a false-positive "missing key" trigger when CentProof
  is launched from a non-standard installation path.

---

## v0.1.2 — 2026-05-12

### Added

- Post-import Suggestion Review. After importing a statement, a
  guided screen walks you through the AI's suggested entities and
  categories, grouped by suggestion so you can accept many similar
  rows in one click. New merchants and new categories get their own
  section requiring deliberate approval.
- Copy from Transactions. Click + drag across descriptions, merchant
  names, categories, dates, amounts, and the description shown in
  the Set Entity / Set Category dialogs to select and copy.
- Undo on Hide. Hiding a transaction now shows a toast with an Undo
  button so a misclick is one click to recover. The "Show hidden"
  toggle shows a count when hidden rows exist and reveals them
  immediately on toggle (no separate Search click).

### Changed

- AI suggestions ignore the account holder. Bank statement
  descriptions often echo your name; the AI now picks the actual
  merchant or payer instead of tagging the transaction back to you.
- Ask CentProof's "show all transactions" returns both debits AND
  credits. Spending-specific phrasing ("show purchases", "what did
  I spend on") still scopes to debits.
- AI mode defaults to Bundled (offline) for fresh installs and
  settings resets. External-mode URL must be filled in manually.
- Set Category / Set Entity dialogs: clearer button labels showing
  what will actually happen ("Save rule & tag N rows" vs "Apply to
  this row only"). Click an already-selected item in the picker to
  deselect it. The bottom-left destructive button is now labeled
  "× Clear & delete rule" so its scope is clear.

### Fixed

- AI no longer mistakenly suggests your own name as the entity for
  transactions where your name appears in the bank's raw description
  (the most common false-positive in v0.1.1 imports).
- Encrypted PDFs are now protected from silent corruption. If the
  macOS Keychain entry holding your PDF encryption key becomes
  missing or unreadable (e.g. after Time Machine restore or a
  manual deletion), CentProof refuses to overwrite the original key
  and surfaces clear recovery instructions instead of orphaning
  every previously-imported PDF.
- Set Category dialog: when an auto-generated match pattern doesn't
  match the very row you opened the dialog from, your "tag this
  row" intent now still applies (was previously failing silently).
- Stale-cache footprint in the Search/Transactions view's hidden-row
  flow eliminated — toggle responds immediately and the count is
  always accurate.

### Removed

- Hardcoded LAN IP that previously shipped as the default External-
  mode AI server URL. Fresh installs and settings wipes no longer
  surface a stranger's network address.

---

## v0.1.1 — 2026-05-11

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
