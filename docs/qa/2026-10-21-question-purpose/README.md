# 追问理由与未知的呈现 · 2026-10-21

总体目标仍是改进思考和引导的实际帮助。本轮追问回答页存在两种越界：生产问题卡会从 evidence_gap_type 自动拼出“否则后面的回答容易变成泛泛判断”，并从 lens_move/answer_use 再造答题指令；页面的“看明思为什么这样问”又独立调用本地关键词观察和训练路线，不能证明它们是这次模型提问的理由。模型明确没有问题时，页面还会推断“已有可验证判断”，但空数组也可能意味着用户只想结束、已说不知道或需要直接帮助。

## 改动

- generateQuestions 1.26.0 / schema 6，1.25.0 原文保留。问题应能用材料和已知信息回答，不能要求先做调查、测试、与人谈话，也不能重复索取用户已说没有的证据。回答未知是有效表达；proceed_when 只说明这一个问题答到哪里，不保证原因成立，也不要求行动。解释字段各司其职，使用短句，不藏第二个任务。
- 生产问题卡直接呈现 why_now / why_this_matters、expected_update、proceed_when、calibration_target 和原始来源标题。不给缺口标签补造能力诊断，不把枚举改写成作答作业；问题理由不截断两行。缺失解释字段不补造理由。
- 生产回答页移除另起一套的本地观察/训练路线解释。显式本地预览路径仍保留旧呈现，用于历史和离线演示；本轮不把它称为模型判断。
- 空问题页面只说明本轮没有追加问题，不推断准备度或原因已确定。初始推荐卡与诊断完全相同的理由只显示一次。

## 实际验证

所有模拟器执行串行使用固定 iPhone 17 / iOS 26.5（`9F93EE80-68DF-4922-8A73-B0590F5143D4`）。UI 使用独立数据库与 Keychain，并保留生产 model-led 选择路径；预置材料并非真实模型调用。

| 验证 | 结果 | 证据 |
| --- | --- | --- |
| 早期专项单元 | 776 通过、0 失败/跳过 | [摘要](evidence/focused-summary.json) |
| 最终生产源码的完整单元 | 1438 通过、0 失败、12 opt-in 跳过 | [摘要](evidence/full-unit-summary.json)、[逐项跳过范围](evidence/full-unit-scope.json) |
| 首轮 UI | 3 通过、1 失败 | [摘要](evidence/ui-initial-summary.json)、[审读](evidence/ui-initial/reading-review.json) |
| 修正后的 UI | 4 通过、0 失败/跳过，7 张图逐张审读 | [摘要](evidence/ui-final-summary.json)、[审读](evidence/ui-final/reading-review.json) |
| 实际无追加问题场景 | 一次请求、一次完整回应；旧测试 0 通过、1 失败 | [摘要](evidence/live-summary.json)、[完整请求及准确正文](evidence/live/manifest.json)、[语义复核](evidence/live/semantic-review.json) |
| 实际正向引导场景 | 一次不同请求、一次完整回应；效果测试 0 通过、1 失败 | [摘要](evidence/live-positive-summary.json)、[完整请求及准确正文](evidence/live-positive/manifest.json)、[语义复核](evidence/live-positive/semantic-review.json) |

上述数量有重叠，不累计覆盖。完整单元的 12 项跳过均已逐项核对，是外部模型/导入的显式 opt-in 项。完整单元发生在最后的 live harness/runner 调整之前；生产源码此后未变，调整后的构建另已通过，没有把旧完整单元描述成覆盖新 harness。保留结果包：`/tmp/mingsi-question-purpose-unit-final-20261021.xcresult`、`/tmp/mingsi-question-purpose-ui-final-20261021.xcresult`。

