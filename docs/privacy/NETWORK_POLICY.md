# Network Policy

**The core clinical workflow makes no network request.** Not "few", not
"only anonymous telemetry". None.

This is the practical form of Privacy PRI-003, PRD §31, Technical Architecture
§34, AI §8 and Build Specification §2.3.

---

## Four layers of enforcement

### 1. No call sites

Capture, storage, the database, CV, measurement, annotation, comparison and
export contain no code that opens a connection. No HTTP client is a dependency
of this project. **This absence is the actual guarantee** — everything below
exists to keep it true.

### 2. No `INTERNET` permission on Android

`android/app/src/main/AndroidManifest.xml` declares no `INTERNET` permission.
The operating system, not a convention, prevents a network connection. CI fails
if the permission appears.

Adding it would be a deliberate, reviewable act — which is precisely the
visibility Build Specification §72 asks for when it says network features must
be isolated so traffic can be audited.

### 3. `NetworkGuard`

Every future outbound request must pass `NetworkGuard.authorize`. It refuses
when Privacy Mode is on, or when a request carries an image and cloud AI is
disabled. Every attempt is recorded whether allowed or not.

The guard is the audit facility Build Specification §73 requires: it is what
lets a test demonstrate `core capture → no external image request`.

### 4. An automated test that says so

`test/privacy/network_policy_test.dart` runs the complete clinical workflow —
create Before, thumbnail, prepare reference, align, capture After, calibrate,
measure, annotate, compare, export, anonymize — and asserts the audit log is
**empty**.

That test fails if anyone adds a network call anywhere in the core, and it says
which purpose string caused it.

---

## What could ever go over a network

Nothing today. If a future release adds an opt-in cloud feature, it must:

1. be behind a feature flag, off by default (AI §56)
2. be explicitly enabled by the user (AI §67)
3. call `NetworkGuard.authorize` with `carriesImage` set truthfully
4. add the `INTERNET` permission in the same change that updates this document
5. disclose the processing location in the UI (Functional PRI-003)
6. be refused unconditionally under Privacy Mode

Points 4 and 6 are the ones that matter most: a user in Privacy Mode has said
no, and no configuration may override that.

---

## Privacy Mode

Default **on** for a new user (Build Specification §2.10: privacy is a default,
not an advanced configuration).

| With Privacy Mode on | Behaviour |
|---|---|
| Automatic Gallery copy | Never. `ALWAYS` is downgraded to `ASK`, not obeyed |
| Cloud AI | Refused |
| Third-party image processing | Refused |
| Image transmission of any kind | Refused by `NetworkGuard` |
| Local processing | Unaffected — everything in the core still works |

`test/unit/gallery_policy_test.dart` asserts that **no** combination of
settings produces an automatic Gallery copy while Privacy Mode is on.

---

## Backup

Clinical photographs and the database are excluded from Android cloud backup
and device-to-device transfer
(`android/app/src/main/res/xml/data_extraction_rules.xml`).

Automatic backup would be an unaudited copy of clinical images in a third-party
cloud, which PRI-003 forbids as squarely as an upload from the app itself. A
deliberate, user-controlled backup is a separate future feature (Data Model
§58).

---

## Logging

`AppLogger` accepts a message and scalar fields. It cannot be handed an image.
It redacts sensitive keys, reduces filesystem paths to their basename, and
summarises collections and long strings by shape rather than content. Debug
logging is dropped entirely in production builds.

Development builds may log CV metrics — keypoint counts, inlier ratios,
transforms, timings. Those carry no image content and are what CV §79 permits.

---

## Verifying this yourself

```bash
flutter test test/privacy/network_policy_test.dart   # empty audit log
grep -rn "INTERNET" android/app/src/main/AndroidManifest.xml   # no match
grep -rn "package:http\|package:dio\|HttpClient" lib/          # no match
```

On a device: airplane mode, run the entire workflow, confirm nothing degrades
(device test D-OFF-01). Then with a network monitor attached, run it again and
confirm zero outbound requests (D-OFF-03).
