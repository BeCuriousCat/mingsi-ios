# CC Switch 伊莉丝接入与实际验收 · 2026-10-17

用户授权直接复用 CC Switch 的伊莉丝订阅。现已接入 Responses 协议，并将当前选中连接导入固定 iPhone 17 / iOS 26.5 模拟器的明思 Keychain、设为活动连接。GLM 原有配置另存，可切回。手机安装及手机网络尚未验证；本报告不代表整个 App 下载验收完成。

## 连接与实现

只读 CC Switch 数据库中当前启用的 `codex / 伊莉丝`（id=default），没有选用同名旧项，也没有修改 CC Switch。读取 API Key 认证、`https://ylscode.com/codex`、`wire_api=responses` 和模型别名 `gpt-6.1-sol`。此为用户的第三方订阅端点；模型别名不能独立证明上游模型身份，也不代表官方 Codex/ChatGPT 订阅权益。

`DirectGLMClient` 新增 Responses SSE 适配：保留 `/codex` 路径，追加 `/responses`，发送现有完整 Prompt/上下文、`store=false`、`stream=true` 和 `MingSi/1.0` User-Agent。不传 temperature、response_format、reasoning 或工具字段。仅接受 assistant output_text；必须收到完整 response.completed 才作为成功。失败事件、拒绝、工具调用、正文不匹配和提前断流返回错误；推理内容不进入产品正文。输出归一为现有解析器使用的信封，保留实际助手文本。导师仍受单次请求和总时限约束。

设置入口：**设置 → API 配置 → 接口类型 → Responses（Codex 订阅接口等）**。协议、Key、地址、模型写入 iOS Keychain，两种协议独立保存。切换刷新所有生产 AI 服务，本身不发模型请求；保存配置后的既有连接测试会请求一次模型。设置页菜单已修正最大辅助字号截断。

