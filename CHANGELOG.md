# CHANGELOG

Notable changes are documented here using Added, Changed and Fixed categories. Version numbers follow semantic versioning while the project remains in early development.

## [2.0.0] - 2026-09-15

First packaged update since 0.1.0; includes the source-only 0.1.1 and local 0.1.2 changes.

### Added
- Click-outside collapse and persistent pin-to-expand mode.
- Exact token deltas beside abbreviated totals, with three short flashes per new batch.
- Current-conversation, project and all-project tokens-per-minute metrics.
- All-project CNY-per-minute display.
- Resizable width and expanded height with persisted dimensions.
- Animated counters and glass-style surfaces, controls and cards.
- Optional mouse pass-through and reduced-motion/transparency support.

### Changed
- Increasing rates use green; decreasing rates use red and a decrease indicator.
- Missing prices are disclosed in details rather than appended to headline amounts.
- Expanded panels choose an available direction; collapsed coordinates are stored independently.
- Release and project display titles use uppercase branding.

### Fixed
- Added a native, first-click-capable disclosure button with an explicit hit area.
- Prevented rounded-total animation overlays from overlapping exact token deltas.
- Prevented temporary Dock/menu-bar avoidance from overwriting the collapsed anchor.
- Limited keyboard focus to settings interactions.
- Removed the 180-character log-type scan limit that could miss reordered JSON fields.

### Distribution
- Apple Silicon DMG installer, source archive and SHA-256 checksums.
- macOS 13 or later; ad-hoc signed, not notarized. Includes an Applications shortcut and Chinese installation guide.

## [0.1.0] - 2026-09-13

### Added
- Initial native floating monitor with conversation, project and all-project usage.
- Configurable cost estimates, local log scanning, numerical caching and branding.

[2.0.0]: https://github.com/NobitaChow/jiayu-token-float/compare/v0.1.0...v2.0.0
[0.1.0]: https://github.com/NobitaChow/jiayu-token-float/releases/tag/v0.1.0
