# Open-source attribution

The Usage normalization and saturating subtraction routines in Sources/Core.swift are adapted into Swift from ccusage's rust/adapters/codex/src/parser.rs.

- Repository: https://github.com/ccusage/ccusage
- Inspected revision: aaa8992341cbe7ee7a534e662831b2b76c43eda1
- License: MIT (included as ccusage-LICENSE)
- Original copyright: 2025 ryoppippi
- Local modifications: incremental file tailing; counter reset handling; per-turn accounting; native UI; project aggregation and replay-prefix removal.

ccusage was selected because its maintained multi-adapter implementation includes dedicated Codex parsing and replay handling. The full CLI/runtime is not bundled. qianhaoq/codex-usage was reference-only and not reused because its blended cost ratio would discard actual cache and output details.
