# 明思 Agent Runtime 决策契约

状态：已确认的产品与架构边界，尚未进入实现范围。  
更新：2026-08-14

## 决策

`CentralLLMDecisionCenter` 是明思所有产品判断的全局唯一入口。分类、推荐、训练诊断、总结、教练追问、项目复盘和生活奇遇的 `offer` / `hold` 都必须经由这个中心，并保留可审计的 `PromptRun`。

Pi 不是 iOS 本地状态机的替代品，也不在当前实现范围。当前 App 继续由本地 coordinator、repository、SQLite 事务、用户同意和通知权限管理运行态；模型只返回受 schema 约束的建议、问题或判断。Pi 仅可在未来作为服务端 `AgentRuntimeAdapter` 的候选实现，通过同一受控协议接入中央判断中心。

```text
iOS UI -> local consent / state machine / repository transaction
       -> CentralLLMDecisionCenter -> LLMClient
                                      -> DirectGLMClient (current)
                                      -> AgentRuntimeAdapter -> Pi (future experiment only)
```

`AgentRuntimeAdapter` 必须保持 `LLMClient` / `StreamingLLMClient` 的语义边界：输入为已组装且最小化的产品上下文，输出为版本化 schema 与 `PromptRun` 可追踪结果。它不得直接访问 iOS 数据库、Keychain、通知服务、HealthKit、位置、联系人、日历或 UI 状态。

## 受控多轮 Agent 协议

多轮只适用于用户已经主动开始的教练、复盘或生活奇遇澄清；它不是后台自主循环，也不能因为模型想继续而自动继续。

1. 本地先提交一个带 purpose、schema version、allowed context fields、maximum turns 和 expiry 的请求。首轮仅携带该 purpose 所需的最小字段，不发送原始系统数据、精确地点、联系人、日历文本或健康样本。
2. 模型每轮只能返回：最终结构化判断，或一个 `context_request`。`context_request` 只能从该请求的 allowlist 取字段，并说明用途；不得请求自由文本日志、精确地址、联系人身份、原始日历、原始 HealthKit 数据、认证材料或其他未授权资料。
3. 本地显示模型请求的情境及用途。任何补充字段都要由用户逐项确认；用户可拒绝、编辑、跳过或结束会话。未确认字段一律不发送，模型必须在缺失字段下返回 `hold`、保守建议或结束。
4. 每个用户发起的会话最多 2 个模型回合：初始判断 1 回合，且最多 1 回合经用户确认的补充情境。达到上限、过期、离开页面、网络失败或用户取消时，本地结束会话，不保留模型的未确认草稿为事实。
5. 最终输出仍只是提议。涉及接受邀请、开始 Quest、保存记录、改变偏好、授予权限、安排通知、写入日历、发送消息、购买、导航或其他现实行动，必须由用户在本地明确确认后才可执行。

模型和未来 runtime 禁止自行执行现实操作、系统通知、持久化写入、权限请求或外部副作用。隐私过滤、用户同意、频率/冷却、安全校验、通知调度、幂等性和所有数据库事务仍只由 iOS 本地层负责。服务端 adapter 仅得到本地已经批准发送的数据，且不得成为用户事实、权限或事务的权威来源。

## 生活奇遇情境契约

生活奇遇必须贴合用户已确认的现实情境，尤其是家、工作地点及其可行动条件。当前场景可为 `home`、`work`、`familiarPlace` 或 `unknown`，但当前持久资料只支持家和工作地点，不存在“熟悉地点”的持久资料或地点专属 grounding。不能因为素材库有“游泳”“远距离场馆”或其他通用活动就凭空建议；当前资料没有设施、预约、预算或熟悉路线字段，模型不得把这些条件当作已确认事实。没有支持时，模型应 `hold` 或提出不依赖未知条件的小型、可跳过体验。

### 自愿采集与本地资料

`SideQuestLifeContextProfile` 是用户自愿提供、可随时编辑或清除的本地资料。地点仅有家和工作地点的本地标签；标签不进入模型。当前 `SideQuestAIService` 把 profile 的受控枚举和简短 constraints 组装进最小 payload，同时把系统数据限制为 snapshot 的粗粒度场景、可用性和健康 token。

| 类别 | 本地可保存的最小字段 | 模型可用字段 | 模型不可用字段 |
| --- | --- | --- | --- |
| 地点 | 家/工作地点的本地标签 | 当前场景 `scene_home` / `scene_work` | 标签原文、地址、坐标、定位历史、路线 |
| 楼层与楼梯 | 家/工作地点各自的可选 `floorLevel` 与 `stairsAvailable` | 仅当前场景匹配时：`practical_place_home` / `practical_place_workplace`，以及有值的 `*_floor`；仅楼梯为 `true` 时的 `*_stairs`。payload 发送数值 `floor_level` 与布尔 `stairs_available` | 建筑名、门牌、楼层区间、未建模的楼梯不适用状态 |
| 过渡时间与出行偏好 | `after_lunch` / `leaving_work` / `arriving_home`、通勤方式、活动半径、运动偏好、禁用类别及简短 constraints | `practical_transition_windows`、`profile_commute_modes`、`profile_activity_radius`、`profile_movement_preferences`、`profile_constraints` | 日历原文、会议标题、精确时间线、同行人、设施/预约/预算事实 |
| 健康与可用性 | 不持久化原始系统数据 | snapshot 的 `availability_*` 与 `health_steps_*` / `health_activity_*` / `health_sleep_*` 粗粒度值 | HealthKit 样本、诊断、原始数值、来源、精确时间、未建模的精力或行动能力状态 |

