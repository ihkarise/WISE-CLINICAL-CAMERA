# WISE Clinical Camera
## UX/UI Specification v1.0

**Product:** WISE Clinical Camera  
**Brand system:** WiseAiTechs Design MD  
**Platforms:** iOS and Android  
**Primary UX objective:** Make standardized Before/After clinical photography fast, clear, repeatable and configurable.

> This specification applies the WiseAiTechs visual language to the WISE Clinical Camera. The source design system defines WiseAiTechs as practical, AI-first, medical-professional, educational and builder-oriented, with a clean, smart, action-focused, structured and premium interface. fileciteturn0file0L11-L29

---

# 1. Design Foundation

The app should visually follow the supplied WiseAiTechs design system:

- Clean
- Smart
- Action-oriented
- Structured
- Premium
- Educational
- Modern medical professionalism
- AI-first but human-centered

The supplied system specifies rounded geometric design, whitespace-driven layouts, pill-based UI, layered cards, restrained gradients and a modular component system. fileciteturn0file0L52-L70

The brand voice is intelligent, practical, visionary, clear, confident, educational and action-focused. fileciteturn0file0L77-L99

---

# 2. Brand Tokens

## 2.1 Primary colors

### Wise Blue
`#243E8F`

Use for:

- primary actions
- navigation
- important headings
- active system elements
- primary controls

### Wise Red
`#D61F4B`

Use sparingly for:

- emphasis
- alerts
- important interactive points
- selected accent states

These are the supplied WiseAiTechs primary brand colors. fileciteturn0file0L145-L168

## 2.2 Supporting colors

- Deep Navy: `#101828`
- Slate Gray: `#475467`
- Light Gray: `#EAECF0`
- Soft Background: `#F8FAFC`
- AI Glow Blue: `#3B82F6`
- System Cyan: `#06B6D4`
- Success Green: `#16A34A`
- Warning/Error Red: `#DC2626`

The supplied system defines these roles for text, backgrounds, AI indicators, analytics, success and warnings. fileciteturn0file0L172-L239

---

# 3. Typography

Primary font:

**Poppins**

Fallback:

`Poppins, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`

The supplied system specifies Poppins as the primary font and uses strong hierarchy with bold headings and highly readable body text. fileciteturn0file0L246-L283

For the mobile app, adapt the desktop sizes rather than using 60–72px headings everywhere.

Recommended mobile starting scale:

| Element | Size | Weight |
|---|---:|---:|
| Screen title | 24px | 700 |
| Section title | 18px | 700 |
| Body | 16px | 400 |
| Secondary | 14px | 500 |
| Caption | 12px | 600 |
| Camera status | 13–14px | 600 |

---

# 4. Layout Principles

The supplied design system uses:

- Desktop: 12-column grid
- Tablet: 8-column grid
- Mobile: 4-column grid
- Mobile gutter: 16px
- Standard spacing: 4, 8, 16, 24, 32, 48, 64, 96px

For the camera, prioritize the camera preview over decorative UI.

The camera should feel like a professional tool, not a dashboard.

---

# 5. Navigation Architecture

Recommended primary navigation:

```text
WISE
│
├── Camera
│   ├── Before
│   ├── After
│   └── Photo
│
├── Cases
│
├── Photos
│
└── Settings
```

For a minimal first release, the primary navigation can be:

**Camera | Photos | Settings**

Cases can be introduced without changing the camera architecture.

---

# 6. First Launch

The first launch should explain only the essential concept.

### Screen 1

**WISE Clinical Camera**

> Take the same photograph again.

Short explanation:

> Create a Before reference and use WISE to reproduce its position, angle, scale and lighting later.

CTA:

**Get Started**

---

# 7. Permissions

Request permissions contextually rather than all at once.

### Camera

> WISE needs camera access to take clinical photographs.

### Photos

> Allow WISE to save photographs to your device Gallery when you choose.

### Motion/Sensors

Only request where required for alignment or level guidance.

The user should be able to use the core camera whenever technically possible even if an optional permission is denied.

---

# 8. Home / Camera Entry Screen

The central screen should be extremely simple.

```text
WISE Clinical Camera

What would you like to capture?

┌────────────┐ ┌────────────┐ ┌────────────┐
│  BEFORE    │ │   AFTER    │ │   PHOTO    │
│ Reference  │ │  Match it  │ │   Simple   │
└────────────┘ └────────────┘ └────────────┘

             Recent photos
```

