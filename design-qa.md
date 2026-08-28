# Activity And Tasks Design QA

- Source visual truth:
  - Activity direction: `/var/folders/5l/k0dydykj4zn81l676nyr44yr0000gp/T/codex-clipboard-a39f9ec2-1e29-44bf-a6a2-e48984a901a1.png`
  - Reminders/task-panel comparison: `/var/folders/5l/k0dydykj4zn81l676nyr44yr0000gp/T/codex-clipboard-be3cfd46-c626-4b7e-acfd-7a8a8c9879aa.png`
  - Reminders/editor comparison: `/var/folders/5l/k0dydykj4zn81l676nyr44yr0000gp/T/codex-clipboard-849d9254-de85-4f2e-ae1c-3ad20f0ca29a.png`
- Implementation screenshot: unavailable; no post-change app capture was taken because the user previously requested that Codex not control the running macOS app.
- Source dimensions: 724 × 1982, 1696 × 1470, and 2106 × 628 pixels.
- Implementation dimensions: unavailable.
- Viewports represented by the sources: approximately 362-point activity sidebar, 340-point task sidebar, and 660-point editor content measure in dark appearance.
- Density normalization: the Retina references were inspected at original pixel dimensions and interpreted at approximately 2× density. No implementation density normalization is possible without a post-change capture.
- States: Activity with Working expanded plus Recent and Scheduled groups; task sidebar with one expanded material and incomplete tasks; editor with incomplete task blocks.

## Full-view comparison evidence

Blocked. All three source images were opened at their original dimensions, but there is no post-change implementation capture to combine with them. The macOS Debug build succeeds; build success is not being treated as visual evidence.

## Focused-region comparison evidence

Blocked for the same reason. The required focused regions are the expanded Working activity card, the task sidebar's material header and first three rows, and the editor's first three task blocks.

## Findings

- [Blocked] Post-change visual fidelity cannot be verified.
  - Location: Activity sidebar, Tasks sidebar, and editor task blocks.
  - Evidence: the references are available and the implementation builds, but a rendered implementation image is intentionally absent.
  - Impact: exact font rasterization, wrapping, vertical density, hit-area perception, separator contrast, disclosure alignment, and card radii cannot be judged from source values alone.
  - Fix: capture the current app in dark appearance at the three source states without changing its data path, then compare each implementation crop beside its corresponding source.

## Required fidelity surfaces

- Fonts and typography: the activity hierarchy and both task surfaces now use explicit native system sizes and weights modeled on the references; rendering and wrapping remain unverified.
- Spacing and layout rhythm: working cards, history rows, task headers, disclosure rows, completion controls, and multiline task rhythm were adjusted to the measured source proportions; post-render alignment remains unverified.
- Colors and visual tokens: existing Scint foreground, background, border, and task tint tokens remain authoritative; activity intent accents use native semantic colors matching the reference direction.
- Image quality and asset fidelity: no raster imagery or custom assets appear in these components. Native SF Symbols are used for disclosure and completion controls.
- Copy and content: runtime names and task content remain data-driven. Only fixed interface labels such as Working, Recent, Scheduled, Completed, Clear, Hide, and Show follow the visual references.

## Comparison history

- Baseline evidence: the supplied task comparison screenshots show the pre-change density and alignment mismatch between Reminders and Scint.
- Implementation iteration: Activity was separated into card-based working content and flat recent/scheduled history; task panel and editor task blocks were unified around one completion indicator and one row scale.
- Post-fix comparison: blocked because no implementation capture was authorized.

## Implementation checklist

- Capture Activity at approximately 362 points wide with one expanded working card and populated Recent/Scheduled groups.
- Capture Tasks at approximately 340 points wide with one expanded material and a wrapped task row.
- Capture the editor at its 660-point content measure with incomplete and completed task blocks.
- Compare typography, circle size, text baseline, row wrapping, group gaps, disclosure alignment, separator contrast, card fill, hover/selection states, and completed-state contrast.

final result: blocked
