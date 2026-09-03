# AI Strategy

**V1 ships with no AI provider registered.** Every `AiService.analyze` call
returns `AiUnavailable`, and nothing in capture, storage, computer vision,
measurement, annotation, comparison or export notices.

That is not a gap. It is the specified state:

> "The core application must function with `AI = OFF`." — Build Specification §2.4
>
> "Mandatory per-photo AI API cost = $0." — AI & Cost Strategy §64
>
> "Cloud AI = OFF." — AI & Cost Strategy §65

---

## The escalation order

AI §4-5 and Build Specification §66 define a hierarchy. A higher-cost layer is
reached only when no lower one can serve the request.

```text
Device sensors            ← level, tilt, orientation
        ↓
Classical computer vision ← where WISE actually operates today
        ↓
On-device ML              ← no model ships in V1
        ↓
Self-hosted AI            ← interface only
        ↓
Cloud AI                  ← interface only, off by default
```

Everything the product needs to do today sits in the first two layers. Sensors
give orientation and tilt; classical CV gives alignment, guidance, lighting and
focus. **No paid API is called for any of it**, which is the point of AI §64.

`AiService._orderedProviders` sorts by `AiProcessingLocation`, so on-device is
always tried before self-hosted, and self-hosted before cloud.

---

## Why the abstraction exists with nothing behind it

AI §47 (vendor lock-in) and Build Specification §64 require that no feature
depends on a specific vendor. The abstraction exists so that:

- **no vendor SDK is imported anywhere in this codebase** — check `pubspec.yaml`
- a future provider registers against `AiProvider` without a feature changing
- the privacy path is already built and tested before any provider exists

`DisabledAiProvider` is registered in tests to exercise the abstraction. It
never runs a model and never touches the network.

---

## The privacy path, built before it is needed

A provider whose `location.leavesDevice` is true must clear `NetworkGuard`
before `analyze` is called. The guard refuses when:

- Privacy Mode is on, or
- the request carries an image and cloud AI is disabled

If no guard is configured, `AiService` **fails closed** rather than transmitting
unaudited. Failing closed is the required direction (Privacy PRI-003).

`test/privacy/network_policy_test.dart` proves a cloud provider is refused under
Privacy Mode, and that the image never leaves.

---

## Feature flags

AI §56 requires each AI capability to be independently flagged:

```dart
onDeviceAi, cloudAi,
aiBodyRegionDetection, aiLandmarkDetection, aiOcr, aiReportAssistance
```

All default `false`. `FeatureFlags.aiFullyDisabled` asserts the whole set is
off, and a test pins it so the default cannot drift.

---

## What AI would be good for, in order

AI §66 and §31 of the PRD, roughly in value order:

1. **Body-region assistance.** A lightweight on-device model suggesting the body
   part, so the clinician does not pick from an 18-item list. Small, on-device,
   no recurring cost, and wrong answers are cheap because the field is optional.
2. **Landmark detection** to make alignment more robust on low-texture anatomy —
   the case where classical CV genuinely struggles (CV §46).
3. **On-device OCR** for document capture, using the platform's own OCR rather
   than an API.
4. **Report assistance**, and only after the local product is stable.

## What AI must not do

AI §32, Functional §44, Build Specification §113:

- No diagnosis, disease classification or treatment recommendation
- No claim of clinical improvement from a photographic difference
- No modification of an original clinical photograph
- No silent upload, under any configuration

Any AI output is labelled `AI-generated assistance` and, while experimental,
carries the experimental notice. `AiResult` carries `location` and
`isExperimental` on every result so the UI cannot omit them by accident.

---

## Cost, if a cloud provider is ever added

AI §37 requires guardrails: request limits, a monthly budget, provider and model
selection, Wi-Fi only, and usage statistics. None is built, because none is
needed for a product with no provider — Build Specification §68 says explicitly
not to build billing infrastructure in V1.

What *is* built is the place they attach: `AiProvider.getUsage` is in the
interface, and `NetworkGuard`'s audit log already records every attempt.

Two rules from AI §6 and §26 worth writing down before anyone implements a
provider:

- **Never run AI on every frame.** Sensors and CV handle the live path.
- **Never send a full-resolution clinical original.** Downscale first
  (AI §25), and never compress the original itself (AI §27).

---

## Adding a provider

1. Implement `AiProvider`; declare `location` honestly.
2. Register it in `aiServiceProvider`.
3. Add a feature flag, defaulting to `false`.
4. Set `carriesImage` truthfully on every request — the guard's guarantee
   depends on it.
5. Add a test proving it is refused under Privacy Mode.
6. Update `docs/privacy/NETWORK_POLICY.md` in the same change, including the
   `INTERNET` permission if the provider is remote.

Step 6 is not paperwork. The permission's absence is currently enforced by CI,
so adding a remote provider necessarily makes the change visible in review.
