# Security Review: Offline Damage Saves

## Scope

This review covers the offline damage-save flow and the proposed persistent
local queue. It is not a full application security audit.

## Findings

| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|
| 1 | 🟡 MEDIUM | `lib/providers/Datafeed.dart` | 1302-1305 | Pending damage records are carried across refreshes without filtering them by company or authenticated user. Because logout does not clear or partition this in-memory list, a pending record from one account/company can appear in another account's damage list on the same app instance. | 8/10 |

### Details and recommended fix

The pending damage list is retained before a company-filtered Firestore query
runs. Filter pending records by both the original Firebase user ID and company
ID whenever listing or syncing. Keep records associated with their original
account while offline; do not display or sync them under another account.
Enforce company membership and matching `companyid` in Firestore Security Rules.

The deployed Firestore rules were not present in the reviewed workspace, so
server-side tenant authorization could not be verified.

## Offline persistence and data protection

- Firestore's built-in offline persistence is the simplest cost-free option
  when its behavior meets the app's needs. It can queue writes and retry when
  connectivity returns, but it does not replace account/company isolation or
  Firestore Security Rules.
- Persistence setup in `lib/main.dart` catches setup failures. Test actual
  offline behavior on each supported target, especially web and desktop.
- The current `Datafeed.damages` pending list is in memory; it is not an
  independent durable queue that the application controls.
- If an independent durable queue is required, use a transactional local store
  such as Hive, partition every record by Firebase user ID and company ID, and
  encrypt sensitive payloads with keys stored using platform-appropriate
  secure storage. Hive's default storage is not encrypted. Do not store damage
  payloads in `shared_preferences`; it is not an encrypted transactional
  queue.
- Encryption does not protect against malicious code executing in the web
  app's origin, and browser persistence should be treated as accessible to
  same-origin code.
- Dispose stream subscriptions and close local storage resources on provider
  shutdown. Do not discard unsynced records just because a screen or provider
  is disposed; preserve them for the original account to retry after restart.

## Recommended implementation order

1. Add user/company ownership to pending records and filter all pending reads
   and sync attempts by that ownership.
2. Verify Firestore rules enforce authentication, company membership, and
   matching company IDs for damage writes.
3. Prefer Firestore's offline write queue unless testing proves a separate
   durable queue is needed. If one is needed, add encrypted, account-scoped
   storage with an explicit retry and disposal lifecycle.
