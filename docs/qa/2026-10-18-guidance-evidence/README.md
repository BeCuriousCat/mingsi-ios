# 指导提示按单次行为归属 · 2026-10-18

继续审查思考和引导，发现指导提示把未描述的行为当成反例；同一来源虽然只存一份引用，重复处理却会继续增加次数，两个支持来源又会自动标为 mastered 并隐藏提示。模型理由没有原文约束，结果自评也可能越过行为证据。两条修复前回归均失败，见[修复前摘要](evidence/before-summary.json)，`/tmp/mingsi-guidance-before-20261018.xcresult`。

## 实现

`evaluateGuidanceEvidence` 升至 1.1.0 / schema 2，保留 1.0.0 原文回放和回退。请求区分原行动计划、待检验判断、结果原文、用户完成/价值/判断自评，以及保存的结果评估。supports 需要报告相关动作，counterexample 需要明确没做或直接违背提示；缺少描述、记不清、计划、选择、好结果或低自评都不能代替行为。前两类附一至三段唯一连续原文引用，insufficient 空引用，不要求补练习或推断能力/掌握。引用校验只证明字面来源，不能判定语义。

同一 Verification 的重复或相反分类不再重复计数；支持次数不会自动设置 mastered 或清除旧反例。用户已有明确已掌握和暂缓偏好仍由原资格策略处理。新明确非使用报告恢复 practicing 以允许后续提示，并不证明能力退步。旧计数及 mastered 原样保留，因为历史无法区分自动推断与明确选择。

SQLite 的归属更新与偏好更新各自在单个写事务内读取最新状态再修改，避免并发覆盖。Store 合并同一结果的进行中请求，重新创建后按持久来源跳过已记录项；只处理来源匹配、有观察且引文可核对的保存结果，旧 nil、missing/conflicting 均跳过。模型或读写失败停止后续目录调用，不给当前页补本地判断。偏好保存失败保留提示并显示错误。任务由 Store 跟踪，后台和模型配置变化取消，await 后校验取消及配置版本以丢弃迟到网络结果。

## 本地验证

前三次相关执行在编译阶段停止，没有模型调用：[编译错误摘要](evidence/initial-compile-failures.json)。前两次为新增 AppStore 测试参数顺序，第三次暴露 Swift 6 禁止把仍持有的非 Sendable 仓储传入并发任务。修正为共享 GRDB 的 Sendable DatabaseQueue、在各 detached task 内创建仓储，保留并发更新断言，没有添加 unchecked Sendable。

修正后专项 **254 通过、0 失败/跳过**，见[专项摘要](evidence/focused-summary.json)，`/tmp/mingsi-guidance-focused-sendable-20261018.xcresult`。覆盖版本回退、自评上下文、编造/空/重复引用、重复来源、两个写任务、偏好保留、旧结果跳过、重复请求合并、取消和配置变更后的迟到回复、Store 重建去重，以及 SQLite 拒写后停止后续请求。夹具模型只验证来源及编排，不当作实际语义证据。

首次完整单元 **1416 通过、1 失败、10 项 opt-in 跳过**，见[初始完整摘要](evidence/full-unit-initial-summary.json)，`/tmp/mingsi-guidance-full-unit-20261018.xcresult`。唯一失败是暂缓日期在往返后偏差约 1.5 毫秒，超过 1 毫秒断言。改用固定整秒日期，继续断言并发归属不改暂缓日期、计数、引用或用户偏好；没有放宽为只看非空，也没有改生产时间序列化。

最终完整单元 **1417 通过、0 失败、10 项显式 opt-in 跳过**，见[最终完整摘要](evidence/full-unit-final-summary.json)，`/tmp/mingsi-guidance-full-unit-final-20261018.xcresult`。本次完整套件没有外部模型调用。历史指导 Prompt 的 Swift 多行字符串去除缩进后与 HEAD 原文一致。

## 伊莉丝真实调用

只读复核 CC Switch 当前选择仍为伊莉丝、`https://ylscode.com/codex`、Responses、`gpt-6.1-sol` 别名，使用已授权配置执行一次生产服务验收。三次请求、三次完整回应，一条测试通过、0 失败/跳过，无重试；见[执行摘要](evidence/live-summary.json)，`/tmp/mingsi-guidance-live-20261018.xcresult`。这也再次确认该第三方接口的实际兼容性，不证明其上游身份或订阅计费规则。协议形式依据 [OpenAI Docs / Custom model providers](https://developers.openai.com/codex/config-advanced)。

Codex AI 逐条读完完整请求及助手正文，见[附件清单](evidence/live/manifest.json)、[内容复核](evidence/live/semantic-review.json)。三组均为同一“开始前，先写清怎样算完成”提示的合成材料；done/high/confirmed 是干扰，自评与已保存的 unresolved 评估分开传入。

| 材料 | 实际回应与复核 |
| --- | --- |
| 没返工，记不清有没有写标准 | insufficient、空引用；说明结果和自评无法确认过程，不补造做过或没做 |
| 写明标准并核对，仍返工两次 | supports；引用完整实际动作，保留“后来返工不否定行为、也不能证明减少返工”的边界 |
| 明确没写标准，恰好没返工 | counterexample；引用保留完整否定，结果不改变行为分类，不推断因果 |

三条理由均只解释本次报告，未安排补练习、评分或推断掌握。这里只认可这三个样本的行为/结果区分，不建立稳定通过率或提供商优劣结论；测试的 calibrationAssessment 为夹具提供，不是整条结果回顾生成链的真实验收。保存的是完整 Prompt/上下文与生产适配器归一信封中的精确正文，没有原始 SSE。

`git diff --check`、脚本语法检查通过。488 个修改/新增文件及本轮 live 日志未检出当前密钥字面值，临时凭据 xctestrun 为零；未修改 CC Switch 设置。以无夹具参数启动固定模拟器的正常 App 并确认进程仍在，见[启动记录](evidence/normal-launch.json)。启动记录只证明存活，不代表新 UI 或手机验收。配置仍按设备保存，桌面 CC Switch 不会自动同步到手机。

## 边界

本轮没有 UI 修改，未重跑页面或 VoiceOver 验收；后台生命周期为编排测试，未建立真实系统切后台的端到端证明。已经开始的数据库写事务可能在取消后提交，未宣称取消与提交原子化。没有持久恢复队列，insufficient 未落为永久去重记录，进程重启后没有自动补跑。既有 PromptRun 是分类理由/引文的审计路径，未新增独立归属审计表。旧自动 mastered 状态仍可能抑制提示。

行为仍是用户报告和模型判断，不代表独立观测、因果有效、稳定能力或长期帮助。整体思考/引导目标继续进行；旧本地计分路径、最大辅助字号阅读负担、真实日常及手机验收仍未完成。未发布安装包。
