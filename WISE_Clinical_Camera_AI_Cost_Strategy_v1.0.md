# WISE Clinical Camera
## AI & Cost Strategy v1.0

**Product:** WISE Clinical Camera  
**Purpose:** Define where AI should be used, where it should not be used, how to minimize operating cost, how to protect clinical images, and how to keep the product scalable without making cloud AI a dependency.

**Platforms:** iOS and Android  
**Architecture:** Flutter + native camera/sensor bridges + local computer vision + optional AI services.

---

# 1. Executive Strategy

WISE Clinical Camera should **not be an AI-first camera in the sense of sending every photograph to an AI model**.

It should be:

> **A camera-first clinical reproducibility system with AI available only where AI creates meaningful additional value.**

The preferred processing hierarchy is:

```text
Device Sensors
        ↓
Classical Computer Vision
        ↓
On-Device ML
        ↓
Self-Hosted AI
        ↓
Cloud AI
```

This architecture minimizes:

- cost
- latency
- network dependency
- privacy exposure
- vendor lock-in
- infrastructure complexity

It also keeps the core product useful when the Internet is unavailable.

---

# 2. Core Cost Principle

The most important cost decision is:

> **Do not use a paid AI API for something that can be solved deterministically on the device.**

Examples:

| Function | Preferred technology |
|---|---|
| Level | Gyroscope/accelerometer |
| Orientation | Device sensors |
| Grid | UI rendering |
| Zoom matching | Camera metadata |
| Basic alignment | Computer vision |
| Feature matching | Local CV |
| Blur detection | Local CV |
| Lighting check | Local image statistics |
| Measurement | Geometry + calibration |
| Annotation | Local rendering |
| Comparison | Local image processing |
| OCR | On-device OCR |
| Body-region detection | On-device ML |
| Image explanation | Optional AI |
| Report assistance | Optional AI |
| Complex reasoning | Optional cloud/self-hosted AI |

---

# 3. AI Is Optional

The following must work without any cloud AI:

```text
BEFORE
AFTER
PHOTO
Reference Overlay
Alignment
Lighting Check
Focus Check
Grid
Level
Calibration
Measurement
Annotation
Comparison
Export
```

AI must not become a hidden dependency.

---

# 4. AI Capability Tiers

WISE should use four practical AI tiers.

## Tier 0 — No AI

Pure deterministic processing.

Examples:

- camera controls
- grid
- level
- measurement
- annotations
- file handling

Cost:

```text
≈ $0 per image
```

after the device/app development cost.

---

## Tier 1 — Classical Computer Vision

Examples:

- ORB/AKAZE-style feature matching
- RANSAC
- homography
- template matching
- edge matching
- optical flow
- Laplacian sharpness
- luminance analysis

Cost:

```text
No per-image API charge
```

Processing happens locally.

---

## Tier 2 — On-Device ML

Examples:

- body-region recognition
- landmark detection
- subject segmentation
- automatic ROI selection
- image-quality classification
- optional OCR

Cost model:

```text
Model development
+
App/package size
+
Device CPU/GPU/battery
```

There is normally no per-image cloud inference bill.

---

## Tier 3 — Self-Hosted AI

Examples:

- private clinic AI
- local server
- private cloud
- WISE-controlled inference server

Useful when:

- data cannot leave an organization
- multiple devices need a shared model
- the model is too large for mobile
- high-volume inference is required

Cost model:

```text
Server
+
GPU/CPU
+
Storage
+
Maintenance
```

---

## Tier 4 — Cloud AI

Use only where it provides significant value unavailable locally.

Examples:

- advanced image understanding
- complex report assistance
- natural-language explanation
- advanced multimodal workflows
- future AI assistant features

Cost model:

```text
API usage
+
network
+
privacy controls
+
vendor dependency
```

---

# 5. AI Decision Rule

Before adding AI, ask:

```text
Can sensors solve it?
        ↓ yes
Use sensors.

Can deterministic CV solve it?
        ↓ yes
Use CV.

Can lightweight on-device ML solve it?
        ↓ yes
Use on-device ML.

Does it require larger reasoning?
        ↓ yes
Consider self-hosted AI.

Does it require frontier intelligence?
        ↓ yes
Consider cloud AI.
```

---

# 6. AI Should Not Run on Every Frame

This is one of the most important cost/performance rules.

Do not:

```text
Camera frame
 ↓
Cloud AI
 ↓
Camera frame
 ↓
Cloud AI
```

Instead:

