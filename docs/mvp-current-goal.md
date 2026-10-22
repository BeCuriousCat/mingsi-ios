# MingSi Current Goal

## 总 Goal：可信、可复用、可公开使用的日常思考导师（2026-10-23，进行中）

让用户在没有准备时也能获得具体帮助，在下一次生活或工作中独立运用，并让其他人能够安装使用开源明思。本期完成指首个通过真实使用、后续复用与公开安装验证的版本；不是完成某一轮 Prompt 或 UI 修复。

正式口径见[长期 Goal 与验收契约](mingsi-long-term-goal.md)：G1–G10 分别覆盖可信与数据、启动负担、在线可用、当次获益、外部重复价值、独立复用、相对普通聊天的价值、自主性、安装与开源维护。全部达标且产品拥有者确认才能标记总 Goal 完成。

当前 M1 只有部分实现及工程证据，真实试用和长期复用尚未通过，也没有普通用户安装渠道。先补证据台账与未保存内容契约，再做真机交互验证和拥有者约 14 天自然试用；之后由少量真实用户验证，并观察至少 4 周复用。以下历史“本轮完成”均为子里程碑，不代表总 Goal 完成。

## 子里程碑：真实试用观测汇总工具（2026-10-23）

按现有App导出与UsageEvent契约补[本机离线汇总工具](mingsi-trial-summary.md)，保留首次入口的失败/早退/未反馈分母，路径切换、新呈现/复看、请求终态分别统计。重复冲突拒绝、同秒反馈冲突标不确定、混版本不合并耗时；原导出只读、输出0600且拒绝覆盖，不带私人正文或ID。新增16项及全体25项Python脚本测试通过；公开合成CLI样例可复现，没有读取真人数据、调用模型或改变App运行行为。工具不判定获益、负担、独立复用或任何Goal通过。详见[验证与边界](qa/2026-10-23-trial-summary/README.md)。原生复验仍待Mac解锁，总Goal继续。

## 子里程碑：主屏闪念暖启动（2026-10-23）

实际系统主屏菜单发现：App已运行停在设置时，“记录闪念”只返回设置。补UIWindowSceneDelegate暖启动回调，闪念页挂载/重复请求时消费待处理标记，启动测试与生产共用待处理投递函数。最终完整单元1517通过/24显式跳过/0失败，2条UI通过，含真实主屏菜单、草稿精确保留、普通重启不误开，以及离线教材启动/恢复。Release模拟器构建在清理可再生成的缓存后通过，原磁盘不足失败保留。详见[快捷入口专项](qa/2026-10-23-capture-shortcut/README.md)。最终额外原生冷启动复核因Mac锁屏待继续；真机、AppIntents/Siri、任意其他弹窗及真人价值不计通过，总Goal继续。

## 子里程碑：证据基线与闪念草稿恢复（2026-10-23）

已建立[G1–G10与33项T/A场景台账](qa/2026-10-23-goal-baseline/README.md)，准备真实试用、至少4周复用与手机验收表，实际数据未填造。闪念正文/待确认识别文本本机持久化、后台停止录音保留部分识别、正式保存与草稿清理事务已实现。最终同一构建完整单元1517通过/24显式跳过/0失败，模拟器UI两项通过，含实际App进程结束重启、未确认转写恢复、确认只追加一次、保存与明确丢弃不复活、普通及最大字号关闭保护。原夹具误判、测试调度冲突、底栏部分可见误点击的失败均保留。详见[本轮证据](qa/2026-10-23-capture-draft/README.md)。真实手机语音、VoiceOver、网络UI及真实价值仍未验收，总Goal保持进行中。

## 本轮：导师 SSE、正文预览与空闲截止（2026-10-22）

导师回应与整理理解改为 SSE，正文预览通过同一严格审计的 complete 路径接入。共享 600 秒无内容截止替代生产流式的 30／120 秒总预算，持续内容续期、心跳不续期；取消拒绝迟到内容，一次 HTTP 无自动重发。断流保留本页可复制预览，不保存成完整回应，退出或重启不承诺恢复。最终签名构建完整单元 1504 通过／0 失败／23 opt-in 跳过；实际 UI 2 通过，普通浅色增长／完成与最大字号深色断流各一项，四图审读。真实伊莉丝新请求 1 通过：4.126 秒见正文、13.059 秒完成，审计及同 SQLite 保存重开均验证，正文已 AI 审读；一次短样例不证明长时稳定。原 UI 夹具失败已保留。详见[流式证据与边界](qa/2026-10-22-mentor-streaming/README.md)。未引入 Agent 框架，未发布安装包。


## 已完成：产品最大问题审视与本轮引导改进（2026-10-21）

当前主问题是训练规则可能覆盖当下需要。复核整个思考链的既有修复与当前资产后，再清除 mentorRespond 2.16.0 中疲惫一律禁问、正文一律禁问号的冲突；2.17.0/schema 1 保留完整回退，允许用户主动需要的一个标准问题与引号内第三方表达示范，仍保留问题预算、停止和来源边界。输入参考明确可选，Deep 表达为更仔细审视而非增加问题。

