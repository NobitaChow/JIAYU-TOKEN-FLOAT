# JIAYU Token Float 0.1.0

![应用标志](Assets/Logo.svg)

macOS 13+ / Apple Silicon 原生悬浮用量窗口。

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
