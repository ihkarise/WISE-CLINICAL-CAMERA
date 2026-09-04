# Test Strategy

Build Specification §74 prescribes the directory structure; §75-80 prescribe
what must be covered. This records what exists, what it establishes, and what
it deliberately does not.

---

## Layout

```text
test/
├── support/       shared harness and the synthetic CV dataset
├── unit/          pure logic: settings, measurement, guidance, readiness
├── widget/        screen composition and accessibility
├── integration/   the end-to-end clinical workflow
├── database/      schema, migrations, repositories against real SQLite
├── cv/            alignment regression and false confidence
├── privacy/       the P0 privacy invariants
├── security/      (folded into privacy/; see below)
└── performance/   (device-dependent; see DEVICE_TEST_PLAN.md)
```

`security/` and `performance/` exist as directories but hold no tests. Security
properties that *can* be asserted in a unit test — log redaction, metadata
stripping, network policy, no hard-coded secrets — are asserted in `privacy/`,
because splitting them would obscure that they are one concern. Performance is
device-dependent and lives in the device test plan; measuring it on a desktop VM
would produce numbers that mislead.

---

## Principles

**Test the property, not the implementation.** The immutability suite hashes a
file before and after everything the app can do to it, rather than asserting
that a particular method was not called. That survives refactoring and catches
routes nobody thought of.

**Use the real thing where it is cheap.** `sqflite_common_ffi` runs actual
SQLite, so foreign keys, CHECK constraints and transaction rollback are
exercised rather than mocked. A mocked database would accept a self-referencing
photo row; real SQLite rejects it.

**Assert the safe direction, not the happy one.** The CV suite mostly asserts
that the engine *declines* — on repeating patterns, corner-only detail,
occlusion, unrelated scenes. Those are the cases where a wrong answer causes
harm.

**Name the requirement.** Every test file names the specification sections it
covers, so a change to a requirement can be traced to the tests that pin it.

---

## What each suite establishes

### `unit/`

| File | Establishes |
|---|---|
| `effective_settings_test.dart` | The precedence chain in both directions, that a session override never mutates a default, and that a platform limitation vetoes every layer |
| `measurement_test.dart` | Calibration mathematics, every rejection case, the specification's worked examples, and that no path produces centimetres without calibration |
| `guidance_engine_test.dart` | Correct direction and priority, and that no user-facing string contains a CV term |
| `capture_readiness_test.dart` | That capture stays possible through every advisory warning, and that only an unavailable camera or a deliberately configured protocol blocks it |
| `gallery_policy_test.dart` | That no configuration produces an automatic Gallery copy under Privacy Mode |

### `database/`

Schema shape, foreign key enforcement per connection, indexes, contiguous
migration numbering, a v1-to-current upgrade with rows intact, photo CRUD, the
Before/After relationship both ways, self-reference rejection at the schema
level, the deletion policy, and checksum integrity including detection of a
corrupted original.

### `cv/`

Geometric accuracy against synthetic ground truth: translation, rotation and
scale recovered to within about 2 %. Then the cases that matter more — low
texture, repeating patterns, spatially concentrated detail, occlusion,
unrelated scenes — where the engine must decline rather than guess. Every gate
in `ConfidenceModel` is asserted individually, as is the absence of CV
terminology from every user-facing string.

### `privacy/`

The three P0 invariants:

- an original is byte-identical after a full annotate/measure/export/anonymize
  cycle, verified by SHA-256
- the complete clinical workflow produces an empty network audit log
- log redaction, EXIF stripping, and the absence of any GPS field

### `integration/`

The exact sequence Build Specification §81 names, against a real database and
filesystem, ending with an assertion that the Before original is unchanged.

### `widget/`

That the home screen presents three primary actions and not a dashboard, that
their accessibility labels exist, and that AFTER routes through reference
selection rather than straight to the camera.

---

## What is deliberately not tested here

| Not tested | Why | Where instead |
|---|---|---|
| Real camera behaviour | No device | `DEVICE_TEST_PLAN.md` §1 |
| Real sensors | No device | §2 |
| Alignment on clinical images | No dataset, and none may be committed | §3 |
| Measurement accuracy in the real world | Needs physical objects and a camera | §5 |
| Gallery permissions | Platform behaviour | §6 |
| Performance, memory, thermal, battery | Device-dependent | §7 |
| Accessibility with a real screen reader | Semantics are asserted; the experience is not | §9 |

A test that mocked these would produce a green tick with no information behind
it, which is worse than an honest gap.

---

## Running

```bash
flutter test                    # everything
tool/test.sh                    # the same, summary and failures only
flutter test test/privacy/      # the P0 privacy suite
flutter test test/cv/           # alignment and false confidence
flutter test --coverage         # writes coverage/lcov.info
```

CI runs the privacy, CV and integration suites as separate jobs, so a failure
in any of them is unmissable rather than buried in unrelated output.

---

## Adding a test

1. Put it in the directory matching its concern.
2. Name the specification sections in the file's doc comment.
3. Assert the property, not the call sequence.
4. For a bug fix, write the failing test first — every "Fixed" entry in the
   changelog was found by one.