```text
Camera
 ↓
Local sensors/CV
 ↓
Occasional ML
 ↓
Capture
 ↓
Optional AI analysis
```

Real-time alignment should be local.

---

# 7. AI Trigger Strategy

AI processing should be event-driven.

Examples:

```text
User requests AI
User captures image
User selects "Analyze"
User requests report assistance
```

Avoid continuous AI inference unless there is a validated reason.

---

# 8. AI Image Upload Policy

Default:

```text
Image stays on device.
```

If cloud AI is enabled:

```text
User action
 ↓
Privacy notice
 ↓
Explicit authorization
 ↓
Secure upload
 ↓
AI processing
 ↓
Result
```

No silent cloud fallback.

---

# 9. Cloud AI Cost Model

For token-based models:

```text
Cost =
(input tokens × input price)
+
(output tokens × output price)
+
tool/image-specific charges
```

For image workflows, actual cost depends on how the provider tokenizes image input and what output/tool calls are used.

Therefore, production cost calculations should use measured request sizes rather than assuming a fixed "cost per image."

---

# 10. Current API Cost Benchmarks

These are indicative public API prices and should be rechecked before implementation because provider pricing changes.

## OpenAI

Current published pricing includes:

- GPT-5.4 mini: $0.75 / 1M input tokens and $4.50 / 1M output tokens
- GPT-5.4 nano: $0.20 / 1M input tokens and $1.25 / 1M output tokens citeturn0search6turn0search7

Older GPT-5 mini/nano pricing is also published at $0.25/$2 and $0.05/$0.40 per 1M input/output tokens respectively. citeturn0search2turn0search4

## Anthropic

Claude Haiku 4.5 is currently listed at:

```text
$1 / 1M input tokens
$5 / 1M output tokens
```

Anthropic also lists lower batch-processing prices. citeturn0search0turn0search9

## Google Gemini

Google's current Gemini API pricing lists low-cost models including Gemini 3.1 Flash-Lite at:

```text
$0.25 / 1M input tokens
$1.50 / 1M output tokens
```

and Gemini 2.5 Flash at:

```text
$0.30 / 1M input tokens
$2.50 / 1M output tokens
```

with additional pricing depending on modality and service tier. citeturn0search1

These prices are useful for architecture decisions, but **they should not be treated as a permanent WISE operating-cost assumption**.

---

# 11. Open-Weight AI Option

Open-weight models can be useful where WISE eventually wants more control over data and inference.

OpenAI currently provides gpt-oss-20b and gpt-oss-120b as open-weight models that can run on infrastructure controlled by the developer or through hosting providers. OpenAI states that gpt-oss-20b can run on edge devices with around 16 GB memory, while gpt-oss-120b is designed for efficient operation on a single 80 GB GPU. citeturn0search5turn0search8

For WISE, this means:

```text
Local/private AI
      ↓
No per-request vendor API bill
```

but it does **not** mean zero cost.

There are still:

- hardware costs
- power costs
- engineering costs
- model maintenance
- deployment costs

---

# 12. Cost Categories

WISE AI cost should be divided into:

```text
Development Cost
Infrastructure Cost
Inference Cost
Storage Cost
Network Cost
Maintenance Cost
Privacy/Security Cost
```

A cheap API is not automatically the cheapest architecture.

---

# 13. Development Cost

Development is likely to dominate the early project cost.

Prioritize reusable modules:

```text
CV Engine
AI Abstraction
Image Pipeline
Privacy Layer
Export Engine
```

These should be reusable across future WISE applications.

---

# 14. Infrastructure Cost

V1 should aim for:

```text
$0 mandatory AI infrastructure
```

because core AI/CV features should run locally.

Optional infrastructure can be added later.

---

# 15. Cloud Cost

The product should not require:

```text
database server
+
image server
+
AI server
```

just to take a photograph.

Cloud infrastructure should be introduced only when a specific feature justifies it.

---

# 16. Recommended V1 Cost Architecture

```text
Mobile Device
 ├── Camera
 ├── SQLite
 ├── Local Files
 ├── CV
 ├── Measurements
 ├── Annotations
 └── Optional On-Device ML

No mandatory server
No mandatory AI API
No mandatory cloud storage
```

This gives WISE a very low baseline operating cost.

---

# 17. AI Gateway Architecture

AI should be hidden behind an abstraction.

Conceptual:

```text
WISE AI Service
      │
      ├── LocalAIProvider
      ├── OnDeviceAIProvider
      ├── SelfHostedAIProvider
      └── CloudAIProvider
```