协议依据：[OpenAI Docs / Create a response](https://developers.openai.com/api/reference/resources/responses/methods/create)。第三方端点的实际兼容性以以下调用为证。

## 实际验证

所有设备测试均在固定模拟器 `9F93EE80-68DF-4922-8A73-B0590F5143D4` 执行。以下结果有重叠，不累计为独立覆盖数量。

| 验证 | 结果 | 证据 |
| --- | --- | --- |
| 最终完整 MingSiTests | 1366 通过、0 失败、5 跳过 | [摘要](evidence/full-unit-final-summary.json)，`/tmp/mingsi-responses-full-unit-final-20261017.xcresult` |
| 设置切换 UI，浅色正常字号及深色最大辅助字号 | 1 通过、0 失败、0 跳过 | [摘要](evidence/settings-summary.json)、[截图清单](evidence/settings/manifest.json)，`/tmp/mingsi-responses-settings-ui-final-20261017.xcresult` |
| 伊莉丝导师真实调用 | 9 场景、10 次回应；1 条验收测试通过，无跳过 | [执行摘要](evidence/mentor-summary.json)、[AI 逐项语义复核](evidence/mentor/semantic-review.json)，`/tmp/mingsi-cc-switch-mentor-20261017.xcresult` |
| Today 生成问题与停止边界真实调用 | 2 次回应；1 条验收测试通过，无跳过 | [执行摘要](evidence/today-summary.json)、[AI 语义复核](evidence/today/semantic-review.json)，`/tmp/mingsi-cc-switch-today-20261017.xcresult` |
| 实际连接导入并校验保存字段、HTTPS host | 1 通过，无跳过，零模型调用 | [摘要](evidence/import-summary.json)，`/tmp/mingsi-cc-switch-import-verified-20261017.xcresult` |
| live 验收脚本契约 | 通过 | `bash Tests/Scripts/test_live_glm_acceptance_script.sh` |

完整套件的 5 项跳过均为需显式授权开关的 live/import 测试；导师、Today 和导入另在上述独立执行中启用并通过。套件覆盖 Responses 请求、完整/不完整 SSE、失败/拒绝/工具输出、取消/超时、独立 Keychain 配置以及现有业务回归。未在完整套件内调用外部模型。

导师逐项 AI 审阅包括倾听疲惫、直接讲解、接受纠正、保留不确定性、停止追问、条件建议、找漏洞、回看补材料及真实两轮上下文。样本中的多轮建议会随新证据更新，也明确一次成功不能确定唯一原因。所有请求和回复见 [mentor 附件](evidence/mentor/manifest.json)。这些文件保存生产适配器归一后的信封和准确助手正文，未保存原始线上的 SSE 流。

Today 先围绕一位朋友未完成入口、后来发现断网的合成材料生成一个问题；随后明确回答“不继续回忆、别再问、不要安排验证任务”。复核确认停止后 next_repair_question 及其他提问入口为空，不安排当前任务，readiness 保持 not_ready，既不确定设计失败，也不把断网认定为原因。反馈多字段仍偏长，实际页面认知负担未在本轮验收。原始助手正文及请求见 [Today 附件](evidence/today/manifest.json)。

后续实际链路审查发现：上述认可只适用于助手正文，客户端仍把空提示补为练习并显示训练按钮，因此不能视为停止后的产品交互通过。已修复解析、页面与独立回答持久化，升级复盘 Prompt 至 1.4.0，另行完成真实调用和实际页面验证，见[停止边界修复报告](../2026-10-17-coach-stop-boundary/README.md)。上述 Today 请求附件只保留 Prompt 和 input_summary，没有完整结构化上下文；“请求”并非完整线上请求留档。

## 过程中发现并修正的问题

初始最小连通性请求 HTTP 403，第二次更换 User-Agent 并简化请求字段后 HTTP 200，得到兼容性正文；同时改变多个变量，不能把首条失败归因于单一请求头。

Xcode 会把 `TestingEnvironmentVariables` 的值当路径处理，将 `https://` 改成 `https:/`。三次本地导入因此在 URL 校验处失败，没有因此发出模型请求；最后一次修正为仅在 `EnvironmentVariables` 注入，保存 HTTPS host 验证通过。新 CC Switch 脚本及旧 live 脚本均已修正，旧脚本会清理遗留自定义项，同时保留 Xcode 自己的 testing environment。

导师 live 发生在此修正之前，原始 [metadata](evidence/mentor/mentor-semantic-run-metadata.json) 的 endpoint 如实保留 `https:/`。URLSession 当时实际收到了十次完整响应，但该 metadata 不是格式正确 URL 的保存证明；修正后的 Today 调用和连接导入另行通过，不重写历史证据。

首次完整单元回归为 1364 通过、2 失败、5 跳过（[记录](evidence/full-unit-initial-summary.json)）：一条测试仍断言旧“GLM”专用文案，另一条假定默认 Keychain 没有用户配置。已分别更新为实际通用文案、独立空 Keychain；随后整个套件通过。没有清除用户订阅配置。

## 凭据与复验

密钥未进入聊天、仓库或截图。CC Switch 脚本只读取当前授权连接，注入构建目录旁的临时 0600 xctestrun，执行后删除；不输出密钥，不继承其他模型凭据。App 保存至设备 Keychain。此次导入只针对模拟器，不会自动同步手机。最终以无 fixture 参数启动正常 App，并复核[首页截图](evidence/settings/normal-app-launch.png)。任务文件中未检出所用密钥字面值，构建目录无遗留临时凭据 xctestrun。

复验入口 `scripts/run_cc_switch_acceptance.py`：默认导师；`--today-guidance` 为上述两次 Today 请求；`--import-connection` 只导入不调用模型。只使用固定模拟器，传入已有 `--source-xctestrun` 及新的 `--result-bundle-path`。真实调用的自动执行通过后仍必须逐条审阅输出，不把 schema 通过当作引导质量通过。

当前仅认可上述有限合成样本；不宣称稳定通过率、整体 App 验收或伊莉丝优于 GLM。本次同时变更模型和 Prompt，不能做因果比较。其余额、长期稳定性、其他功能 Prompt、手机实机和个人真实场景仍未验证。

## 2026-10-18 当前配置复核

再次只读 CC Switch 当前选中项（[无密钥字段快照](evidence/current-config-recheck-20261018.json)），仍为伊莉丝、`https://ylscode.com/codex`、Responses、模型别名 `gpt-6.1-sol`，认证字段存在。复用现有导入脚本，把当前配置保存为固定模拟器的活动连接，1 条导入校验通过、0 失败/跳过，见[复核摘要](evidence/import-recheck-20261018-summary.json)，`/tmp/mingsi-cc-switch-recheck-20261018.xcresult`。本次没有重新请求外部模型；真实调用能力的证据仍是上述已留档的导师及 Today 回应。配置不会自动同步到手机，未验证手机网络或第三方订阅的计费规则。

同日后续的指导证据验收又使用当前伊莉丝连接完成三次真实请求、三次完整回应，无重试。全部正文及请求已由 Codex AI 逐项复核，见[指导证据报告](../2026-10-18-guidance-evidence/README.md)。这补充实际接口兼容性，仍不建立手机、长期稳定性、上游身份或计费证明。

## 2026-10-21 当前配置复核

再次只读检查，当前仍为伊莉丝、`https://ylscode.com/codex`、Responses、`gpt-6.1-sol` 模型别名，认证字段存在，见[无密钥快照](evidence/current-config-recheck-20261021.json)。此前连接导入、设置 UI 和真实模型调用结果继续保留；这次只读检查本身没有模型请求或 CC Switch 修改。随后再次导入固定模拟器的 Keychain 并设为活动连接，1 项导入校验通过、0 失败/跳过，见[导入摘要](evidence/import-recheck-20261021-summary.json)，导入不调用模型。正常 App 已恢复并核对首页，见[记录](../2026-10-21-question-purpose/evidence/normal-launch.json)。手机仍须单独配置，第三方订阅计费未验证。

同日追问理由专项另有两次不同的实际请求，均收到完整 Responses 正文，确认当前接口仍兼容。两次均为空问题：已保留未知的场景合理，主动检查推断的场景则未提供有效帮助、效果验收失败。不能把接口完成等同于引导质量通过；完整请求、准确正文及失败见[本轮报告](../2026-10-21-question-purpose/README.md)。
