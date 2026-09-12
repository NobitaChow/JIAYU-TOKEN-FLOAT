# JIAYU Token Float · 用量悬浮窗 0.1.0

<p align="center"><img src="Assets/logo.png" width="160" alt="JIAYU STUDIO 用量悬浮窗"></p>

<p align="center">JIAYU STUDIO · 把每次运行，看得更清楚。</p>

一个为 Codex 本地会话制作的 macOS 原生悬浮用量窗口。可以自由拖动，收起时看关键数值，展开后查看对话、分项目和全部项目的 tokens 与美元／人民币等价估算。

## 下载与安装

- [下载 0.1.0 安装包](https://github.com/NobitaChow/jiayu-token-float/releases/download/v0.1.0/JIAYU.Token.Float.0.1.0.dmg)
- [中文上手手册 PDF](https://github.com/NobitaChow/jiayu-token-float/releases/download/v0.1.0/JIAYU-Token-Float-0.1.0-Manual-zh-CN.pdf)
- [全部发布文件与校验值](https://github.com/NobitaChow/jiayu-token-float/releases/tag/v0.1.0)

适用于 **macOS 13 及以上、Apple Silicon（M 系列）**。

1. 打开 DMG，将应用拖入「应用程序」。
2. 从「应用程序」启动 **JIAYU Token Float 0.1.0**，然后弹出安装磁盘。
3. 更新已有安装时，请先退出正在运行的旧版，再完成替换。

本包采用本地 ad-hoc 签名，尚未获得 Apple 开发者公证。

## 操作

- 按住左侧四点拖动；位置自动保存。
- 单击数值区域展开或收起。
- 展开后在「对话 / 分项目 / 全部项目」之间切换。
- 对话默认跟随最近开始运行的主任务，也可手动锁定。不会跟随当前前台窗口；任务名称显示工作目录和对话 ID。
- 分项目按日志的完整工作目录分组，包含该目录下已记录用量的子任务；全部项目汇总本机可读取的 sessions 和 archived_sessions。
- 设置中可选择两项折叠字段，包括项目、全部项目的 tokens、美元、人民币和费用/分钟；也可修改置顶、参考汇率、模型单价、日志目录。
- 菜单栏图标可重新显示、重置位置或退出。

金额保留两位小数（0.01）。

## 统计口径

- 本轮：最近一次 task_started 之后的输入 + 输出；对话：该对话日志的累计。
- 缓存输入是输入的一部分；推理输出是输出的一部分，均不重复加进总量。
- 已有累计计数时，用差分防止重复日志重复计量。分叉仅剔除与其已读取父会话匹配的历史前缀。
- 速度为最近 60 秒日志记录的输出 tokens / 60，包含推理输出；日志分批到达，无法还原逐 token 的生成速度。
- 美元/分钟是最近 60 秒已记录的 token 等价费用，不是未来费用预测。
- Astra 和 GPT-5.6 Sol/Terra/Luna 采用 2026-09-13 核对的标准 API 价格。fast/priority 按 2 倍估算；长上下文按界面规则估算。其他模型可自定义；未知价格显示「已知金额＋待计价」，不会算成零费用。
- 人民币默认采用手动参考汇率 7.0，非实时汇率，可在设置更改。
- 所有金额均为模型 tokens 的 API 等价估算，不是订阅扣费，不含工具等其他费用。
- 首次扫描可能需要数分钟，读取期间明确标为部分统计。后续使用只保存数值和项目路径的本地缓存加快启动。
- 本地日志缺失、未同步远程任务或缺少用量事件时，无法纳入完整统计。此程序不等于账户全量账单。

## 本地数据与权限

不联网、不读取认证文件或钥匙串，不需要辅助功能、录屏或管理员权限。只读日志。
设置：macOS UserDefaults，域 studio.jiayu.tokenfloat。
可丢弃缓存：~/Library/Caches/studio.jiayu.tokenfloat/accounting-v1.json；不缓存对话正文。

## 构建与测试

运行 ./build.sh。构建会执行计量自测。
源码使用 SwiftUI / AppKit；ccusage 移植部分的 MIT 许可见 ThirdParty。
本地 ad-hoc 签名，无 Apple 开发者公证。

## 价格来源

- https://developers.openai.com/api/docs/models/gpt-6-astra
- https://developers.openai.com/api/docs/models/gpt-5.6-sol
- https://developers.openai.com/api/docs/models/gpt-5.6-terra
- https://developers.openai.com/api/docs/models/gpt-5.6-luna

## 已验证与限制

0.1.0 已通过 19 项计量自测，并检查已安装应用的拖动、展开、三个统计范围、设置持久化和 LOGO。安装包、构建产物及已安装应用的可执行文件一致。

速度是日志的 60 秒滑动统计，无法还原逐 token 流式生成速度。费用是 API 等价估算；本地日志覆盖范围不等于账户全部用量。此次发布材料修订没有修改应用程序。

## 开源来源与许可

自有代码使用 [MIT 许可](LICENSE)。用量归一化与安全差分逻辑从 [ccusage](https://github.com/ccusage/ccusage) 的 Codex 解析器移植到 Swift，并保留其 MIT 许可；完整 CLI 未打包。项目汇总、增量读取、窗口与设置为本项目定制实现。[codex-usage](https://github.com/qianhaoq/codex-usage) 仅作参考，未复用代码。

详细版本和改动说明见 [第三方声明](ThirdParty/NOTICE.md)。LOGO 为本项目原创图形，未打包商业字体文件。中文手册使用嵌入字体，便于在不同设备阅读。

---

免责声明：这个工具是通过 **AI 与人工协作**完成的。它原本只是我根据自己的需求制作的一个个人小工具。我保留这个代码仓库主要是为了方便以后备份和使用，同时也分享给社区，希望它能对其他同样在寻找简单实用工具的人有所帮助。
