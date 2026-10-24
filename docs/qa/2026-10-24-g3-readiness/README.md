# G3 正式请求窗口的前置核查

日期：2026-10-24。关联[长期契约 G3](../../mingsi-long-term-goal.md)。**7天/50次窗口尚未开始，本页不是验收通过报告。** 输入区候选ec444881已完成[第九轮CI与AI截图审读](../2026-10-24-response-scroll/ci-ninth/result.json)，未混入传输层改动；正常App真实网络基础场景和下列G3接入工作仍缺。

## 当前源码证据

| 项目 | 观察 | 结论 |
| --- | --- | --- |
| 导师应用层重发 | `DirectGLMClient.complete` 遇到 `mentorExecutionPolicy` 直接走单次 `send`，绕过普通请求重试及格式回退；`MentorRequestExecutor` 校验 `maxHTTPAttempts == 1` | 具备单次应用层派发规则；不能据此证明底层实际 HTTP 交易数 |
| 底层计数 | 新候选已绑定每次attempt delegate并接入独立表/导出，取消后仍归旧请求，删除后不重建；macOS局部测试及真实localhost探针通过，完整iOS/产品集成待验 | 点击/登记/Prompt审计不代替实际HTTP；无原生指标、unknown分类与冲突均保持未知。见[本轮证据](../2026-10-24-http-observation/README.md) |
| 输出预算 | 后续候选对Responses发送`max_output_tokens`；官方Z.AI/BigModel兼容Chat发送`max_tokens`，官方OpenAI Chat发送`max_completion_tokens`，并在attempt观测表记录字段和值；未知兼容网关保留为空 | 字段编码、局部测试与官方文档核对已完成；完整iOS验证需下一轮CI，当前转发服务合同仍未核对，正式窗口不能使用未知字段或把字段缺失当作预算已生效 |
| 用量 | 新候选将Chat完整响应、usage-only事件及Responses终态的数字用量持久化；未知/empty/invalid/conflict分开，44项局部测试和真实localhost通过，完整iOS尚待验 | 见[本次证据](../2026-10-24-service-usage/README.md)；不存原始usage/model，缺失不填0，亦不证明实际账单或上游身份 |
| 等待边界 | 生产流以有效内容更新空闲期限，默认600秒；非流式旧调用保持有限总期限，等待提示不超过10秒 | 与输出预算、底层计数分别验证；不是取消所有等待边界 |

源码入口：[DirectGLMClient.swift](../../../Sources/Services/DirectGLMClient.swift)、[MentorRequestExecutor.swift](../../../Sources/Services/MentorRequestExecutor.swift)、[审计请求定义](../../../Sources/Services/CoreProtocols.swift)。本次核查只读源码，新增模型请求0。

## 下一步实现与验收边界

以下是待做工作，不是已交付能力：

1. 为导师请求增加明确的服务端输出预算，记录实际派发值；按支持的协议组装请求。先核对当前授权服务的兼容性，不能通过删除预算字段并静默重试来换取成功。
2. 分别记录应用层派发次数和系统报告的网络交易数，以固定请求身份关联成功、失败、取消、重定向及迟到的观测。采不到的指标保留未知；不能把“任务1次”重命名为“HTTP1次”。不记录认证头、Key、原始URL查询或私人正文，也不新增外部遥测。
3. 区分传输层首次解析到可读正文、实际界面首次可见正文、完整响应终态。上一轮N01的9985ms是请求终态耗时，不能作为首字时延。
4. 验证预算写入、失败不回退、不重复请求、取消后计数归属、无原生指标时的未知状态，以及保存/重开后观测仍能关联原请求；不为这些工程检查调用付费模型。
5. 当前候选原生界面与真实网络基础场景通过后，再登记同一构建、Prompt、内容、服务配置、输出上限和最多50次实际观测的窗口。保留所有失败，不因不足48次成功而自动补跑。

真实场景N02/N03仍按[原小批登记](../2026-10-23-network-ui/README.md)单独记录，不自动移入正式窗口。拥有者获益、外部试用、盲评与独立复用仍需真人证据。

后续已按实际获取的OpenAI、Z.AI和Apple官方文档补齐[请求预算与观测设计](../../mingsi-network-observation-design.md)：区分不同参数合同、推理消耗、原生逐交易计数、取消后的迟到观测归属及界面首份正文。此为实现设计，尚未接入产品、冻结预算或证明当前订阅转发兼容；不因此开启正式窗口。