同一最终签名构建完整单元 **1497 通过 / 0 失败 / 22 opt-in 跳过**；一次新场景的两轮真实伊莉丝请求及同 SQLite 会话保存重开 **1 项通过**，两条实际正文逐条 AI 审读，恢复零请求；输入页独立 UI **1 项通过**，两图审读。正常 App、签名及当前 Prompt 选择已核对，未发布安装包。[审视结论与仍存问题](qa/2026-10-21-request-boundaries/product-assessment.md)、[验证证据](qa/2026-10-21-request-boundaries/README.md)。这完成了本次“审视最大问题并改进思考引导”的工程与有限真实场景验收，不表示全 App 无缺陷、所有外部模型稳定或长期能力效果已被证明。


## 本轮完成：透镜、提示词与相关页面验证（2026-10-21）

十种透镜与能力边界已实现，四种新增为机会成本、可逆决策、换位理解、可控边界；设计理由、合并候选及真实入口见[设计记录](lens-library-design.md)。长材料选择补修 mentorRespond 2.16.0/schema 1，当前输入不可被旧片段替代，老师正文/问题分别选择，省略材料不能被重建为用户事实。长原话独立全文阅读，相关卡片统一留白、换行及大字号布局；实际 34pt 按钮目标已改为至少 44pt。

本轮完整单元 **1495 通过 / 0 失败 / 21 opt-in 跳过**，早于最后 UI 专属修改，后者另有签名构建。十种目录、说明与原选择页三项 UI 先前通过，最终全文/当前诉求新场景 **1 通过 / 0 失败**，覆盖普通浅色和最大辅助字号深色，八张截图审读完成。真实伊莉丝显式老师片段场景一次请求 **1 通过**，无重试；SQLite 选择持久化另由本地测试验证。正常模拟器 App 已恢复。[全部证据、原失败与范围](qa/2026-10-21-context-selection/README.md)。尚无真机、全 App 视觉或长期能力提升验收，未发布安装包；整体产品目标仍在推进。


## 进行中：感受、帮助请求与训练形式（2026-10-21）

mentorRespond 2.15.0/schema 1 保留完整 2.14.0 回退，修正疲惫自动进入不分析、每轮强制思考动作及不替用户决定与请求建议之间的冲突。感受与当前请求分别处理：要建议则按用户标准给帮助，只想倾诉则不附加分析和作业，之后请求比较仍可继续。system 与最终检查同步，不新增情绪关键词路由或模型字段。编译空间、旧断言和签名恢复失败均保留；最终同一签名二进制完整单元 **1487 通过、0 失败、20 opt-in 跳过**。新的三轮伊莉丝同会话保存/重开验收 **1 通过、0 失败**：实际建议 → 仅倾听 → 按新条件重新比较，三次不同输入分别约 2.788/5.068/18.687 秒，正文逐条 AI 审读，无问题或作业，恢复零请求。正常 App 已恢复且首页审图。本轮不是网络 UI、真机或长期能力提升证明；原 2.14.0 不同请求的传输失败仍保留。[本轮报告](qa/2026-10-21-mentor-request/README.md)与[产品问题审视](qa/2026-10-21-mentor-request/product-assessment.md)。整体目标继续进行，未发布安装包。


## 进行中：原因未知、选择依据与继续意愿（2026-10-21）

mentorRespond 2.14.0/schema 1 保留完整 2.13.0 回退，修正“不知道就停止追问”与当前诉求冲突：不知道原因仍可请求解释，已有目标、权限和经历可支持有限选择，不必先证明他人动机；明确停止仍停止。新线索只更新确信，不自动证明恶意。最终签名二进制完整单元 **1486 通过、0 失败、19 opt-in 跳过**。实际伊莉丝三轮验收首轮约 113.966 秒传输失败，无 assistant 正文，在线 **0 通过、1 失败**；后两轮未发送，不重试，不能声称本次语义效果已验证。验收附件补充安全错误类型/domain/code，未重发失败请求。正常签名 App 已恢复、首页截图已审读。[完整证据与限制](qa/2026-10-21-mentor-uncertainty/README.md)。整体目标继续进行，尚无真机或长期能力提升证明，未发布安装包。


## 进行中：初始诊断去重与流式直接讲解（2026-10-21）

修复已有讲解/问题重开仍发初始诊断，以及继续回答、修改同 id 原文或退出后旧请求覆盖当前反馈/错误的问题。初始建议只属于未完成的视角选择；任务随选择、继续、切换、退出、重置及模型配置刷新失效，成功/错误还核对当前阶段、模式、日记录、事项和完整卡片。用户主动选定的透镜不会再被迟到推荐改回。四个反例修改前确实失败（正例 1 通过），最终签名构建与完整单元 **1475 通过、0 失败、17 opt-in 跳过**。一条新的可逆决策直接讲解经生产流式 TodayAIService/DirectGLMClient 和实际 AppStore 提交、保存、新 store 打开同一 SQLite 文件完成，在线 **1 通过、0 失败、0 跳过**；真实正文已 AI 审读，讲清学费可退与时间不可逆，无问题或任务。实际流式一次、complete 零次、HTTP 一次，恢复在该 harness 中零请求。测试直接进入已确认卡片步骤，不接初始推荐/辅助提示，不是全流程网络 UI 或所有生产辅助请求零调用证明；旧机会成本超时仍保留。正常 App 已恢复且首页审图。[完整证据与边界](qa/2026-10-21-initial-decision-lifecycle/README.md)。整体目标继续进行，无长期能力提升证明，未发布安装包。