The rest of the application should call:

```text
AIService.analyze(...)
```

rather than directly calling a specific vendor.

---

# 18. Provider Configuration

Possible configuration:

```text
AI Mode

OFF
ON-DEVICE
SELF-HOSTED
CLOUD
AUTO
```

Recommended default:

```text
OFF
```

or:

```text
ON-DEVICE
```

when a validated local model exists.

---

# 19. AUTO Mode

AUTO should follow:

```text
On-device capability
      ↓
Local CV
      ↓
Self-hosted endpoint
      ↓
Cloud
```

However, AUTO must never silently upload clinical images.

Cloud fallback must require explicit prior configuration and authorization.

---

# 20. Cost-Aware Routing

AI requests can be classified:

```text
TRIVIAL
STANDARD
COMPLEX
```

Then route accordingly.

Example:

```text
Image classification
→ local model

Simple text generation
→ low-cost API

Complex multimodal reasoning
→ stronger model
```

---

# 21. Model Escalation

Do not send every task to the strongest model.

Recommended:

```text
Cheap model
   ↓
Check confidence
   ↓
If insufficient:
Stronger model
```

This can significantly reduce cost.

---

# 22. Caching

Cache reusable AI context where provider support makes this economical.

Examples:

- fixed system instructions
- protocol definitions
- standard report templates
- recurring structured prompts

Do not cache sensitive clinical images longer than necessary.

---

# 23. Batch Processing

Use batch processing for non-urgent jobs when supported.

Examples:

- historical photo organization
- bulk metadata processing
- offline report preparation
- dataset analysis

Do not use batch processing for interactive camera guidance.

---

# 24. Token Minimization

For text AI:

- use structured prompts
- avoid repeated long instructions
- use concise JSON schemas
- reuse stable system context
- avoid sending unnecessary history

---

# 25. Image Minimization

For AI image requests:

- crop to relevant region where appropriate
- resize to the minimum useful resolution
- avoid sending duplicate images
- avoid sending reference images when unnecessary
- avoid sending unrelated photographs

The original full-resolution image should remain local.

---

# 26. Image Processing Before AI

Recommended:

```text
Original
 ↓
Local preprocessing
 ↓
Relevant ROI
 ↓
Quality check
 ↓
Optional resize
 ↓
AI
```

This reduces:

- bandwidth
- cost
- latency
- privacy exposure

---

# 27. Do Not Compress Clinical Originals

Cost optimization must not mean damaging the original clinical photograph.

Instead:

```text
Original
 ↓
Derived AI input
```

The AI input can be resized separately.

---

# 28. AI Result Storage

Store:

```text
AI result
model
provider
model version
timestamp
request type
confidence if available
```

Do not store unnecessary prompt/request data containing sensitive content.

---

# 29. Model Versioning

Every AI result should identify:

```text
provider
model
model version/snapshot
engine version
```

This is important because model behaviour changes over time.

---

# 30. Reproducibility

If an AI-assisted workflow affects a clinical export, store enough information to understand:

```text
what model was used
when it was used
what operation was requested
```

Do not claim exact reproducibility if a provider's model can change.

---

# 31. AI Use Cases for WISE

## High Value

Potentially valuable:

- automatic body-region recognition
- landmark detection
- subject segmentation
- automatic ROI
- image-quality assessment
- OCR for external documents
- structured report assistance
- natural-language organization
- protocol assistance

---

# 32. AI Use Cases to Avoid in V1

Avoid making these core V1 dependencies:

- diagnosis
- treatment recommendation
- autonomous clinical interpretation
- disease progression claims
- cloud-based alignment
- AI-generated alteration of clinical photographs

---

# 33. AI and Clinical Photography Integrity

AI must never silently modify clinical evidence.

Allowed:

```text
Generate derived annotation
Generate segmentation
Generate description
```

Not allowed as default:

```text
Change lesion appearance
Remove clinical findings
Beautify skin
Alter wound
Generate missing anatomy
```

The original must always remain available.

---

# 34. Synthetic/Generative Images

Generative image tools should be separated from clinical evidence workflows.

If future educational or presentation features use generated images:

```text
Generated
```

must be clearly distinguishable from:

```text
Clinical Photograph
```

Never mix them silently.

---

# 35. Cost per User Model

WISE should track:

```text
AI requests/user/month
Input tokens/request
Output tokens/request
Images/request
Cloud inference cost
```

Then calculate:

```text
monthly AI cost per active user
```

