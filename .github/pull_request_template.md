## What changed

<!-- One or two sentences. What does this do, and why now? -->

## Specification reference

<!-- Which requirement or section this implements, e.g. Functional MES-004,
     Computer Vision section 23. If it resolves an entry in
     docs/SPECIFICATION_CONFLICTS.md, say which. -->

## Invariants

Confirm the six cross-cutting invariants still hold (see
`docs/PROJECT_KNOWLEDGE_MAP.md`):

- [ ] Originals are never modified
- [ ] No silent upload; the core workflow makes no network request
- [ ] No physical units without a valid calibration
- [ ] Persistent preferences are not rewritten by a session override
- [ ] Capture remains possible through advisory warnings
- [ ] Confidence is not presented as clinical accuracy

## Verification

- [ ] `dart format` clean
- [ ] `flutter analyze` clean
- [ ] `flutter test` passing
- [ ] New behaviour is covered by a test
- [ ] Device testing needed? If so, note what in
      `docs/testing/DEVICE_TEST_PLAN.md`

## Thresholds

- [ ] No new hard-coded CV, blur, lighting or alignment threshold; anything
      tunable lives in `AlignmentConfig` or `QualityConfig` and is documented
      in `docs/cv/THRESHOLDS.md`