## 进行中：首页导师的选择标准与等待策略（2026-10-21）

`mentorRespond` 2.13.0 / schema 1 保留 2.12.0 冻结回退，区分事件、解释与价值标准；标准足够时直接建议，未知时只比较一个条件式取舍，不擅自排列收入、效率或关系，不强制补问或作业。Responses 导师总预算改为 120 秒，普通 API 保留 30 秒，十秒提示等待；页面、执行器和验收 HTTP 配置同步，策略按发送时捕获，正常回应及整理理解共用，取消与迟到拒绝、一尝试无回退不变。PRD、系统设计、验收合同及待试用版本记录已同步。最终签名构建与完整单元 **1469 通过、0 失败、17 opt-in 跳过**。新的显式网络复验 **1 通过、0 失败、0 跳过**，包含两条不同输入、同一真实 SQLite session 保存重开、两次真实伊莉丝回应；逐条 AI 审读确认首轮不代排序、续轮按用户新标准明确建议。两次约 8.03/19.95 秒，均短于旧截止，不能把成功归因于延长预算；原 30 秒在线 0/1 失败仍保留，无底层错误码，不断言原因。普通 App 已恢复且首页截图已审读，正常数据库无生效 Prompt 回退或启用 Pack。[完整范围与失败](qa/2026-10-21-mentor-criteria/README.md)。这不是网络 UI、长期效果或全 App 完成证明；整体目标继续进行，未发布安装包。


## 进行中：初始讲解可读、可保存与来源边界（2026-10-21）

发现“请直接解释”只返回空问题、页面丢失帮助内容。generateQuestions 1.29.0 / schema 7 新增可选 explanation，冻结 1.28.0 回退；返回、解析、当前确认来源校验、展示、指纹和真实 SQLite 保存恢复均已接通。可直接保存返回，切换事项/重置问题清空，返回选择步骤不重复请求。完整单元 1462 通过/0 失败/16 opt-in 跳过；最终普通浅色及最大辅助字号深色 UI 1 通过，四图逐张审读，长正文按滚动开头与结尾验收。早期标识冲突、错误同屏断言和磁盘耗尽结果均保留，最终签名构建与正常 App 恢复已完成。新版机会成本直接讲解只请求一次，30 秒非流式探针超时无正文，在线 0 通过/1 失败，未自动重试；不能声称真实模型讲解有效或供应商不兼容。[完整报告](qa/2026-10-21-direct-explanation/README.md)。总体目标继续进行，真实讲解效果、同事项持久化网络多轮、真机和长期能力变化仍待验证。


## 进行中：让透镜训练不同的思考动作（2026-10-21）

进一步发现通用 Prompt 与本地词汇门把多种视角都压成“补证据”。builtin.v3 将换位理解改为准确表述双方已知诉求/限制并比较侧重点；generateQuestions 1.28.0 / schema 6 允许取舍、价值及已知侧重点作为有用材料，无事实缺口时标 none；回退保留 1.27.0。diagnoseTrainingCase 1.3.0 / schema 2 读取新目录，1.2.0 的完整 v2 目录冻结，不随当前资产漂移。结构化门保留来源、具体判断与用途校验，不再强迫无缺口重看前提出现缺口关键词。修改前 0/2，首轮完整单元 1454 通过/2 失败（遗漏已有反证说明合同），补修后 1456 通过/0 失败/15 opt-in 跳过。新说明页 UI 1 通过，含普通浅色/最大字号深色，四图逐张审读。当前伊莉丝连接两次不同轮次请求均完整返回，在线 1 通过；首问比较双方明说的侧重点，显式停止后空问题。实测首轮与续轮 draft UUID 不同，虽确认卡片/真实首问/回答完整转入，不能算同一持久化事项多轮验收；harness 后已复用同一 draft 并重新签名构建，未重复付费。[完整证据与限制](qa/2026-10-21-lens-distinction/README.md)。正常 App 已恢复；未改导师首页交流 Prompt，未重发旧讲解超时。总体目标继续进行，持久化多轮和直接讲解效果仍待验证，不将一个合成例子当作长期能力提升。

## 进行中：透镜流程的取消、重试与上下文恢复（2026-10-21）