---

# 36. Example Cost Calculation

Suppose a hypothetical text workflow uses:

```text
5,000 input tokens
1,000 output tokens
```

At GPT-5.4 mini's published rates:

```text
Input:
5,000 / 1,000,000 × $0.75
= $0.00375

Output:
1,000 / 1,000,000 × $4.50
= $0.00450

Total:
≈ $0.00825/request
```

This example is only a token-cost illustration. Actual image requests may have additional modality-specific pricing.

---

# 37. Cost Guardrails

Implement:

```text
daily request limit
monthly request limit
per-user budget
per-feature budget
```

where cloud AI is enabled.

---

# 38. User-Controlled AI

Settings should allow:

```text
AI Features
[ ON / OFF ]

Cloud AI
[ ON / OFF ]

Use cellular data
[ ON / OFF ]

Maximum monthly AI usage
[ setting ]
```

Exact controls can be introduced progressively.

---

# 39. Clinic-Level Controls

Future organizational deployments may require:

```text
Allow cloud AI
Allow self-hosted AI
Allow on-device AI
Maximum AI spend
Approved providers
Data retention
```

This belongs to enterprise/future scope.

---

# 40. Network Cost

AI should not consume mobile data unexpectedly.

If cloud AI is enabled, consider:

```text
Wi-Fi only
Wi-Fi + mobile
Ask before upload
```

---

# 41. Offline Queue

Future AI jobs may be queued:

```text
Capture
 ↓
AI requested
 ↓
No Internet
 ↓
Queue locally
 ↓
Network available
 ↓
Process
```

This should be opt-in for privacy-sensitive deployments.

---

# 42. AI Failure Handling

If AI fails:

```text
AI unavailable.
Core WISE functions continue.
```

Do not make the camera unusable.

---

# 43. Provider Failure

If the configured provider is unavailable:

```text
Cloud AI unavailable.
Try again later.
```

Do not silently switch to another provider unless the user explicitly configured an approved fallback.

---

# 44. Provider Abstraction

The provider interface should conceptually support:

```dart
abstract class AIProvider {
  Future<AIResult> analyze(
    AIRequest request,
  );

  Future<bool> isAvailable();

  Future<AIUsage> getUsage();
}
```

The exact implementation belongs in the technical architecture.

---

# 45. Cost Observability

Where cloud AI is used, store aggregate usage metrics such as:

```text
requests
input tokens
output tokens
estimated cost
provider
model
```

Do not store the clinical image as part of analytics.

---

# 46. Privacy-Preserving Cost Tracking

Usage records should identify:

```text
feature
provider
model
tokens
estimated cost
timestamp
```

rather than storing sensitive image content.

---

# 47. Vendor Lock-In Protection

Never design WISE around one provider's proprietary API format.

Use:

```text
WISE AI Request
        ↓
Provider Adapter
        ↓
Vendor API
```

This allows switching providers later.

---

# 48. Recommended Initial Providers

No single provider should be mandatory.

For cloud text/multimodal experiments, current low-cost options include:

- OpenAI GPT-5.4 mini/nano
- Google Gemini Flash-Lite/Flash
- Anthropic Claude Haiku

Their current public pricing illustrates that inexpensive models can be used for selected non-critical workloads. citeturn0search6turn0search1turn0search0

Provider selection should ultimately depend on:

- clinical privacy requirements
- image capability
- latency
- quality
- region availability
- cost
- contractual terms
- retention policy

---

# 49. Self-Hosted Strategy

Self-hosting becomes attractive when:

```text
High volume
+
Privacy requirements
+
Predictable workload
```

make recurring API costs or data transfer undesirable.

Possible architecture:

```text
Mobile
  ↓
Encrypted API
  ↓
Private inference server
  ↓
Open-weight model
```

---

# 50. When NOT to Self-Host

Do not self-host simply because a model is open-source.

Avoid it when:

- usage is tiny
- no GPU exists
- maintenance burden is high
- a local mobile model is sufficient
- cloud cost is negligible
- security operations would become disproportionate

---

# 51. Break-Even Analysis

Before deploying a self-hosted model:

```text
Monthly API cost
vs
GPU/server cost
+
electricity
+
maintenance
+
monitoring
+
security
```

Only self-host when total ownership cost and privacy/control benefits justify it.

---

# 52. On-Device Model Strategy

On-device AI should be considered before self-hosting.

Advantages:

- no server
- no API fee
- offline
- low privacy exposure
- low latency

Limitations:

- model size
- device variation
- battery
- thermal constraints
- mobile GPU/NN accelerator differences

---

# 53. Model Quantization

Where appropriate, use:

- quantized models
- smaller architectures
- mobile-optimized runtimes

to reduce:

- download size
- RAM
- latency
- battery consumption

Accuracy must be benchmarked before adoption.

---

# 54. AI Model Packaging

Models should be:

- versioned
- integrity checked
- securely distributed
- replaceable
- separately documented

A model update must not silently change historical results.

---

# 55. AI Model Rollback

If a new model causes unacceptable behaviour:

```text
New model
 ↓
Problem detected
 ↓
Rollback
 ↓
Previous validated model
```

---

# 56. AI Feature Flags

AI features should be feature-flagged.

Examples:

```text
ai_body_region_detection
ai_landmark_detection
ai_ocr
ai_report_assistance
ai_cloud_analysis
```

This allows controlled rollout.

---

# 57. Experimental AI

Experimental AI should be clearly separated from validated product functions.

Example:

```text
Experimental AI
```

must not appear identical to:

```text
Validated WISE Tool
```

---

# 58. AI Evaluation

Before production release, each AI function should be evaluated on:

- accuracy
- false positives
- false negatives
- latency
- memory
- battery
- privacy
- cost
- device compatibility

---

# 59. Clinical Dataset Governance

Clinical image datasets used to train/evaluate models require explicit governance.

The product must not assume that photographs captured by users can automatically become training data.

Training use requires appropriate authorization, policy, and governance.

---

# 60. No Automatic Model Training

Default:

```text
User photograph
      ↓
Clinical workflow
```

not:

```text
User photograph
      ↓
Automatically added to training dataset
```

---

# 61. AI Data Retention

For cloud AI:

- send the minimum data required
- retain results only as necessary
- avoid unnecessary request logs
- understand provider retention settings
- provide deletion where supported

---

# 62. Prompt Privacy

Prompts should not contain unnecessary:

- names
- identifiers
- addresses
- clinical notes
- metadata

Use structured de-identified inputs when possible.

---

# 63. AI Cost Priority Matrix

| Function | AI? | Preferred Cost Tier |
|---|---:|---|
| Level | No | Device |
| Grid | No | Device |
| Focus | No | CV |
| Lighting | No | CV |
| Alignment | No | CV |
| Measurement | No | Geometry |
| Annotation | No | Device |
| Body-region detection | Optional | On-device ML |
| Landmark detection | Optional | On-device ML |
| OCR | Optional | On-device ML |
| Image description | Optional | Low-cost AI |
| Report assistance | Optional | Low-cost AI |
| Complex multimodal reasoning | Optional | Strong AI |
| Diagnosis | Not V1 | Separate validated product |

---

# 64. Recommended V1 AI Budget

The target should be:

```text
Mandatory per-photo AI API cost = $0
```

because the camera, CV, measurement and comparison stack should operate locally.

Optional cloud AI can be pay-as-you-go.

---

# 65. Recommended V1 Technology Stack

```text
Flutter
   ↓
Native Camera
   ↓
Local Image Pipeline
   ↓
Classical CV
   ↓
Optional On-Device ML
   ↓
AI Abstraction Layer
   ↓
Optional Provider
```

---

# 66. Recommended V1 AI Features

Implement first:

### 1. No-AI intelligent camera

Use:

- sensors
- CV
- geometry
- image statistics

### 2. Optional body-region assistance

Use a lightweight on-device model if testing proves it useful.

### 3. Optional OCR

Use platform/on-device OCR if document workflows need it.

### 4. Optional report assistance

Use a low-cost cloud or self-hosted model only after the local product is stable.

---

# 67. AI Features for Later

Potential V2/V3:

- multimodal clinical documentation assistant
- automatic image organization
- structured report generation
- longitudinal photo summaries
- natural-language search
- protocol recommendation
- advanced image quality coaching

These should be separate modules.

---

# 68. AI Architecture for Future WISE Products

The AI layer should become reusable:

```text
WISE Core AI
   │
   ├── Camera
   ├── Clinical Documentation
   ├── Reports
   ├── Education
   ├── Workflow Automation
   └── Future WISE Apps
```

The same provider abstraction and cost controls can serve future products.

---

# 69. Cost Optimization Rules