健康字段永不用于诊断或能力判断。系统可用数据只能先在端侧归约为上述 token；用户未提供、已撤回或不适合时，字段缺失，不得猜测。未来若要加入熟悉地点、设施、预约、预算、路线或额外身体适配字段，必须先作为新的自愿、可编辑、本地最小字段和明确 grounding token 设计；这些不是当前实现。

### Grounding 与拒绝规则

- `offer` 必须逐项引用本次最小情境中的 `available_grounding_refs`，且每一项现实前置条件都有对应的当前可用 ref。
- 当前实现中，`practical_place_home`、`practical_place_home_floor`、`practical_place_home_stairs` 只会在 active scene 为 home 时出现；workplace 以同样规则出现。`*_floor` 只在该地点有数值 `floor_level` 时出现，`*_stairs` 只在 `stairs_available == true` 时出现。旧的未归属 `floor_count` 不可作 grounding。
- `scene_home` / `scene_work`、`availability_*` 和 snapshot 的 `health_steps_*` / `health_activity_*` / `health_sleep_*` 也可描述当前粗粒度情况。熟悉地点只可能是没有地点专属 profile ref 的粗粒度 scene，不能据此推断地点条件。
- 缺少当前地点和楼梯 refs 时不得建议爬楼、上下楼或以楼层为前提的活动。当前没有楼梯不适用、精力、行动能力或其他设施/预算的专属 token，不能把这些未建模条件作为已有依据。
- 涉及游泳、健身房、远距离场馆、交通、花费、预约、他人配合或陌生路线时，当前资料不确认具体设施、预约、预算或路线熟悉性。不得把该活动作为邀请，不能用“附近可能有”或常识补全；只有未来新增相应的用户确认字段与 grounding token 后才可重新评估。
- 当前场景、过渡时间或身体状态不支持时，模型必须 `hold` 或改为不依赖未知条件、可拒绝的体验。邀请不得把用户未确认的家、工作、关系或能力当作事实。

## Pi 服务端实验门槛

Pi 只能在当前 3-7 天真实体验完成并形成明确保留决策后，作为一个有止损条件的服务端 adapter 实验。以下条件必须同时满足：

1. 真实体验表明单轮中央 LLM 在至少 20 次已同意的支线计划中，无法稳定处理需要一次用户澄清的情境，且问题记录能归因于多轮编排，而不是 prompt、schema、grounding 或本地 UX。
2. 实验协议能保持最多 2 回合、逐项用户确认、最小字段 allowlist、`PromptRun` 回链和本地事务权威；Pi 不能要求扩展原始位置、健康、联系人、日历或持久化访问。
3. 在隔离测试中，adapter 对受控 fixture 的 schema 合格率、`hold` 的保守性、拒绝未经 grounding 的场馆/游泳/远距离建议，以及取消/超时后无副作用，均不低于 DirectGLMClient 基线。
4. 有明确的服务端数据保留、删除、访问控制、故障降级和成本上限设计，并经用户再次确认开始该实验。

任何一项未满足时，保留 `DirectGLMClient` 与本地状态机，不接入 Pi。实验失败、超时或 adapter 不可用时，如 `DirectGLMClient` 可用则经中央判断中心回退到单轮调用；否则本地保留当前事实并显示可重试状态。不得启用本地随机或目录 fallback 替代判断。

## 里程碑与验收

| 里程碑 | 范围 | 验收 |
| --- | --- | --- |
| 当前：3-7 天真实体验 | 现有单轮中央 LLM、生活奇遇、情境资料和本地账本；不实现 Pi | 记录接受率、完成率、纠正率、`hold` 比例、地点/楼梯不贴合反馈、场馆/远距离幻觉、通知关闭率和压力反馈 |
| vNext.1 决策 | 基于试用决定保留、调整或移除生活奇遇 | 每项调整可回链到本地试用记录和用户反馈；确认是否存在多轮的真实缺口 |
| 可选 adapter 设计评审 | 仅在 Pi 门槛全部满足后定义服务端 adapter | 协议、隐私、事务、成本、回退和 fixture 验收完整；仍不替换 iOS 状态机 |
| 有限 adapter 实验 | 显式 opt-in、隔离环境、受控 purpose | 最多 2 回合、确认率 100%、零未授权副作用、所有结果可审计且可关闭 |