补修无透镜/自定义透镜取消后不能重试、回答复盘取消/失败误入问题生成、等待态缺取消、保存重开后丢失上轮判断，以及无初始判断静默不提交。请求活动按独立 token 清理，迟到响应不覆盖新请求；保留答案、明确“重试回答复盘”，取消/重试目标至少 44pt。previousTurn 为兼容旧 JSON 的可选字段，无数据库迁移。修改前 0/4，逻辑最终完整单元 1453 通过/0 失败/14 opt-in 跳过；之后仅 DEBUG 超时夹具和 UI harness 调整，签名构建通过。严格恢复 UI 最终 1 通过，含普通浅色/最大字号深色的取消和失败四变体，重试及复盘结论整块完整滚入阅读区，答案保留并保存返回；另一个保存重开回归在前次确认通过。十张最终截图逐张打开，早期阅读失败与磁盘/测试滚动问题全部保留。[报告与证据](qa/2026-10-21-review-retry/README.md)。正常 App 已恢复，模型 Keychain 索引仍在；本轮无模型网络请求、真机或长期效果验收，不发布安装包。总体思考引导目标继续进行，换位理解仍偏证据核对和直接讲解实际超时的语义缺口未扩大为通过。

## 进行中：回答复盘选择与输入留白（2026-10-21）

reviewCoachAnswer 1.5.0 / schema 1 保留真实 1.4.0 回放，将证据准备度、追问价值、行动同意分开；未就绪可以无追问，不再补造空训练要求。复盘后可直接保存返回，有追问时也有保存出口，验证行动需另行选择；保留未知和真实事项状态，防重复保存。共用输入文字增内边距，Today 去掉重复输入边框；真实 UI 发现的 15.67pt 次要按钮已修成至少 44pt。修改前两项 0/2，逻辑最终完整单元 1448 通过/0 失败/14 opt-in 跳过；后续纯界面修正重新签名构建，相关 UI 5 通过/0 失败，八张最终图逐张审读。三次独立伊莉丝请求返回两条有效回应，解释场景超时，原在线 0/1 失败保留且未重发；不能宣称讲解效果或长期能力提升已验收。普通 App 与现有连接已恢复，未发布安装包。[报告与完整证据](qa/2026-10-21-answer-choice/README.md)。总体目标继续进行。


## 进行中：透镜扩充、能力提示词与布局（2026-10-21）

Today 透镜由六种增至十种：新增机会成本、可逆决策、换位理解、可控边界；保留旧 id 与存储，修复历史版本解码漂移。每种方法明确能力动作、适用条件、停用边界与自愿行动规则；generateQuestions 1.27.0 / schema 6、diagnoseTrainingCase 1.2.0 / schema 2 读取完整目录。选择页三组单列、独立说明入口、完整换行；推荐卡内边距、标签与最大字号操作重排，首页入口留白修正。正确夹具首轮 UI 发现实际重叠、模态字号与对比问题，已集中修正并实际审图。逻辑最终完整单元 1443 通过/0 失败/13 opt-in 跳过；此后 UI 专属修正重新构建，针对性 UI 2 通过，最后文字色单项 UI 1 通过。11 张透镜图与最后两张推荐图分别审读，其他相关 UI 五项此前通过。四次伊莉丝单轮合成请求完整返回，原在线测试因可控边界本地词汇门误拦而失败，原失败保留；修正后四段正文原样离线回放通过，未重复付费。换位理解实际回复仍偏证据核对，不宣称已证明能力提升。详细取舍见[设计记录](lens-library-design.md)，证据与范围见[验收报告](qa/2026-10-21-lens-library/README.md)。正常 App 与既有伊莉丝连接已恢复，签名后 Keychain 导入 1 通过且不发模型请求。总体目标继续进行；未发布安装包。


## 进行中：追问理由与有效帮助（2026-10-21）

generateQuestions 1.26.0 / schema 6 改为可用现有材料作答、允许原因未知；生产页直接显示真实解释，不再从枚举或本地关键词补造诊断，缺失理由留空，空问题不推断原因已成立，初始重复理由已消除。最终生产源码完整单元 1438 通过/0 失败/12 opt-in 跳过，修正参数优先级后的 UI 4 通过、7 图逐张审读；完整单元早于最后的测试 harness 调整，后者另已构建通过。两次伊莉丝实际请求均完整返回空问题：第一条用户已保留未知，旧测试强制提问是 harness 问题；第二条主动请求检查“晚交=故意不配合”仍无帮助，正向效果验收确实失败，未重发求绿灯。下一步优先澄清直接帮助/主动思考的边界及回答复盘强制追问；取消后无透镜重试仍待修。当前订阅连接已重新导入模拟器并恢复正常 App；[报告](qa/2026-10-21-question-purpose/README.md)保留全部失败、实际正文、范围和限制。总体目标继续进行，未发布安装包。

## 进行中：初始思考建议的材料边界（2026-10-21）

初始模型 diagnoseTrainingCase 1.1.0 / schema 2 明确给出至多一个材料缺口和已确认卡片来源，不再由阶段补造缺观察/基线；生产选择页隐藏本地关键词观察/训练路线与未校准百分比。补修“跳过”及“不选视角继续”仍保留透镜、旧 LensSession 覆盖当前空选择的问题，保留已有答案。修改前 0/3、修正后 3/3 回归；最终完整单元 1437 通过/0 失败/12 opt-in 跳过，补齐真实推荐卡夹具的 UI 3 通过，四次伊莉丝实际回应已逐项 AI 审读。正常 App 已恢复。推荐理由仍重复、最大字号滚动较长，首次签名和磁盘失败均保留；[报告](qa/2026-10-21-initial-coach-evidence/README.md)记录证据及限制。总体目标继续进行，未发布安装包。


