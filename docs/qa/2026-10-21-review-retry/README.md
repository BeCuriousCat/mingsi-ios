# 透镜引导的取消、重试与上下文恢复

日期：2026-10-21。承接[透镜目录与布局](../2026-10-21-lens-library/README.md)和[回答复盘选择](../2026-10-21-answer-choice/README.md)。本轮没有增加目录条目或改动提示词模板版本，修正已选方法进入回答后的实际交互。

## 发现与修正

- 问题生成取消后，重试强制要求内置透镜，导致“不选视角”和自定义方法无法继续。去掉这项与可选透镜契约冲突的条件，保留原选择。
- 回答复盘取消或失败后没有保留请求类型，通用重试可能进入 generateQuestions。现在保留 reviewCoachAnswer 的身份，失败显示原因和“重试回答复盘”，不替换既有问题与答案。
- 回答复盘原先未进入共享等待状态，无法显示既有取消入口。现在与前台请求共用忙碌状态，防双击；每次请求有独立活动 token，取消立即释放其活动，迟到响应和旧清理不能结束或覆盖新请求。
- 保存重开后，上轮模型判断未恢复到下一次请求上下文。现在恢复真实上轮判断；编辑只使当前反馈失效，上轮判断仍可作为历史上下文保存。CoachReflectionState 增加可选 previousTurn；旧 JSON 缺字段保持 nil，无数据库迁移。
- 初始判断不存在时，提交会静默返回。现在上轮判断可选，显式标记 previous_assessment_available=false，模型使用当前卡片与回答，不补造历史诊断。成功复盘更新下一轮上下文。
- 重试与取消入口的命中区域至少 44pt，文字完整换行；回答状态的取消文案明确为“取消本次复盘”。沿用 DESIGN.md 的原生组件与间距规则。

## 修改前与初轮验证

新增四项回归在修改前为 **0 通过、4 失败**；[基线摘要](evidence/baseline-summary.json)，原结果 `/tmp/mingsi-review-retry-baseline-20261021.xcresult`。分别复现未恢复上轮判断、回答复盘缺等待/恢复、失败不可正确重试，以及无/自定义透镜取消后不能重试。

首次修正后 **2 通过、2 失败**，见[摘要](evidence/first-fixed-summary.json)。两条成功输出未呈现，是新增夹具缺少真实 PromptRun 和 responseReceived 审计记录，被现有持久化门正确拒绝；夹具已改用 PromptTracingLLMClient 与真实 SQLite 审计，不放宽生产质量门。

完整单元初轮 **1452 通过、0 失败、14 opt-in 跳过**，见[摘要](evidence/unit-initial-summary.json)。此后发现无初始诊断的静默提交问题，补修后需重新完整回归。新测试首次构建错误引用不存在的 userMessage，已改为检查实际 contextPayload.currentInput.rawText。

## 最终验证

最终签名构建通过。补修后的完整单元 **1453 通过、0 失败、14 opt-in 跳过**，见[最终摘要](evidence/unit-final-summary.json)、[五项关键回归](evidence/unit-key-tests.json)、[跳过范围](evidence/unit-skipped-scope.json)，原结果 `/tmp/mingsi-review-retry-unit-final-20261021.xcresult`。涵盖无透镜/自定义取消重试、取消后迟到响应、双击重试、失败后正确恢复、保存重开并编辑后继续，以及缺初始判断也可提交。

首轮 UI 最终写结果时发生 `mkstemp: No space left on device`，新式摘要为 unknown/0 项，不能作为通过证据。保留[原摘要](evidence/ui-first-summary.json)、[原始问题与 runner 片段](evidence/ui-first-diagnostic.json)及 `/tmp/mingsi-review-retry-ui-20261021.xcresult`。原始 action metrics 为 2 项/1 失败，runner 记录新恢复测试失败、保存重开通过。新测试在两种最大字号恢复场景都错误地持续向下滑手指返回页顶，而重试按钮仍在视口下方；严格可点击断言失败，随后系统自动滚动点击后成功恢复。修正测试按按钮当前坐标决定滚动方向，保留可点击、44pt、答案和保存断言，不修改生产布局迁就测试。