首轮 UI 在 helper 默认参数后追加 Dark/最大字号，启动解析实际取了前面的 Light/普通字号，文字高度断言正确失败。修正为优先传入所需参数后，最终截图确实为深色最大字号，断言通过。七张最终图片已经逐张打开阅读：真实理由与“原因仍未知也足够”的条件可读，来源标题保留且测试另行滚动读取，未显示本地补造诊断，初始重复理由已消除。最大字号仍需要较多滚动，回答页大操作栏仍固定；不能据此认可整页舒适度、VoiceOver 或手机。

## 真实回应暴露的效果缺口

两次均通过当前已授权的 CC Switch 伊莉丝 Responses 连接、模型别名 `gpt-6.1-sol`，使用生产 `generateQuestions 1.26.0`、完整 Prompt/结构化上下文和合成材料，`maxRetryAttempts=0`。附件是生产适配器归一后的信封与准确助手正文，不是原始 SSE。两次均没有执行后续回答复盘；未重发任何请求求更好输出。

第一条材料已经区分“一位朋友未完成”“后来发现断网”和“原因仍未知”，模型返回 `{"questions": []}`。生产服务接受了有效空数组；旧 harness 却强制要求一个问题，因而失败。这是测试假设问题，不能称为模型产品失败。已修改 harness 接受零或一个问题，空结果明确记载停止复盘未执行，没有为了覆盖而编造一轮回答，也没有重跑原请求。

第二条明确说“同事报告晚交两天，所以认定他故意不配合”，并自愿请求检查推断、区分事实与推测。仍返回 `{"questions": []}`。接口兼容得到确认，但当前协议没有给用户任何有用的区分或解释，**正向引导效果验收未通过**，保留要求一个有材料依据问题的断言及原始失败。不能把两条空结果都当作成功。非空问题解释质量仍缺真实回应验证。

完整 Prompt 可见三处待审：把所有 explanation/direct-answer 请求归入空数组可能吞掉主动检查推断的意愿；最后一句把三个正向标准和一个冗余判断放在同一个 “If yes” 前，语义不清；已有回答时仍要求一个 repair question，与零或一个的价值门冲突。这些是可见指令张力，尚不能认定是哪一条导致本次结果。后续应同时检验合理不追问和主动思考时的有效帮助，不能一律强制提问。

## 连接与运行恢复

再次只读确认伊莉丝当前连接，随后导入固定模拟器 Keychain，设为活动 Responses 连接。导入校验 1 通过、0 失败/跳过，零模型调用，见[导入摘要](../2026-10-17-cc-switch-compatibility/evidence/import-recheck-20261021-summary.json)。原 GLM 配置按协议独立保留，未修改 CC Switch。协议依据见 [OpenAI Docs / Responses](https://developers.openai.com/api/reference/responses/overview)，第三方实际兼容以真实响应为证，不推断上游身份、余额或计费规则。

已无夹具参数/自定义子进程环境启动正常 App，核对进程及[稳定后的首页](evidence/normal-app-launch-settled.png)，见[启动记录](evidence/normal-launch.json)。首张截图捕获到启动动画，另行保存稳定后截图，没有把动画白屏当作页面通过。启动恢复不代表全 App 交互验收，手机配置不会从桌面自动同步。

`git diff --check` 与 runner AST 检查通过；779 个修改/新增文件及本轮日志未检出当前连接密钥字面值，临时凭据 xctestrun 为零，见[限定范围检查](evidence/security-check.json)。这不是全部凭据的通用扫描。

## 仍需继续

正向引导的空结果、直接解释如何实际获得帮助，以及空问题页仍导向“设计明日验证”，是本轮新增的明确待办。回答复盘的 not_ready/partially_ready 仍要求用户未显式停下时给出修补问题；本轮未修改这项协议，不能宣称所有未知都已从追问循环中释放。模型服务仍会给部分空反馈字段补本地训练标准，独立初始决策恢复也未保证只执行一次。取消后的无透镜问题重试还错误要求已选透镜，尚未修复。跨仓储一致性、VoiceOver、手机与长期个人效果尚未验证。未发布安装包，整个目标继续进行。