## 进行中：允许不安排行动（2026-10-21）

发现 generateQuests 允许 `main_quest: null`，客户端却报空结果。修改前两条回归实际失败；现已接通明确空行动、可保存/返回的页面与事项会话恢复，不生成新原则、提醒或成长贡献。补充真实 SQLite 完成写入失败、重复提交、重试不重发模型、旧 active/completed 行动在保存/恢复/后退后保留，专项 146 通过。一次联合回归因磁盘不足未能写完结果，不认可其退出码；分开复验的完整单元 1431 通过/0 失败/11 opt-in 跳过，最终两条 UI 2 通过/0 失败，覆盖浅色正常字号及深色最大辅助字号的阅读、保存和返回。证据与限制见 [无行动回顾](qa/2026-10-20-no-action/README.md)。总体目标保持进行中。

## 进行中：行动建议清晰度（2026-10-18）

本轮减少建议重复和强制作业感，同时保留具体目标、观察信号、来源和用户边界。1.12.0 独立 Prompt 与本地未知结果文案已修改；真实回应发现旧关键词门误拦自然重试，已用准确回应回放修复。三个真实回应已审读，最终完整单元 1427 通过/0 失败/11 opt-in 跳过。严格 UI 已验证浅色普通字号、深色最大辅助字号的分段完整阅读与保存，辅助字号操作栏改为随内容滚动；撤回此前仅靠部分可见判定的阅读结论。记录见 [行动清晰度报告](qa/2026-10-18-action-clarity/README.md)。无行动接纳后续已修复并完成局部验证，见上节。总体目标仍未完成：其他本地诊断路径、写入一致性、来源和实际个人使用仍需审视。


Date: 2026-08-20

## Current Product Stage

MingSi is implementing and validating the vNext multi-matter coaching loop:

```text
记录一天中的多件事项
-> AI 建议拆分，用户确认
-> 任意时刻只训练一件
-> 形成可验证行动
-> 按真实证据更新判断
-> 项目结束时完成最小复盘
-> 长期沉淀可回链的成长证据和原则
```

The user-facing term is `事项`; the internal aggregate is `TrainingCase`. The existing three-stage training hierarchy remains visible, while the internal `DailyLoopState` and `TrainingCaseSession` remain implementation details.

## Single Simulator Execution Standard

- Daily use and manual debugging use only the existing iPhone 17 Simulator with UDID `9F93EE80-68DF-4922-8A73-B0590F5143D4`.
- Do not switch simulator models or start any other device. iPad and other device records may remain installed, but they must not be booted or used for verification.
- Use the fixed simulator destination by UDID when launching or testing; do not substitute a name-only destination.
- Preflight on 2026-08-20 confirmed the app is installed and launchable on the fixed iPhone 17 simulator; no new crash was observed in the current launch. This is a launch check only, not real-use evidence.
- Full `MingSiUITests` regression ran serially on the fixed iPhone 17 simulator on 2026-08-20: 55 passed, 0 failed. The run used about 1 GB of temporary build/test capacity; retain several GB of headroom before repeating it.

## Current Milestone

The active milestone is **MingSi vNext: Closed-Loop Reliability and Usability Acceptance**.

### Daily Return Loop 子里程碑：闪念

“闪念快速捕获 + 按日聚合”是 Daily Return Loop 的子里程碑，不取代 vNext 事项、证据、验证与成长闭环。用户可保存原始文字，主动将同日两条以上素材聚合后带入 Today 原始输入；不会自动创建事项、训练或通知。Action Button 仅支持用户自行绑定“记录到明思”App Shortcut；相机控制键不在范围。

### 明思一下：即时结束与条件验证

“明思一下”是独立、用户主动发起的一问一答。Today 页只保留一个紧凑常驻入口（无会话时引导开始，未完成时显示继续），完整交互在独立 sheet 中进行，不挤占事项训练或中央模型入口。当场点拨帮助用户看见一个思维缺口，不代替用户做决定，也不自动变成待办、事项、验证、原则或成长指标。用户可在任意一轮到这里；完成后回执保留、操作区收敛为唯一的“再明思一件”，后者是新的独立记录。

每轮问题或复盘请求前，当前轮（含回答）会先同步落盘；保存失败时保留输入并提示重试，不发起模型调用。换角度/继续想一层会先把已完成父轮落盘，再创建子轮，父轮的问题、回答和两个 PromptRun ID 不被覆盖；子轮的“回答前”承接父轮的回答。

只有当用户明确选择“带入行动验证”，且材料已有可被未来事实检验的判断、预测或行动时，才把原文带进现有可编辑 Today capture。之后是否整理成验证行动仍由用户确认。

Target delivery gates (implementation status is tracked below; this list is not a claim that they have passed):

