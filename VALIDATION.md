# VALIDATION — 2.0.1

- Existing 47 checks passed after the layout change.
- A live SwiftUI layout harness exercised normal-width (240 pt), narrow (118 pt) and long-value (180 pt) displays with changing currency rates.
- The increment occupied space after the amount when wide, and wrapped below it when narrow. Neither case overlapped the metric heading.
- Test window was closed after visual inspection.

## Previous 2.0 validation

# VALIDATION — 2.0.0

Validated on Apple Silicon macOS, 2026-09-15.

- 47 checks pass, covering accounting, incremental reads, rolling-minute boundaries, geometry, exact token deltas and automatic-collapse policy.
- Installed native disclosure button opened the panel using a coordinate-based mouse click.
- Live abbreviated totals displayed exact token increments without overlapping labels.
- Pin mode exposed additional details. Resizing changed width from 370 to 450 and stored expanded height 730; test dimensions were restored afterward.
- Earlier 0.1.2 checks confirmed stable saved coordinates through collapse; 2.0.0 additionally separates temporary Dock avoidance from the saved anchor.
- Installed application signature and executable equality checked. Release-image integrity and embedded application are verified by the packaging workflow.
- Test application was closed afterward.

## LIMITS

Automated policy/geometry checks do not replace exhaustive testing on every Dock position, monitor layout or third-party input tool. Direct Codex UI automation was unavailable in the test environment. Event-monitor behavior is based on AppKit mouse-only monitoring and does not intercept input.

Rates use batched local logs and a rolling 60-second window. Costs are API-equivalent estimates, not subscription charges. Missing logs or prices remain incomplete. RMB uses a configurable reference exchange rate. The application is ad-hoc signed and not Apple-notarized; the GitHub macOS packaging workflow verifies the DMG and its embedded application.