The three modes are the primary product actions.

---

# 9. BEFORE Workflow

## Screen

Header:

**Before**

Optional fields:

- Body part
- Left / Right
- Protocol

Primary CTA:

**Open Camera**

Secondary:

**Skip details**

The user should never be forced to fill clinical metadata before taking the photograph.

---

# 10. Before Camera

Primary camera view.

Recommended composition:

```text
┌─────────────────────────────┐
│ ← Before              Tools │
│                             │
│                             │
│       CAMERA PREVIEW        │
│                             │
│                             │
│                             │
│                             │
│        ─────────            │
│                             │
│       ● CAPTURE             │
└─────────────────────────────┘
```

Active tools appear as compact controls.

Inactive tools remain in **Tools**.

---

# 11. Camera Tool Bar

Potential tools:

- Overlay
- Align
- Light
- Focus
- Grid
- Level
- Measure
- Mark

Each tool has a clear state:

**ON**

or

**OFF**

The state must be visually obvious without relying only on color.

---

# 12. Persistent Add-On Model

This is a central UX requirement.

A user activates an add-on once.

Example:

**Measurement = ON**

It remains ON in future sessions until the user changes it.

The user should see:

> **Your camera tools**

in Settings.

---

# 13. Tool States

Each add-on has three conceptual states:

```text
Default
   ↓
Persistent preference

Temporary override
   ↓
Current capture
```

Example:

> Measurement normally ON  
> Turned OFF for this photograph  
> Default remains ON

---

# 14. Temporary Override UX

When a persistent tool is changed during capture:

Show a small optional confirmation:

**Measurement**

`Off for this capture`

or:

`Change default`

Do not interrupt every action with a modal. Use a compact contextual control.

---

# 15. Tools Drawer

The Tools drawer should contain the full feature list.

```text
Camera Tools

● Ghost Overlay          ON
● Alignment             ON
● Lighting Check        ON
● Focus Check           ON
○ Grid                  OFF
○ Level                 OFF
● Measurement           ON
○ Annotation            OFF
○ Difference View       OFF
```

Each tool can open its own settings when selected.

---

# 16. AFTER Workflow

The After workflow starts by selecting the reference.

### Choose Before

Sources:

- WISE photos
- Device Gallery
- Files
- Case
- Recent Before photos

Then:

**Use as Reference**

---

# 17. After Camera

The camera opens with the selected Before image as reference.

Core visual:

```text
LIVE CAMERA
+
REFERENCE GHOST IMAGE
```

The reference is transparent and adjustable.

---

# 18. Ghost Overlay Controls

Overlay controls:

- Opacity
- Lock
- Rotate
- Flip
- Reset

Example:

**Reference 50%**

`10% ━━━━━●━━━━ 100%`

The opacity control should be large enough to use quickly on a phone.

---

# 19. Reference Lock

After positioning:

**🔒 Locked**

The reference becomes fixed.

User can:

**Unlock**

to modify it.

This prevents accidental movement.

---

# 20. Alignment Guidance

When Alignment is ON, show a compact status panel.

Example:

```text
ALIGNMENT

Angle       ✓
Position    ✓
Scale       ✓
Framing     ✓
Rotation    ✓

READY
```

When correction is needed:

```text
Move slightly left
```

or:

```text
Move closer
```

The instruction should be one action at a time where possible.

---

# 21. Alignment Score

Optional advanced information:

**Alignment 94%**

Expandable:

- Angle 96%
- Position 94%
- Scale 91%
- Rotation 99%
- Framing 95%

Normal users should not need to interpret technical numbers.

---

# 22. Capture Readiness

When enabled tools are satisfied:

**✓ READY TO CAPTURE**

Capture remains available even when warnings exist unless the active protocol explicitly requires a threshold.

---

# 23. Warning States

Examples:

### Lighting

**⚠ Lighting differs from Before**

### Focus

**⚠ Possible blur**

### Alignment

**⚠ Move closer**

### Calibration

**Measurement unavailable**

Each warning must explain the next useful action.

---

# 24. Capture Override

Always provide:

**Capture anyway**

unless a future protocol explicitly defines a hard restriction.

Clinical documentation should not be unnecessarily blocked by software.

---

# 25. Review Screen

After capture:

```text
        PHOTO PREVIEW

       [ image ]

✓ Focus
✓ Alignment
⚠ Lighting slightly different

[ Retake ]        [ Use Photo ]
```

The user should be able to inspect before saving.

---

# 26. Save Screen

Primary actions:

**Save to WISE**

**Save to Gallery**

If the user's persistent preference is:

**Ask every time**

show both.

If:

**Always**

the selected destination is automatically applied.

---

# 27. Gallery Permission Failure

If Gallery access is denied:

> Gallery access is currently unavailable.

Actions:

**Continue with WISE**

**Open Settings**

Do not prevent local WISE saving.

---

# 28. Measurement Mode

When Measurement is ON:

A compact measurement toolbar appears.

```text
Measure

Length
Width
Area
Perimeter
Scale
```

---

# 29. Calibration Screen

If no calibration exists:

> **Set a scale before measuring in centimetres.**

Options:

**Use ruler**

**Use calibration marker**

**Manual calibration**

---

# 30. Manual Calibration

Workflow:

1. Draw a line across a known distance.
2. Enter physical length.
3. Select unit.
4. Confirm.

Example:

**Known distance: 5 cm**

**[ Calibrate ]**

The app then indicates:

> Scale calibrated.

---

# 31. Measurement Interface

User selects a measurement tool.

For length:

**Tap first point → Tap second point**

Display:

**2.8 cm**

For area:

**Trace region → Close shape**

Display:

**3.6 cm²**

Measurements can be moved or edited.

---

# 32. Measurement Layer

Measurements should visually resemble technical annotations rather than decorative graphics.

They must be:

- clear
- thin
- readable
- non-destructive
- editable

---

# 33. Annotation Mode

Toolbar:

```text
Mark

Pen
Arrow
Circle
Rectangle
Point
Text
```

Use simple rounded line icons consistent with the WiseAiTechs icon direction. The supplied design system specifies rounded, smart, minimal, geometric and futuristic iconography. fileciteturn0file0L436-L455

---

# 34. Comparison Screen

After an After photograph is available:

```text
Before / After

[ Side by Side ]
[ Slider ]
[ Overlay ]
[ Blink ]
[ Difference ]
```

The selected comparison mode should persist as the user's preferred mode.

---

# 35. Side-by-Side

```text
┌──────────────┬──────────────┐
│    BEFORE    │     AFTER    │
│              │              │
│              │              │
└──────────────┴──────────────┘
```

Maintain matched dimensions and framing wherever possible.

---

# 36. Slider

A central draggable divider.

```text
BEFORE      │      AFTER
            │
            │
            │
```

The divider should be touch-friendly.

---

# 37. Overlay Comparison

Controls:

**Before opacity**

`10% ━━━━━●━━━━ 100%`

This allows visual blending of the two photographs.

---

# 38. Blink Comparison

Automatically alternate between Before and After.

Provide:

**Play / Pause**

and a manual toggle.

Respect reduced-motion accessibility preferences.

---

# 39. Difference View

Display a visual difference.

Add a persistent explanatory label:

> **Visual difference only. This does not provide a medical diagnosis.**

---

# 40. Measurement Comparison

If both images have valid calibration:

```text
BEFORE             AFTER

4.2 cm             2.8 cm

Length change
−33%
```

Do not infer disease improvement automatically.

---

# 41. Footer Builder

Optional export feature.

The user can choose:

- no footer
- measurement footer
- date footer
- protocol footer
- custom text

Example:

```text
WISE CLINICAL PHOTO
Lesion: 2.8 × 1.7 cm
```

---

# 42. Export Screen

Options:

**Export Original**

**Export Annotated**

**Export Measured**

**Export Before + After**

**Export Before + After + Measurements**

**Export Anonymized**

---

# 43. Anonymized Export

Provide a simple switch:

**Anonymize export**

When ON, remove available identifying metadata according to platform capabilities.

The original remains unchanged.

---

# 44. Photo Library

Library views:

### Recent

Chronological photographs.

### Before/After

Pairs and comparison sets.

### Cases

Grouped photographs if cases are enabled.

### Protocol

Photos grouped by capture protocol.

---

# 45. Photo Card

Each card can show:

- thumbnail
- Before/After/Photo badge
- date
- body region if provided
- case reference if provided
- comparison availability

Avoid displaying excessive metadata.

---

# 46. Case Linking

Case information should be optional.

After capture:

**Attach to case**

Options:

- Existing case
- New case
- Skip

This keeps the camera fast.

---

# 47. Settings

Recommended sections:

### Camera Tools

Persistent add-ons.

### Capture

- default camera
- default zoom where supported
- flash preference
- orientation preference

### Measurement

- unit
- calibration behaviour

### Comparison

- default comparison mode

### Saving

- Gallery preference
- WISE storage

### Privacy

- Privacy Mode
- anonymized export defaults
- cloud/AI permissions

### Protocols

- create
- edit
- duplicate
- activate

---

# 48. Persistent Tool Settings Screen

Each tool should have:

**Enable**

**Configure**

For example:

### Alignment

ON

Settings:

- guidance sensitivity
- acceptance threshold
- show score

The defaults should remain simple.

---

# 49. Protocol Builder

User can create:

**Dermatology Standard**

Select tools:

☑ Overlay  
☑ Alignment  
☑ Lighting  
☑ Focus  
☑ Measurement  
☑ Grid  
☐ Annotation

Then:

**Save Protocol**

---

# 50. Protocol Activation

Camera entry:

**Current protocol**

`Dermatology Standard ▾`

The protocol changes the effective settings for that session.

User defaults remain available.

---

# 51. Empty States

## No photographs

> Your clinical photographs will appear here.

CTA:

**Take a Photo**

## No Before reference

> Select a Before photograph to begin an After capture.

CTA:

**Choose Before**

## No calibration

> Add a scale reference before measuring in centimetres.

---

# 52. Loading States

Avoid long blank screens.

Use:

- compact progress indicator
- meaningful status text
- thumbnail preview where available

Example:

> Preparing reference…

> Checking alignment…

> Creating comparison…

---

# 53. Error States

Errors should be human-readable.

Examples:

> Camera access is required to take a photograph.

> This device does not support this camera feature.

> Automatic alignment is unavailable. Ghost Overlay is still available.

> A physical scale is required for centimetre measurements.

---

# 54. Mobile Interaction Requirements

Touch targets should be comfortably tappable.

The camera capture control should be the dominant action.

Avoid tiny controls near screen edges.

Controls should work in:

- portrait
- landscape where supported
- different screen sizes

---

# 55. Accessibility

Support:

- VoiceOver
- TalkBack
- dynamic text where practical
- high contrast
- non-colour-only status
- accessible labels
- reduced-motion preference

A status such as:

**✓ Alignment good**

should communicate both visually and textually.

---

# 56. Motion

The supplied WiseAiTechs system calls for smooth, intelligent, lightweight and fluid motion while avoiding excessive or distracting animation. fileciteturn0file0L463-L492

Use motion for:

- tool activation
- panel transitions
- capture confirmation
- comparison transitions

Do not animate the camera unnecessarily.

---

# 57. Cards and Surfaces

Use rounded cards and layered surfaces consistent with the supplied system.

The design system specifies rounded cards with 24px+ radii, light borders and soft depth. fileciteturn0file0L387-L430

For the camera view itself, minimize cards and let the image dominate.

---

# 58. Dark Camera Interface

The camera should use a predominantly dark interface around the live preview when practical.

Reason:

- reduces visual distraction
- improves image inspection
- makes overlays easier to see
- preserves camera-preview focus

Brand blue and red should be used for active controls and meaningful states rather than filling the entire camera screen.

---

# 59. AI Visual Language

If AI features are enabled, use the WiseAiTechs AI accents:

- AI Glow Blue
- System Cyan

The supplied design system defines these specifically for AI features, active states, data highlights and interactive AI elements. fileciteturn0file0L209-L226

AI must never visually imply that an AI feature is a medical diagnosis unless a separately validated and regulated feature is explicitly designed for that purpose.

---

# 60. UX Rules for AI

AI actions should say what they do.

Good:

**Identify body area**

**Improve framing**

**Check photo quality**

Avoid vague:

**AI Magic**

**Smart AI**

**Analyze**

---

# 61. Main User Journey

```text
OPEN WISE
   ↓
BEFORE / AFTER / PHOTO
   ↓
Select optional protocol
   ↓
Camera
   ↓
Optional tools
   ↓
Capture
   ↓
Review
   ↓
Save
   ↓
Optional comparison
   ↓
Optional measurement / annotation
   ↓
Export
```

---

# 62. Ideal Before → After Journey