- v33-v39 migrations, SQLite online-backup versioned pre-migration backup, legacy fallback, export, and legacy backfill are verified.
- Today can confirm multiple matters, keep one active matter, persist before switching, and prevent evidence/context crossover.
- Due verification is non-blocking and can be completed or deferred without creating false evidence.
- Verification and `GrowthSettlement` commit together; settlement shows evidence, never a per-session score change.
- History, Projects, and Growth resolve evidence back to the correct matter and source.
- Project closure requires reason and actual outcome; archive and review commit atomically, restoration preserves the closure review and prior status, and AI principle candidates require explicit evidence-backed confirmation.
- Meaningful recommendations and evidence classifications go through the shared `CentralLLMDecisionCenter`; local code only supplies bounded candidates and enforces consent, safety, cooldown, mastery, and durable state.
- The model also diagnoses each confirmed matter's phase, training dimension, and recommended lens before the question loop; vNext production waits for that decision and never presents a local interpretation. Missing-key/offline mode remains retryable; only injected test/preview paths may show an explicitly labeled fallback.
- Guidance copy comes from the versioned catalog, while the model decides whether to show one eligible hint and whether verification evidence supports or contradicts it.
- A user-triggered weekly review remains evidence-gated at three recent verifications across two calendar days; the model may select existing guidance IDs and evidence refs, but cannot write scores or new UI copy.
- Simulator build, focused vNext tests, full unit/UI regression, migration rehearsal, and real-device launch pass.

## Acceptance Status (2026-08-20)

- [x] Source-level fixes for the project-closure reason label, History repair filtering, and same-source Growth contribution de-duplication.
- [x] v37 CoachPromptTurn schema, AppStore lifecycle, exact presented-output attribution, quality-gate outcomes, and local feedback categories are complete.
- [x] v38 persists one immutable weekly Guidance review per natural week. Repeated actions and App restarts reuse it without another model request.
- [x] v39-v40 persist side-quest preferences, one open invitation at a time, LLM offer/hold decisions with PromptRun audit, and one immutable positive life-experience event with continuity after an accepted quest is completed. Invitations are visible by default but remain optional; notifications require explicit permission. It remains separate from the five coaching metrics.
- [x] Simulator build and unit-test evidence after canonical Verification attribution: `MingSiTests` 905 passed, 1 skipped, 0 failed. Full UI regression is not included in this evidence.
- [x] The fixed `MingSi Dev` iPhone 17 simulator (`9F93EE80-68DF-4922-8A73-B0590F5143D4`) is available for manual testing, isolated from UI-test fixture data; no other device is part of daily execution.
- [x] Manual-case dead-end is closed: the central model receives each new manual Case before presenting a training prescription; vNext missing-key/offline mode stays retryable without promoting a local judgment, legacy missing prescriptions self-repair on open, injected preview questions stay Case-scoped, and restart restores the active Case state without evidence crossover.
- [x] Settings separates ordinary model/data controls from advanced Prompt diagnostics and local asset packs; production UI hides remote registry, subscription, remote-manifest, and Marketplace surfaces while QA fixtures retain coverage.
- [x] Post-fix unit/VNext regression passes: `VNextTests` 79 passed; full `MingSiTests` executed 967 with 1 skipped and 0 failures. `MingSiUITests.swift` is no longer incorrectly compiled into the unit-test target.
- [x] Today judgment-stage density gate passes: Guidance details and state actions are progressive disclosure, coach feedback follows the training content, and the first answer field no longer overlaps the fixed primary action on the dedicated iPhone 17 simulator.
- [x] `MingSi Dev` normal persisted-data launch remains alive with no crash report or process fault; the observed install/launch failure was traced to full local storage and recovered by removing only regenerable MingSi DerivedData. Daily debugging remains simulator-only.
- [x] Growth shows the controlled weekly-review evidence gate before exposing its generate action: the local 7-day verification and day-coverage progress matches `WeeklyGuidanceReviewPolicy`, and an AI generation command appears only after the existing 3-verification, 2-day threshold is met.
- [x] Black-box migration rehearsal passes against the preserved real v32 database copy: the consistent backup remains at v32, the working database reaches v38, all legacy record counts remain intact, and current Growth evidence has zero missing Case links or duplicate evidence keys.
- [x] Synthetic v1 and complex v32 fixtures continue to prove schema backfill, export coverage, and failure rollback.
- [x] Full `MingSiUITests` regression: 55 passed, 0 failed on the fixed iPhone 17 simulator UDID. The stale side-quest fixture assertion was aligned with the stable catalog title and independently rerun before the passing suite.
- [ ] Real-device launch remains pending and is intentionally not used for daily debugging.
- [ ] 3-7 day real-use trial: remains READY; no user-generated observations exist, so the Day 1-7 record remains blank. It begins only with intentional normal use on the fixed iPhone 17 simulator.

The current next objective is the **3-7 day real-use trial**. Daily execution remains on the fixed simulator only; no other device launch is scheduled. Prompt copy changes remain frozen until presented-turn feedback provides repeated evidence such as `wrong_target`, `repetitive`, or `too_abstract`.

Use [vnext-real-use-trial.md](vnext-real-use-trial.md) for the daily privacy-minimized record and the vNext.1 decision summary.

The implementation source of truth is [vnext-final-execution-plan.md](vnext-final-execution-plan.md).

## Experience Gate

