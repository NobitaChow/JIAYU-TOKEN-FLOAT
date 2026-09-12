# 0.1.0 validation

Validated on Apple Silicon macOS, 2026-09-13.

- 19 accounting checks pass: duplicate cumulative counters, increments, separate turns, unrelated completions, reset counters, cache normalization, reasoning inclusion, standard/priority/long-context prices, partial JSONL records, repeated polling, and inherited-prefix project deduplication.
- Installed application launches and displays live local usage.
- Collapse/expand, conversation/project/all-project tabs, settings, and field selection exercised in the real UI.
- Dragging changed the saved window coordinates by the requested displacement. Position restores on relaunch and is clamped to a visible screen during restoration/expansion.
- A custom collapsed field persisted across relaunch; the default field was restored after testing.
- Historical scanning completed; relaunch restored the numeric cache without a full rescan.
- Logo renders in the application; currency display uses two decimal places.
- Build and installed executable checksums match; ad-hoc code signature verified.
- DMG checksum verified.

## Limits

Rates are rolling 60-second averages based on batched log events, not a token streaming instrument. Project boundaries are full working-directory paths. Totals cover readable local logs only. Unknown model prices are explicitly incomplete. Currency is an API-equivalent estimate and RMB uses a manually configured reference exchange rate. This personal macOS build is not Apple-notarized.
