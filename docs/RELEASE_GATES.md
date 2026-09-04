# Release Gates

**Document:** `docs/RELEASE_GATES.md`
**Product:** WISE Clinical Camera · WiseAiTechs
**Last Updated:** 2026-09-04

The states a build passes through, and what must be true to leave each one.
"Buildable", "installable", "usable", "product-polished", "device-validated"
and "production-ready" are **distinct** states. Passing automated tests never
by itself advances a gate that requires device evidence.

| Gate | Definition of done | Status |
|---|---|---|
| **G0 Buildable** | CI green: format, analyze (`--fatal-infos --fatal-warnings`), `flutter test`, Android/iOS/Linux builds. | **PASS** — 563 tests green; APK built by CI. |
| **G1 MVP-1 Usable** | Core capture workflow exercised on a real Android device (see [`FAST_TRACK_MVP.md`](FAST_TRACK_MVP.md)). | **PASS** — first device validation completed by owner. |
| **G2 MVP-2 Functionally complete + product-polished** | User-created protocols; import BEFORE with metadata; persistent BEFORE; Before+After combined export; WISE brand icon/splash/identity. Software-implemented **and** device-checked per the MVP-2 checklist. | **SOFTWARE DONE / DEVICE PENDING** — see [`MVP_2_PRODUCT_COMPLETION.md`](MVP_2_PRODUCT_COMPLETION.md) §10. |
| **G3 iOS device validation** | Same core workflow validated on a real iOS device. | PENDING |
| **G4 Evidence validation** | CV alignment, photographic measurement and performance validated against real datasets (not synthetic analogues). | PENDING |
| **G5 Security decision** | At-rest encryption / storage-security decision resolved (SPECIFICATION_CONFLICTS C-019). | PENDING |
| **G6 Release candidate** | Production signing, store metadata/listing, privacy review, pilot plan. | PENDING |

## Standing rules for every gate

- Device rows are marked from **observed device behaviour**, never from source
  inspection, an emulator, or CI alone.
- No INTERNET permission in the Android manifest; the core workflow makes no
  network request (Privacy PRI-003, enforced in CI).
- Originals are immutable; exports are derived and non-destructive.
- Do not commit clinical photographs to the repository — synthetic subjects
  only (Privacy §52).
- If the project needs to remember it, GitHub must remember it.