After implementation acceptance, run a 3-7 day real-use trial. Record:

- daily matter count and AI grouping edit rate;
- completion, suspension, and abandonment stage per matter;
- any evidence crossover or wrong context use;
- coach feedback: useful, wrong target, repetitive, too abstract, or gave away the answer;
- action completion-criteria quality;
- verification completion and deferral reasons;
- whether growth settlement feels credible without inviting score gaming;
- whether project closure creates reusable principles;
- guidance frequency, repetition, and mastery accuracy.

The trial informs vNext.1. It is not a prerequisite for this implementation.

## Explicitly Deferred

`Provider Profile Foundation v1` is superseded by this milestone and is not the current goal. Do not start multi-provider expansion, account/user center, cloud sync, team collaboration, a remote guidance marketplace, rankings, streak incentives, or a new score for the five evidence-based coaching metrics until vNext has passed implementation acceptance and the real-use trial. The side-quest life-experience ledger is intentionally separate from those metrics.

## Constraints

- Do not expose engineering state names in product UI.
- Do not allow simultaneous active coaching requests for multiple matters.
- Do not auto-confirm, merge, split, close, restore, or save principles.
- Do not bypass the central decision center for a meaningful recommendation or classification. Do not add gratuitous calls when no decision is required. A configured model failure must remain retryable; it must not be replaced by a local-looking judgment.
- Do not turn Projects into task management.
- Do not add per-session scores, ranking, or personality judgments. Positive side-quest life experience, optional notifications, and its non-punitive continuity record are allowed and remain separate from the five coaching metrics. Mainline streak incentives remain out of scope.
- Do not delete old data or rewrite historical verification facts.
- Keep API keys in Keychain and out of database export, logs, and PromptRun content.


## 2026-10-18 result-review evidence update

The active objective remains app-wide thinking/guidance quality and usability. Three actual synthetic result-calibration responses now cover support, counterexample, and conflicting records. The receipt/persistence chain now keeps the model assessment separate from user self-ratings; v73 preserves legacy nil assessment. Full unit checks passed (1390 passed; 7 opt-in skipped). Rendered UI evidence and limitations are tracked in [the result-calibration report](qa/2026-10-18-result-calibration/README.md).

Do not close the milestone: lens learning and growth context still consume self-ratings on some paths, observed results do not prove selected-principle practice, verification submission concurrency needs review, and real-device/daily-use acceptance remains missing.

## 2026-10-18 historical-evidence update

History no longer converts self-ratings into method reinforcement/veto. Current question/action/growth prompts receive reported outcomes and saved uncertainty; per-case ownership and every verification in a growth scope are retained. Actual 伊莉丝 acceptance exposed and fixed an action method-label veto; the exact response now passes with valid sources and fails with invented sources. Full unit: 1395 passed, 0 failed, 8 opt-in skipped. Final three synthetic model responses were individually reviewed by Codex AI, with readability/tone reservations; initial failures remain in [the history-evidence report](qa/2026-10-18-history-evidence/README.md).

This supersedes the preceding lens-history/context gap only for the covered production paths. The active product objective remains open: principle-practice attribution, repeated/late verification submissions, neutral result-input wording, legacy local scoring, largest-font reading burden, real-device and daily-use effectiveness remain unproven or unfinished. No new UI acceptance or package release in this iteration.

## 2026-10-18 neutral-result submission update

Result capture now asks for observations before self-ratings and supports unresolved judgment. Submission locks synchronously, allows cancellation during the model phase, rejects stale responses, and retries the same prepared result/IDs after storage failure. Original-source preflight precedes the model; historical case completion uses the repository. Full unit: 1402 passed, 0 failed, 8 opt-in skipped. Final two UI tests passed without skips, including Light normal text and Dark largest accessibility input/cancel/preserved-text/resubmit. Earlier fixture and scrolling failures remain documented in [the submission report](qa/2026-10-18-neutral-result-submission/README.md). No new external model calls or package release.

The active product objective remains open. Retry preparation is process memory, not restart idempotency; case status and derived writes remain outside the core result transaction. Principle-practice attribution, background guidance lifecycle, legacy scoring, VoiceOver, large-text reading burden, phone and daily-use effectiveness remain unproven.


## 2026-10-18 principle-behavior evidence update

The active objective remains thinking/guidance quality and usability. Principle selection, positive outcomes, helpful recalls and three records no longer establish practice/internalization. verifyQuest 1.11.0/schema 5 separates reported behavior from outcome using supplied actions and exact quotes; v74 keeps the nullable classification, legacy associations remain unassessed, and new valid reports are deduplicated without deleting old rows. Full unit: 1409 passed, 0 failed, 9 opt-in skipped. Two fixture UI tests passed in Light normal/Dark largest text; four real 伊莉丝 responses separately passed and were individually reviewed by Codex AI. One response remains too long. See [the practice-evidence report](qa/2026-10-18-principle-practice-evidence/README.md) for initial failures, disk recovery and visual evidence limits.

