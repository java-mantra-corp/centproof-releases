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

## v0.1.11 — _unreleased_

### Fixed

- **Chase business-statement transactions were being tagged
  `kind = deposit` even when they were outgoing payments.** Surfaced
  by a v0.1.10 user looking at Tax Summary — the "Outgoing
  breakdown" showed 14 transactions labeled "deposit" totaling
  $7,061.54, when in fact those rows were all real debits (Chase
  Credit Card autopay, 7-Eleven purchases, ATM withdrawals,
  Zelle payments) that just didn't match the parser's specific
  description regexes.  Root cause: the classifier used the
  SIGN of the amount as its fallback ("amountCents > 0 →
  deposit"), but the business-statement parser passes an unsigned
  amount because Chase Business PDFs don't print a sign —
  direction is implied by which section the row sits in.  The
  fallback then returned "deposit" for every business-row debit
  whose description didn't match a specific regex.  The fix passes
  direction explicitly, so the fallback is now `direction ===
  'credit' ? 'deposit' : 'purchase'` — bug eliminated for new
  imports.
- **One-shot backfill migration corrects existing wrong kinds.**
  When you launch v0.1.11, the sidecar runs a one-time pass that
  re-classifies every transaction whose `(direction, kind)` pair
  is the impossible state the bug produced (e.g., `debit +
  deposit`, `debit + direct_dep`).  Re-classification uses the
  corrected classifier on the original description, so backfilled
  rows are indistinguishable from freshly-ingested ones.  Tax
  Summary's Outgoing breakdown now reads what it should — credit
  card payments, ATM withdrawals, purchases, transfers, fees —
  not a single sweeping "deposit" bucket.  The audit log records
  how many rows were corrected and the before-after kind
  transitions so the operation is traceable.  Idempotent — re-
  runs find zero candidates.
- **Tax Summary's breakdown now shows "Deposits" and "Direct
  deposits" instead of the raw lowercase `deposit` /
  `direct_dep` strings.** Polish — the friendly-label map in
  the on-screen view was missing those entries (the PDF builder
  already had them).

### Notes for existing users

- **One safe backfill migration.** Runs once on first launch
  after upgrade.  Audit log captures the count of corrections;
  no data loss possible — the migration only writes
  `transaction_kind`, never touches amounts / dates /
  descriptions / FKs.  Backups (Time Machine etc.) of your
  pre-v0.1.11 database remain readable by older releases.
- **Tax Summary will look different on existing imports.**
  Specifically, the Outgoing breakdown will redistribute what
  was previously a giant "deposit" bucket into the real
  categories.  If you handed a v0.1.10 Tax Summary PDF to your
  CPA already, regenerate it on v0.1.11 — the totals (Income,
  Outgoing, Net) are unchanged, but the kind breakdown
  shifts.

---

## v0.1.10 — 2026-06-01

### Fixed

- **"Generating AI suggestions" screen could still hang after the
  v0.1.9 fix in two more error paths.** v0.1.9 unblocked rows
  whose LLM call threw an exception, but two other paths to
  errors were missed:
    1. When the local model returned a response that LOOKED valid
       structurally but had `confidence: null` (or any
       non-numeric confidence) — small local models sometimes
       hallucinate this — the validation correctly rejected the
       response, but the rejection path forgot to mark the row
       as attempted.
    2. If any code path inside the suggestion function threw
       synchronously OUTSIDE the LLM call (a SQL error, a regex
       edge case, etc.), the whole batch aborted, leaving
       every subsequent row in the statement pending forever.
  v0.1.10 fixes the first case directly and adds a defense-in-
  depth wrapper at the batch loop so the second case also can't
  trap rows in pending — even for future code paths we haven't
  thought of.  The result: the "AI suggestions seem stuck"
  90-second escape from v0.1.9 should be a rarity now, not a
  frequent occurrence.

### Changed

- **Toast notifications now replace native alert() dialogs
  across the entire app.** v0.1.8 fixed the most-trafficked
  surfaces (Categories, Entities, Trash, Settlement, Tax
  Summary); v0.1.10 finishes the sweep — Statement upload,
  Save report, Manual entries (both Settlement and Tax Summary
  variants), AI suggestion accept/dismiss, Bulk-action bar,
  Notes cell, the Best-effort import screen, Review screen,
  and the Preferences panels.  Every success and every error
  message now uses the same green-check / amber-warning /
  red-error toast pattern the newer screens use, so feedback
  stays consistent across the app regardless of which surface
  triggered it.  Many of these alerts had been silently dropped
  by Tauri's macOS webview (same root cause as the
  confirm-dialog fix in v0.1.8) — so this isn't just polish,
  it's also unblocking error messages users were never seeing.

### Notes for existing users