```text
BEFORE
  ↓
Capture
  ↓
Save
  ↓
Weeks/months later
  ↓
AFTER
  ↓
Select Before
  ↓
Ghost Overlay
  ↓
Alignment
  ↓
Lighting
  ↓
Focus
  ↓
READY
  ↓
Capture
  ↓
BEFORE / AFTER
  ↓
Measure / Annotate
  ↓
Export
```

---

# 63. UX Priority Order

When the screen becomes crowded, prioritize:

1. Live camera
2. Capture
3. Reference alignment
4. Active warning
5. Active tools
6. Navigation
7. Secondary metadata

Never allow secondary UI to dominate the photograph.

---

# 64. Design System Component Inventory

Reusable components:

- Primary button
- Secondary button
- Pill button
- Toggle
- Tool chip
- Camera control
- Capture button
- Status badge
- Warning banner
- Slider
- Bottom sheet
- Tool drawer
- Photo card
- Before/After card
- Measurement label
- Annotation toolbar
- Protocol selector
- Export sheet
- Confirmation dialog

The supplied design system emphasizes reusable modular components and pill-based healthcare UI. fileciteturn0file0L62-L70

---

# 65. Primary Button Style

Use Wise Blue as the primary action.

The supplied system defines the primary button as Wise Blue with white text, rounded pill geometry and 16px semibold typography. fileciteturn0file0L323-L340

For camera capture, the capture control may use a circular shutter design rather than the standard pill button.

---

# 66. Secondary Button

Use:

- white/light background
- Wise Blue text
- subtle border
- rounded geometry

Use for:

- Retake
- Cancel
- Choose Reference
- Open Settings

The supplied system defines this secondary treatment. fileciteturn0file0L346-L360

---

# 67. AI Button

Where an actual AI action exists, use a restrained Wise Blue → AI Glow Blue gradient treatment.

Do not use the AI treatment for ordinary camera functions.

The supplied design system reserves this treatment for AI-oriented interaction. fileciteturn0file0L366-L380

---

# 68. Icon System

Use:

- rounded line icons
- minimal geometry
- consistent stroke width
- clear medical/technical metaphors

Avoid:

- cartoon icons
- overly detailed illustrations
- heavy gradients
- skeuomorphic camera graphics

This follows the supplied WiseAiTechs icon principles. fileciteturn0file0L438-L455

---

# 69. UX Principle: Progressive Disclosure

The user should see only what they need.

Basic user:

**Before | After | Photo**

Advanced user:

**Overlay | Align | Light | Focus | Grid | Level | Measure | Mark**

Expert user:

**Protocols + calibration + comparison + export configuration**

This allows the same application to serve different workflows without overwhelming the camera screen.

---

# 70. UX Principle: Never Destroy the Original

Every edit is visually presented as a layer or derived export.

The user should never wonder:

> Did WISE change my original photograph?

The answer must always be:

> No.

---

# 71. UX Principle: Explain Warnings, Don't Scold

Avoid:

> ERROR: INVALID ALIGNMENT

Prefer:

> **Move slightly closer to match the Before image.**

Avoid:

> **BAD LIGHTING**

Prefer:

> **Lighting is brighter than the Before image.**

---

# 72. UX Principle: Clinical Reality Wins

The app should guide rather than obstruct.

Default:

**Warning → Explain → Capture anyway**

Only a deliberately configured protocol may introduce a hard requirement.

---

# 73. UX Principle: No AI Dependency

The interface must never imply that AI is required for normal operation.

If AI is unavailable:

> Core camera features continue normally.

---

# 74. UX Principle: Device Independence

The UI should adapt to device capabilities.

If a feature is unavailable:

- hide it when irrelevant, or
- show it as unavailable with a reason

Never present a control that silently does nothing.

---

# 75. Final UX Definition

WISE Clinical Camera should feel like:

> **A professional clinical camera that quietly helps the user take the same photograph again.**

The visual identity should combine:

**medical precision + WiseAiTechs technology + simple human interaction.**

The supplied WiseAiTechs system describes the intended visual direction as a combination of modern SaaS systems, Apple-like simplicity, AI startup aesthetics, medical precision and educational clarity. fileciteturn0file0L627-L643

The final interface should therefore avoid becoming a generic medical dashboard. The **photograph is the hero**, the guidance is secondary, and advanced tools appear only when the user turns them on.