1. Prefer local processing.
2. Avoid per-frame cloud inference.
3. Use small models for simple tasks.
4. Escalate only when necessary.
5. Cache reusable context.
6. Batch non-urgent workloads.
7. Minimize image resolution sent remotely.
8. Crop to relevant regions.
9. Set usage budgets.
10. Track actual usage.
11. Keep cloud AI optional.
12. Avoid unnecessary AI features.

---

# 70. Anti-Patterns

Do not build:

```text
Camera
 ↓
Upload every frame
 ↓
AI
 ↓
Return guidance
```

Do not build:

```text
Every image
 ↓
Largest available model
```

Do not build:

```text
AI API unavailable
 ↓
Camera unusable
```

Do not build:

```text
Cloud AI
 ↓
Silent upload
```

Do not build:

```text
AI generated image
 ↓
Replace original
```

---

# 71. Cost Monitoring Dashboard

A future developer/admin dashboard may display:

```text
AI Requests
Input Tokens
Output Tokens
Estimated Cost
Cost/User
Cost/Feature
Provider
Model
Failure Rate
Latency
```

This should contain aggregate usage information rather than clinical images.

---

# 72. Monthly Cost Formula

For a provider:

```text
Monthly AI Cost =
Σ(
input_tokens × input_rate
+
output_tokens × output_rate
+
image/tool charges
)
+
infrastructure
+
storage
+
network
```

Then:

```text
AI Cost / Active User
=
Monthly AI Cost / Active Users
```

---

# 73. Cost Targets

Recommended product targets:

### V1 Core

```text
AI API cost:
$0 mandatory
```

### Optional AI

```text
Pay only when user invokes an AI feature.
```

### High-volume future

```text
Evaluate on-device or self-hosted inference
before accepting large recurring API costs.
```

---

# 74. Security-Cost Tradeoff

The cheapest technical option is not always the best.

Example:

```text
Cloud AI
↓
Cheap per request
```

may still have:

```text
privacy risk
+
network dependency
+
vendor dependency
```

Therefore cost decisions must consider:

```text
Money
+
Privacy
+
Reliability
+
Latency
+
Maintenance
```

---

# 75. Decision Framework

For every proposed AI feature, document:

```text
Feature:
Why AI is needed:
Can CV solve it?
Can on-device ML solve it?
Can self-hosted AI solve it?
Why cloud AI is required:
Expected requests/user:
Expected tokens/image:
Expected cost:
Privacy impact:
Offline behaviour:
Fallback:
```

No AI feature should bypass this evaluation.

---

# 76. AI Readiness Checklist

Before adding an AI feature:

- [ ] Clear user value
- [ ] Non-AI alternative evaluated
- [ ] Local processing evaluated
- [ ] On-device model evaluated
- [ ] Privacy impact assessed
- [ ] Cost estimated
- [ ] Latency measured
- [ ] Offline fallback defined
- [ ] Provider abstraction implemented
- [ ] Model versioning defined
- [ ] Failure handling defined
- [ ] User consent defined

---

# 77. Final Recommendation

For WISE Clinical Camera, the strongest strategy is:

```text
                    WISE CAMERA
                         │
                  CAMERA FIRST
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
       Sensors + CV             Local Storage
             │
             ▼
       Optional On-Device ML
             │
             ▼
       Optional AI Gateway
             │
       ┌─────┴──────┐
       ▼            ▼
 Self-Hosted      Cloud
       │            │
       └─────┬──────┘
             ▼
          AI Result
```

The product should make **zero mandatory cloud AI calls per photograph** the architectural baseline.

---

# 78. Final Cost Philosophy

WISE should not compete by saying:

> “We use the most powerful AI.”

It should compete by saying:

> **“We use AI only where it is useful, and everything else happens faster, privately and locally.”**

That gives WISE:

- lower operating cost
- stronger privacy
- better offline capability
- lower latency
- less vendor lock-in
- easier scaling
- easier deployment in clinics
- better long-term economics

The camera itself should remain inexpensive to operate even as the number of photographs grows dramatically.

---

# 79. Definition of Done

The AI & Cost Strategy is implemented when:

```text
Core camera works without AI              ✓
Core camera works without cloud           ✓
Alignment works locally                   ✓
Measurement works locally                ✓
Comparison works locally                 ✓
AI is optional                            ✓
Cloud AI requires explicit configuration ✓
AI provider is abstracted                 ✓
Models are versioned                      ✓
Usage can be measured                     ✓
Cost can be estimated                     ✓
AI failures do not break camera          ✓
Original images remain local/immutable   ✓
```

The architecture should remain capable of adding better AI later without rebuilding the camera engine.