- **Upgrade in place.** No database changes, no settings to
  migrate.  Open Preferences → About → Check for updates, or
  download the new .dmg from centproof.com/download.

---

## v0.1.9 — 2026-05-31

### Fixed

- **"Generating AI suggestions" screen could hang indefinitely on
  import.** If a single LLM call timed out or errored during the
  on-import suggestion pass, the sidecar correctly logged the
  failure but never marked that row as attempted — so the in-app
  progress counter never decremented past it, and the screen
  stayed at "N of M analyzed" forever even though the backend
  was idle.  Reported by a v0.1.8 user who saw a 30-minute hang
  on a 2-transaction statement (the same bug also affected v0.1.7
  and earlier).  The error path now marks errored rows as
  attempted, matching what the low-confidence-skip path already
  did, so progress unblocks immediately.  As a defense-in-depth
  measure, the screen also gains a safety net: if progress
  hasn't moved for 90 seconds it switches to a clear "Suggestions
  seem stuck — open Transactions" panel with a button.  Users
  can never get trapped on this screen again regardless of the
  underlying cause.

### Notes for existing users

- **Upgrade in place.** No database changes, no settings to migrate.
  Open Preferences → About → Check for updates, or download the
  new .dmg from centproof.com/download.

---

## v0.1.8 — 2026-05-31

### Added

- **Tax Summary view — built for the hand-it-to-my-CPA moment.**
  A new Reports tab that sums every credit and debit in a date
  range across one account or all of them, then breaks the
  outgoing total down by kind so you can see at a glance what
  was a credit-card payment, what was a transfer, and what was
  a real expense. Date-range presets cover the common windows
  (Tax year, Year-to-date, Last 3 months, Last 90, Last 30) plus
  a custom range. The numbers tie directly to the bank statements'
  printed summary blocks, so your CPA can verify against source
  PDFs.

- **Save as PDF + Detailed PDF (with source snapshots) for Tax
  Summary.** Two export buttons. "Save as PDF" produces a clean
  one-page CPA handoff with the headline totals, outgoing
  breakdown, and a "For your CPA" note explaining that credit-card
  payments and account transfers are inter-account movements
  rather than deductible expenses. "Detailed PDF (with snapshots)"
  adds two more pages — a complete transactions list and an
  appendix with a cropped snapshot of every transaction's row
  from its source PDF — so the CPA can spot-check every number
  down to the actual bank statement without ever opening the
  source files.

- **Manual entries on Tax Summary for off-statement cash flows.**
  Click "Add manual entry" to record cash payments, owner draws,
  in-kind income, or year-end tax adjustments that never hit a
  bank statement. Entries merge into the headline Income /
  Outgoing / Net totals and surface in a dedicated amber "Manual
  entries" table on screen and on a separate page in the PDF —
  always with a MANUAL badge so the CPA can tell at a glance
  what's bank-verified vs user-claimed. Edit and delete inline.

- **Schedule C preset on Categories.** One click adds the 16
  standard IRS Schedule C expense categories (Advertising, Bank &
  Card Fees, Contractor Labor, Insurance, Office Expenses, Rent &
  Lease, Software & Subscriptions, Travel, Vehicle / Mileage, and
  so on). Idempotent — same-named categories you already have are
  reused, not duplicated. Useful for fresh-install 1099 freelancers
  who want the standard taxonomy set up without thinking about it.

- **Set Entity dialog now has an "Also set category" companion —
  and Set Category dialog now has the matching "Also set entity"
  companion.** Symmetric to v0.1.7's Set Entity addition. Whichever
  dialog you open first, you can create both correction rules in
  one save with the same match pattern. No more "I tagged the
  entity but forgot the category" or vice versa.

- **User-resizable column widths on Search and Trip Report.**
  Drag any column header's right edge to widen or narrow it.
  Widths persist in localStorage per table, so they survive
  reloads and updates. Double-click the resize handle to reset
  a column to its default.

- **App version shown in the sidebar.** Next to the CentProof
  name in the header. Useful when filing bug reports or verifying
  an auto-update actually applied.

### Fixed

- **Every destructive action's confirm dialog was silently doing
  nothing on macOS.** Click "Move to Trash" on a statement, click
  Delete on a category or entity, click "Add Schedule C preset" —
  all of these expected to show a yes/no confirmation but the
  dialog never appeared, and (because the underlying gate
  defaulted to "cancel") the action silently did nothing. The
  root cause was a Tauri webview behavior on macOS that drops
  browser confirm() calls without a dialog. CentProof now uses
  Tauri's native confirmation plugin, which produces a real macOS
  sheet with title, message, and labeled action buttons. **If you
  hit this in v0.1.7 and concluded a feature was broken — try
  again after updating.** The Schedule C preset, in particular,
  was completely blocked.

