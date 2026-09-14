# JIAYU TOKEN FLOAT

<p align="center"><img src="Assets/logo.png" width="160" alt="JIAYU STUDIO · JIAYU TOKEN FLOAT"></p>

<p align="center">A native macOS floating usage monitor · 原生 macOS 用量悬浮窗</p>

**Version 2.0.2 · macOS 13+ · Apple Silicon · MIT**

查看 Codex 本机日志中的对话、分项目和全部项目用量，显示 tokens、美元及人民币等价估算。

## DOWNLOAD & INSTALL / 下载与安装

- [Download 2.0.2 — Apple Silicon DMG](https://github.com/NobitaChow/jiayu-token-float/releases/download/v2.0.2/JIAYU-TOKEN-FLOAT-2.0.2-APPLE-SILICON.dmg)
- [Release notes & SHA-256 checksums](https://github.com/NobitaChow/jiayu-token-float/releases/tag/v2.0.2)
- [Changelog](CHANGELOG.md)

1. 退出正在运行的旧版。
2. 打开 DMG，将 **JIAYU Token Float 2.0.2.app** 拖入「应用程序」。
3. 从「应用程序」打开新版，避免同时运行多个版本。

2.0 提供带拖入引导的 DMG、中文手册、源码、LOGO 和 SHA-256 校验值。本包采用本地 ad-hoc 签名，未获得 Apple 开发者公证。

## 2.0.2 / 修复

金额与速度的变化提示改为占位排列：宽度足够时排在数值后方，较窄时换到下一行，不再覆盖指标标题。

## FEATURES / 功能

- **统计范围**：对话、分项目、全部项目；可自定义折叠时显示的两项指标。
- **精确增量**：如 `3.44B ↑ +1234`，即使缩写总量不变也能看见最近一批新增 tokens。每次增加闪烁三次。
- **变化动画**：数字平滑过渡；每分钟数值上涨为绿色，下降为红色并显示差额。可关闭动画，遵循系统降低动态效果。
- **窗口交互**：独立展开箭头；点击外部自动收起；图钉固定详细展开；自动向上／向下展开，收起恢复原位置。
- **拖动与缩放**：左侧四点移动窗口，右下角手柄调整宽度及展开高度，位置和尺寸自动保存。
- **玻璃风格**：半透明背景、卡片和按钮；降低透明度时使用实色。兼容 macOS 13，并非新版系统专属 Liquid Glass API。
- **输入控制**：普通查看不获取键盘焦点；设置页允许输入。菜单栏可切换鼠标穿透，选择“显示悬浮窗”恢复操作。

## ACCOUNTING / 统计口径

- tokens 总量为输入加输出；缓存输入包含在输入中，推理输出包含在输出中，不重复累加。
- 每分钟 tokens 是最近 60 秒已记录的输入加输出；输出均速为最近 60 秒输出除以 60。日志分批更新，不是逐 token 实时测量。
- 箭头增量表示最近一次观察到的累计变化，不等于每秒速度。首次加载、切换对象和计数重置不显示虚假增长。
- 费用是模型 tokens 的 API 等价估算，不是订阅扣费或账户账单，不含工具费用。金额保留两位小数。
- 只计算已配置价格的模型；缺价模型在详情列出，全部缺价时显示 `—`。
- 人民币使用可修改的手动参考汇率，默认 7.0，不是实时汇率。
- 项目按完整工作目录分组，汇总已记录子任务并剔除匹配的分叉历史前缀。仅覆盖本机可读取的日志。
- 首次扫描可能需要数分钟，期间显示部分统计。后续通过本地数值缓存加快启动。

## PRIVACY / 本地数据

应用不联网，不读取认证文件或钥匙串。外部自动收起只观察鼠标点击，不读取键盘输入、不消费其他应用的事件；收起或固定时移除观察器。

设置域为 `studio.jiayu.tokenfloat`。缓存位于 `~/Library/Caches/studio.jiayu.tokenfloat/accounting-v1.json`，包含用量数值及项目路径，不包含对话正文。

## BUILD & VALIDATION

```sh
./build.sh
```

构建使用 SwiftUI / AppKit，目标为 arm64 macOS 13。47 项检查通过；已验证独立箭头的坐标点击、精确增量布局、固定详情和拖动缩放。安装包及已安装应用的可执行文件一致。验证边界见 [VALIDATION.md](VALIDATION.md)。

## PRICING REFERENCES

内置价格快照核对于 2026-09-13，可在设置覆盖：

- [GPT-6 Astra](https://developers.openai.com/api/docs/models/gpt-6-astra)
- [GPT-5.6 Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol)
- [GPT-5.6 Terra](https://developers.openai.com/api/docs/models/gpt-5.6-terra)
- [GPT-5.6 Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna)

## 开源来源与许可

自有代码使用 [MIT 许可](LICENSE)。用量归一化与安全差分逻辑从 [ccusage](https://github.com/ccusage/ccusage) 的 Codex 解析器移植到 Swift，并保留其 MIT 许可；完整 CLI 未打包。项目汇总、增量读取、窗口与设置为本项目定制实现。[codex-usage](https://github.com/qianhaoq/codex-usage) 仅作参考，未复用代码。

详细版本和改动说明见 [第三方声明](ThirdParty/NOTICE.md)。LOGO 为本项目原创图形，未打包商业字体文件。中文手册使用嵌入字体，便于在不同设备阅读。

---

免责声明：这个工具是通过 **AI 与人工协作**完成的。它原本只是我根据自己的需求制作的一个个人小工具。我保留这个代码仓库主要是为了方便以后备份和使用，同时也分享给社区，希望它能对其他同样在寻找简单实用工具的人有所帮助。