为确保结果可写，仅清理本任务 DerivedData 中可再生的中间编译、模块和索引缓存，以及模拟器 tmp 下明确命名 mentor-startup-ui-*.sqlite* 的隔离合成数据库；未动实际 Documents 数据库或 Keychain。可用空间约恢复至 668MiB。新测试和所选保存回归关闭 App 的冗长 OS_ACTIVITY 日志；不关闭断言或截图。仅 UI harness 调整后重新构建，生产源码与最终完整单元一致。确认 UI **2 通过、0 失败、0 跳过**，见[摘要](evidence/ui-confirm-summary.json)，原结果 `/tmp/mingsi-review-retry-ui-confirm-20261021.xcresult`。十张恢复流程截图逐张打开，普通字号的内边距、取消、重试与恢复正文可读；最大字号取消文案完整，重试可操作。审图同时发现最大字号的一张按钮仅部分露出，不能将 isHittable 当作完整可见证明。随后加强测试要求：重试按钮及复盘正文必须完整处于安全顶部与固定底栏之间。合成超时改用实际连接层的 LLMClientError.transport，避免夹具直接抛 URLError 时显示英文底层错误；生产错误映射本来已有中文超时文案。该追加改动仅在 DEBUG 夹具与 UI harness 中，正常业务路径与最后完整单元一致。严格 UI 的后续失败、修正与最终确认见下文。

追加严格验证首轮 **0 通过、1 失败**，见 [ui-visible-summary.json](evidence/ui-visible-summary.json)。完整原结果已逐文件 SHA256 核对后归档到 `/tmp/mingsi-review-retry-ui-visible-20261021.xcresult.tar.gz`；十张命名截图与 manifest 保留，重复导出视频/事件文件移除，原件仍在归档内。整屏滑动跨过可读区，改为按目标坐标短距离拖动，未放宽完整可见断言。

重新构建先因磁盘写满失败，随后两次构建仍未成功；这些尝试不算通过。为避免重复删除编译缓存，改清理 Codex、Chrome、Arc 的可再生 HTTP/代码缓存，不涉及浏览器配置、登录信息、个人 App 数据或 Keychain。空间恢复约 1.3GiB 后签名构建成功。短拖动验证仍为 **0 通过、1 失败**，见 [ui-measured-summary.json](evidence/ui-measured-summary.json)，原结果 `/tmp/mingsi-review-retry-ui-measured-20261021.xcresult` 保留。唯一断言是最大字号正文下缘 613.790pt，相比操作栏 621.667pt 少于要求的 8pt 间距约 0.123pt；实际打开对应截图正文完整可读。最后几次微小拖动低于系统滚动起步阈值，现将拖动最小距离设为 40pt，保持最大 140pt、上下完整可见及 8pt 间距断言；这只是 UI harness 调整。重复导出的非 PNG 附件已移除，截图/manifest 与原结果保留。

最终仅调整 UI harness 后签名构建通过；严格 UI **1 通过、0 失败、0 跳过**，见 [ui-final-summary.json](evidence/ui-final-summary.json)，原结果 `/tmp/mingsi-review-retry-ui-final-20261021.xcresult`。该单项包含普通浅色/最大辅助字号深色 × 取消/失败四个变体；保留重试和复盘结论整块完整可见、距离底栏至少 8pt、按钮至少 44pt、答案不变及保存返回断言。十张命名截图已逐张打开，见 [ui-final-review.json](evidence/ui-final-review.json)。截图证明复盘结论可完整滚入阅读区，不表示“下一步”等全部内容同时可见；其他滚动内容仍有正常视口边缘裁切。前次确认中的保存重开回归保持 1 项通过，本次只重跑此前失败的严格恢复测试，不把不同时点结果合称一次全量 UI。

首次同时读取摘要与导出附件触发 xcresulttool 内部 SQLite 提取竞争；等导出结束后单独读取获得有效摘要，上述通过结论来自后者。正常 App 已无测试参数启动（PID 13576），[首页截图](evidence/normal-app.png)已打开检查；既有模型 Keychain 索引仍存在，未读密钥值、重新导入或发送模型请求。元数据存在不等于本轮已复验模型调用。git diff --check 通过。

## 验证范围

UI 使用独立 SQLite/Keychain 和合成离线 transport，经过生产解析器、审计记录、请求生命周期和页面组件。没有使用个人密钥或发模型网络请求；不把这些回归当作真实模型语义或长期思考能力验证。此前新增四个透镜的实际模型结果和换位理解仍偏证据核对的限制，继续保留在透镜报告。本轮不发布安装包，不宣称全 App、手机或手动 VoiceOver 验收。