- **Backend error messages were not reaching the user.** When the
  sidecar rejected an action (e.g., "can't delete a category that
  still has transactions"), the catch handler tried to display
  the message via the same dropped-dialog mechanism above, so the
  user saw no feedback at all. CentProof now uses the same toast
  notification system as Tax Summary and Settlement for delete /
  restore / empty-trash feedback in Categories, Entities, and
  Trash — success and error messages alike.

- **Category and Entity delete sometimes refused on rows the UI
  said were UNUSED.** If you tagged a transaction with a category
  or entity and later trashed the statement that transaction
  belonged to, the Categories / Entities lists correctly showed
  the tag as UNUSED — but clicking Delete still failed with "1
  transactions still reference it." The list count and the delete
  check were using different filters: the list excluded
  trashed-statement rows, the delete didn't. CentProof now uses
  the same filter for both, and silently clears the dangling
  pointer on the trashed-statement row inside the delete (audit
  log records the count). The UI's UNUSED badge now reliably
  means "safe to delete."

- **Tax Summary "Save as PDF" producing no file in the desktop
  app.** A first-pass implementation relied on the browser's
  window.print() API, which Tauri's macOS webview silently drops.
  Switched to the same jsPDF + native save-dialog path Settlement
  Report already uses. Click now actually produces a file.

- **Chase Business Complete Checking statements with no deposits
  that period.** v0.1.7's business-statement support relied on a
  "deposits and additions" section marker to recognize a Chase
  business statement. Quiet months with only one Electronic
  Withdrawal (and no deposits) lacked that marker, so the parser
  fell back to the personal-Chase path and extracted zero
  transactions — reconciliation came up off by the withdrawal
  total. The detection now matches any of the five Chase business
  section markers, so quiet-month statements parse correctly and
  reconcile to the cent.

- **Settlement Report date inputs visually showed today's date
  but the report listed historical transactions.** The empty-input
  placeholder in macOS rendered as today's date, indistinguishable
  from a real value. After clicking Run, the From / To inputs now
  auto-fill to the actual data range of the returned rows so
  what's on screen matches what the inputs say.

### Changed

- **Settlement Report now uses toast notifications instead of
  native dialogs for save and export feedback.** Brings the
  Settlement screen in line with the rest of the app (Tax Summary,
  Cleanup Inbox, Categories, Search). Non-blocking, auto-dismiss,
  and clearly visually distinct between success and error.

- **"Move to Trash" confirm dialog now matches the actual
  behavior.** Previous text read "Delete this statement and all
  its transactions?" — which was scary and inaccurate, since
  trashing is recoverable for 30 days. The new prompt names the
  specific statement (filename and period) and explains that
  it'll stay recoverable for 30 days via the Trash tab before
  being purged permanently. Action buttons are now labeled
  "Move to Trash" and "Keep" instead of generic OK / Cancel.

### Notes for existing users

- **One safe database migration.** Manual entries gained an
  optional account_id column to power the Tax Summary use case;
  the migration runs automatically on first launch and is
  additive, so all your existing Settlement manual entries carry
  forward unchanged.
- **No change to existing supported-bank behavior.** PDFs from
  the nine supported banks still take the same verified-parser
  path. The Chase fix only affects Chase business checking
  statements that previously produced zero transactions on quiet
  months.
- **Tax Summary works on existing data.** No re-import needed.
  Open the new Reports → Tax Summary tab, pick a period, and
  compute — every reconciled statement you've already ingested
  contributes immediately.
- **If destructive actions seemed broken on v0.1.7 — they were.**
  See the confirm-dialog fix in Fixed above. Re-try anything you
  had given up on (deleting a category, trashing a statement,
  adding the Schedule C preset).

---

## v0.1.7 — 2026-05-29

### Added

- **Smart merchant recognition for 280+ common US merchants.**
  CentProof now recognizes Amazon, all major gas stations
  (76, ARCO, Chevron, Shell, Costco Gas, BP, and more), top SaaS
  subscriptions (Claude.ai, OpenAI, GitHub, AWS, Netflix, Spotify,
  Adobe, Microsoft, etc.), every major retailer, restaurant chain,
  travel provider, and telecom — instantly and locally, no AI
  inference needed. Combined with the existing AI suggestion
  pipeline, common merchants now tag themselves on import with
  no waiting and 100% deterministic results.

- **One-click entity + category tagging.** The Set Entity dialog
  now has an optional "Also set a category for this pattern"
  section. Check the box, pick a category, save once — both a
  tag rule for entity AND a tag rule for category are created
  together using the same match pattern. No more forgetting to
  set the category half of the rule and discovering on the next
  month's import that entity auto-tagged but category stayed
  empty.

- **Edit / rename entities and categories.** The Entities and
  Categories tabs both have an Edit button on each row. Type a
  new name and every tagged transaction immediately shows the
  updated display name — correction rules, historical tags, and
  source-row references are all preserved. Useful for cleaning
  up names like "amazon" → "Amazon" or "AT&T Wireless" → "AT&T"
  without having to delete + re-tag.

- **Chase Business Complete Checking support.** Chase business
  checking statements (Business Complete, Performance Business,
  Performance Business with Interest, Platinum Business, Analysis
  Business — any "Chase ... Checking" product name) now
  fingerprint and parse correctly, with full reconciliation to
  the cent. Previously these produced the "unsupported PDF"
  dialog despite Chase being a supported bank.

- **Documentation site at centproof.com/docs.** A new
  how-to-use-the-app reference with seven guides covering quick
  start, importing statements, reviewing and reconciling, tagging
  entities and categories, asking the local AI, reports and
  exports, and backup and recovery. The in-app Help → Docs menu
  now opens this section instead of the homepage.

### Fixed

- **Auto-update restart race.** Some users reported that clicking
  "Restart now" the instant it appeared during an update did
  nothing — the app restarted on the OLD version instead of the
  new one. The Restart button now appears only after the install
  actually completes (not just after the download completes), so
  fast-clickers can't accidentally restart mid-install and boot
  the old binary.

- **Auto-tag suggestions running on already-tagged transactions.**
  The local AI was generating suggestions for every transaction
  on every import — even rows that already had both their entity
  AND category set by correction rules. AI now runs only on rows
  that actually need it. Imports complete noticeably faster on
  statements where most rows match existing rules.

### Notes for existing users

- **No database changes.** v0.1.6 → v0.1.7 upgrades cleanly with
  no migration. All your tagged transactions, correction rules,
  entities, categories, and saved reports carry forward
  identically.
- **No change to existing supported-bank behavior.** PDFs from
  any of the nine supported banks still take the same verified-
  parser path. The Chase business-statement fix only affects
  Chase business checking products that previously failed
  fingerprinting.
- **First-update tip.** When the v0.1.7 update prompt appears,
  click "Restart now" as usual. Because the race-condition fix
  lives IN v0.1.7, the v0.1.6 → v0.1.7 upgrade itself uses
  v0.1.6's old updater code — so a very fast click could
  occasionally bite the same race (uncommon). If it does, just
  open Preferences → About and click "Check for updates" again;
  it'll complete normally. From v0.1.7 onward, future updates
  use the fixed flow forever.

---

## v0.1.6 — 2026-05-27

### Added

- **Best-effort extraction for unsupported bank PDFs.** When you drop in
  a statement from a bank or card issuer CentProof doesn't yet have a
  verified parser for, you now get an opt-in dialog with three choices
  instead of a dead-end error:
  - **Try best-effort extraction** — run a generic heuristic parser
    that looks for date / description / amount patterns anywhere in the
    PDF and shows you what it could pull out. The result is read-only —
    nothing is saved to your imports — so it's safe to try even when
    the rows might be imprecise. Side-by-side amount/balance columns,
    multi-line descriptions, and non-standard layouts may produce
    partial or incorrect rows; the result screen tells you whether the
    extracted rows reconcile against the statement's opening and
    closing balance under either checking-account or credit-card sign
    conventions.
  - **Send us a sample** — opens
    [centproof.com/banks/share-sample](https://centproof.com/banks/share-sample)
    in your browser with the bank name and app version pre-filled. The
    page walks you through redacting personal fields, then you email
    the redacted PDF directly to support — nothing is uploaded from
    the app itself. New parsers typically ship in the next maintenance
    release (1–2 weeks).
  - **Cancel** — closes the dialog with no side effects. Identical to
    the pre-v0.1.6 behavior after dismissing the alert.
- **Best-effort preview screen** with extracted-row table, balance
  detection, reconciliation status (tried under both sign conventions),
  parser diagnostics (lines scanned, headers rejected, ambiguous
  dates), and an inline "Send sample" CTA that pre-fills the bank
  name you confirm.

### Changed

- The previous "Unsupported PDF" browser alert is replaced with the
  new three-option dialog. Users who just want to dismiss can still
  do so with one click (Cancel) — the new flow strictly adds choices
  rather than replacing the dismissal path.

### Notes for existing users

- **No database changes.** Best-effort imports are preview-only in
  v0.1.6 and never write to your local database. Existing imported
  statements, accounts, transactions, tags, and reports are untouched.
- **No change to supported-bank behavior.** PDFs from any of the nine
  supported banks (Chase, Wells Fargo, BoA, Capital One, Apple Card,
  American Express, Discover, Citi, US Bank) take the same verified-
  parser path they did in v0.1.5. The new dialog only appears when the
  PDF can't be fingerprinted to a known bank.

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