This does not establish independently observed behavior, causal effectiveness, full UI driven by real model output, phone compatibility or longitudinal usefulness. Derived practice projection remains outside the core transaction; crash recovery and complete historical audit are not established. Legacy local scoring, background guidance lifecycle, large-text reading burden and personal use remain open. No package release; overall goal remains active.

## 2026-10-18 guidance-behavior evidence update

The objective remains app-wide thinking/guidance quality and usability. evaluateGuidanceEvidence 1.1.0/schema 2 separates reported behavior from outcomes/self-ratings and requires grounded quotes. Repeated sources count once; support counts no longer imply mastery. SQLite read/modify/write operations are transactional, optional tasks are tracked/cancelled on background/configuration changes, and late network results are rejected. Full unit: 1417 passed, 0 failed, 10 opt-in skipped. Three actual 伊莉丝 responses were read individually by Codex AI and accepted for their finite synthetic cases; compilation and initial date-precision failures remain in [the guidance-evidence report](qa/2026-10-18-guidance-evidence/README.md).

The earlier background-guidance gap is covered only by the tested orchestration. No system-background UI, restart recovery queue, independent behavior observation, complete historical audit, phone or longitudinal effectiveness is established. Historical automatic mastered states remain because their provenance is unknown. Legacy local scoring, large-text reading burden and other daily-use gaps remain open. No package release; keep the overall goal active.

## 2026-10-18 growth-evidence boundary update

The app-wide thinking/guidance objective remains active. Retired local fixed-score generation is removed, including legacy migration-fallback and injected-service paths. Workflow completion and favorable self-ratings preserve reported results without creating growth scores. Known retired summaries are hidden from score display, history attribution and future baselines without rewriting stored rows; filtering before version selection preserves older other reports. The growth page reports the count in currently loaded history without claiming that three records prove change, and offers a working return to Today.

Final full unit: 1418 passed, 0 failed, 10 opt-in skipped. Final focused unit/UI: 2 passed; six actual Light normal/Dark largest-text screenshots were opened and reviewed. Large text still takes substantial scrolling; the three-record screenshot shows the return button below the visible text, while the test separately scrolls to it and returns successfully. No external model calls or Prompt version changes this iteration. Before-fix failures, stale fixtures and initial false theme/font coverage are preserved in [the growth-evidence boundary report](qa/2026-10-18-growth-evidence-boundary/README.md).

Repeated-pattern local diagnoses remain a concrete next concern: generic fixture records are labelled as communication problems. Unknown historical provenance, snapshot/contribution crash consistency, VoiceOver, phone and longitudinal usefulness are unproven. No package release; keep the overall objective active.

## 2026-10-18 historical discussion and ability boundaries

The overall thinking/guidance goal remains active. Retired keyword-based history diagnoses no longer run or enter any production Prompt, even if an old caller supplies them. generateQuests 1.11.0 preserves 1.10.0 and states that discussion labels/assistant questions cannot establish deficits or training needs. Growth now offers saved answered-question topics with verbatim answers and individual History/Case links, preserving cross-record reflection without manufacturing a user profile. Sources require matching confirmed non-excluded cards; canonical per-Case reflection overrides old lens copies, duplicate records/questions do not inflate counts, and unknown old classifications are not backfilled.

Final full unit: 1423 passed, 0 failed, 11 opt-in skipped; focused unit/UI: 5 passed. Actual Light normal/Dark largest text expansion and source navigation passed, all three exported images were read by Codex AI. SQLite reload without lens sessions preserves questions/answers and Case deep links. Two actual 伊莉丝 Responses completions were individually reviewed and accepted for the limited boundary cases, with verbosity and a confusing negative calibration target still noted. Failures and the corrupt result archive remain in [the topic report](qa/2026-10-18-reflection-topics/README.md). Normal app relaunched; no package released.

Completion remains unproven for app-wide guidance quality. Other local Today coaching paths, concrete and concise calibration targets, historical provenance, crash-atomic snapshot/contribution persistence, VoiceOver, phone and longitudinal usefulness are still outstanding. Do not turn this local fix or test count into an overall completion claim.


## 2026-10-21 auxiliary guidance presentation update

The overall thinking/guidance objective stays active. recommendGuidance 1.1.0/schema 1 adds current user answers and separately labelled prior AI assistance/stop boundary, while preserving the complete 1.0.0 rollback. Exact-context decisions coalesce and validated show/hold reuse stays bounded to process memory; failures and stale decisions are not cached. Actual appearance records cooldown transactionally without claiming the hint was read or learned. Preferences and evidence survive late receipts. Final signed unit: 1485 passed, zero failed, 18 opt-in skipped. One UI test passed both Light normal and Dark largest accessibility expansion/dismissal, with two screenshots individually reviewed. One live acceptance passed two distinct 伊莉丝 synthetic decisions (hold on already explained values + stop, show on a requested observation/intent distinction), each assistant response read by Codex AI. Initial regression failures and a mistaken test expectation remain in [the report](qa/2026-10-21-guidance-presentation/README.md).

The normal signed simulator App is restored. The UI fixture and live model test are separate evidence, not a combined network UI flow or proof of improved ability. Largest-text scrolling burden, manual VoiceOver, personal daily-use and phone acceptance remain unproven; no package release.
