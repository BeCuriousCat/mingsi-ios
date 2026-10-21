# 透镜扩充、提示词与布局验收 · 2026-10-21

用户要求判断哪些角度值得做成透镜、打磨提升思考能力的提示词，并按通用设计规范修正文字贴边、对齐及布局问题。选题取舍和十种方法的具体能力目标见[设计记录](../../lens-library-design.md)。

本文保留初次扩充的 builtin.v2 / generateQuestions 1.27.0 及当时验收记录。当前目录 builtin.v3、问题生成 1.29.0/schema 7，后续差异、直接讲解和回答承接均见上述设计记录及各专项报告；后续导师 2.15.0 三轮请求已通过，见[报告](../2026-10-21-mentor-request/README.md)；当前 2.16.0 的长材料选择修正与本地回归见[最新报告](../2026-10-21-context-selection/README.md)。2.14.0 的原传输失败仍保留在对应报告。不得用初次记录的版本或效果代替当前全部功能验收。

## 已实现

- builtin.v2：保留六种方法的持久化 id，补充机会成本、可逆决策、换位理解、可控边界，合计十种。它们分别对应取舍、承诺退出成本、他人已知处境、个人决定权，复用现有 reasoning move 与存储方式。
- 每种方法分别定义目的、一次思考动作、可回答示例、适用条件、停用边界与自愿行动规则。方法不会因被选择就强制制造问题，也不默认明日任务。
- `generateQuestions` 1.27.0 / schema 6、回退 1.26.0，修正主动检查判断与直接要答案的区分、末尾检查歧义以及已有回答必须追问的规则。`diagnoseTrainingCase` 1.2.0 / schema 2、回退 1.1.0，由当前完整方法目录提供可选范围与条件。
- 选择页三组单列：完整换行，标题不再限一行，移除无意义的顺序编号和固定卡片高度，选择与说明为独立控件。说明页解释能力目标、场景、一个问题和边界，选中后返回，不自动调用模型。自定义创建入口渐进披露。
- 推荐卡两侧留白一致，去掉粗左条；多行标签用可扩展矩形，大字号操作纵向排列并保持 44pt 目标。首页入口明确左对齐、多行文本与纵向留白。范围为本次相关页面，不宣称全 App 已符合所有设计规范。

依据本项目 DESIGN.md 与已读取的 [Apple HIG Layout](https://developer.apple.com/design/human-interface-guidelines/layout) 中阅读顺序、对齐、分组、渐进披露、适应文本大小与安全区原则。对称是同级内边距和布局规则一致，不是让所有正文居中或机械等高。

## 初始失败与修正

首次 build-for-testing 因新增测试误把非 Codable 的 DailyEntryDraft 当作 Codable 而失败。改为实际 SQLiteDailyEntryRepository 保存/恢复测试；没有为了测试改变生产数据模型。

首轮完整单元为 **1432 通过、9 失败、13 opt-in 跳过**，原结果 `/tmp/mingsi-lens-library-unit-20261021.xcresult` 与[摘要](evidence/unit-initial-summary.json)保留。发现旧 LensCatalogContext 无 packVersion 时从当前目录补版本，导致历史 builtin.v1 被标成 builtin.v2，现改为使用历史记录自身的版本。原历史 fixture 和 v1 断言保留。其他失败为更新后的目录文案/版本断言和新增恢复测试的同毫秒排序假设；分别对照当前契约更新，恢复测试用明确递增时间，无需改数据库排序。

## 已完成的本地验证

修正后的完整单元 **1441 通过、0 失败、13 opt-in 跳过**，结果 `/tmp/mingsi-lens-library-unit-final-20261021.xcresult`，见[摘要](evidence/unit-final-summary.json)及[逐项跳过范围](evidence/unit-skipped-scope.json)。13 项均为 LiveGLMAcceptanceTests 的外部调用或导入开关；新增四个方法的实际请求另行显式执行，不把跳过算作效果通过。

这次之后发现真实可控边界回复被 `missingThinkingMaterialTarget` 误拦：旧规则要求可见文案出现“缺、证据、约束”等词。现增加有条件的结构化路径：必须为约束分解/缺约束，具备完整用途字段、来源标题与具体判断对象，原词汇路径及其他质量门保留。没有来源与模糊判断对象的负例仍被拒绝。

逻辑修正后（含结构化边界门与分组裁切）重新构建并完成完整回归：**1443 通过、0 失败、13 opt-in 跳过**，结果 `/tmp/mingsi-lens-library-replay-unit-20261021.xcresult`，见[最终摘要](evidence/unit-replay-final-summary.json)、[关键回放/负例](evidence/unit-replay-key-tests.json)、[逐项跳过](evidence/unit-replay-skipped-scope.json)。四个真实 assistant 正文原样经 TodayAIService 回放全部通过，问题、允许结束条件和来源保持原样，不改写原回复、不重复付费请求。

首轮 UI 夹具错误接入 speechInputUIFixture，实际生产启动打开空事项概览。已停止该轮，记录[中断审查](evidence/ui-interrupted-review.json)与[原始摘要](evidence/ui-interrupted-summary.json)，未认可其中的透镜页面结果。夹具已移到正确的隔离 mentor startup 分支并重新构建。

## 真实模型：四次请求、保留原失败

通过已授权 CC Switch 当前伊莉丝 HTTPS Responses 连接，别名 `gpt-6.1-sol`，每个新增透镜各一次合成请求，无自动重试。四个完整回复均留存并逐项 AI 语义审读。原测试 **0 通过/1 失败**：前三个解析通过，第四个可控边界被上述本地词汇门误拦。[原在线摘要](evidence/live-summary.json)保持失败，不用后续离线回放替换它。

[语义审读与完整正文索引](evidence/live/semantic-review.json)区分模型输出、本地接受和语义判断：机会成本比较真实牺牲，不替用户排序；可逆决策检查已知退出条件，不要求先试；可控边界不把领导情绪归责用户。“换位理解”保持原话与推测边界，但实际问题更接近证据检查，尚未充分展开对方已知人手限制。一次合成结果不能证明所有方法完全独立，也不能证明能力提升。文件为保留 assistant 文本的适配后 envelope，非原始 SSE；模型别名不作为上游身份或计费证明。

## 实际 UI：发现问题再修正

固定 iPhone 17 / iOS 26.5，串行执行且不收集额外诊断。正确夹具后的第一轮六项 UI **5 通过、1 失败**，见[摘要](evidence/ui-first-render-summary.json)、[实际审图](evidence/ui-first-render-review.json)。透镜项在最大字号改选后说明按钮被推到视口外，测试错误假定它立即可点；截图还暴露真实的选项重叠、图标溢出、模态字号未继承与深色按钮对比不足。

集中修正选项、按钮与文字栈的实际行高，关闭分组隐式重排动画，图标保留紧凑 20pt、说明目标保持 44pt。模态显式传递当前字号，新增字号增长断言；主按钮使用 DS.onAccent。测试滚动到可见的说明入口再操作，分别保留推荐操作区的截图。

针对性确认两项 **2 通过、0 失败**，见[摘要](evidence/ui-confirm-summary.json)。11 张新增透镜截图已分别打开审读，见[逐图范围和结论](evidence/ui-confirm-review.json)：四个新选择的普通字号不再重叠；最大字号各行独立、说明页文字确实放大且底部按钮可读，推荐操作纵排并留足空间；普通说明完整展示目的、场景、示例与边界并可选中返回。首页普通字号截图另已打开，入口左对齐且有明确留白。

审读确认时又发现浅色机会成本推荐卡的小字使用浅金色，存在实际对比问题。因此只将卡片三处文字色改成 DS.accentInk；没有再展开一般视觉迭代。最后完整单元早于这些 UI 行高、字号传递与文字色修正；UI 修正已重新构建，Prompt/业务逻辑未再改变。最后只针对这一真实对比缺陷重跑透镜 UI：**1 通过、0 失败、0 跳过**，见[摘要](evidence/ui-contrast-summary.json)。浅色推荐文字与深色操作区两张截图均已分别打开，确认正文改用清晰文字色、背景和按钮布局保持可读，见[审读](evidence/ui-contrast-review.json)。未追加模型请求或一般审美迭代。

[颜色计算](evidence/button-palette-contrast.json)中，深色浅绿底白字约 2.23:1，改用 DS.onAccent 后约 8.23:1；浅色主按钮约 7.96:1。它是设计 token 的实色计算，不能代替渲染检查或全 App WCAG 认证。

## 恢复与收尾

UI 调试阶段使用无签名构建时，正常 App 未能识别已存模型连接。首次受保护导入实际失败 `unexpectedStatus(-34018)`，见[原摘要](evidence/connection-restore-initial-summary.json)；不是模型请求失败。重用现有 DerivedData，以 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-` 重新构建，模拟器 entitlement 恢复 `GQ6YS2M625.com.codex.mingsi`。同一授权的当前伊莉丝连接仅重新保存到 Keychain，未发模型请求；导入测试 **1 通过、0 失败、0 跳过**，见[签名后摘要](evidence/connection-restore-signed-summary.json)。没有重置或删除个人数据库/Keychain。最终正常启动无 fixture 参数与测试子进程环境；首页截图和进程记录在本目录留存。

Python runner AST 与 `git diff --check` 通过，修改/新增文本及本任务日志的密钥字面量扫描无候选，受保护临时 xctestrun 剩余 0；[收尾检查](evidence/hygiene.json)不暴露值。
## 尚未覆盖

透镜选择 UI 采用隔离数据库/Keychain 的生产 model-led 路径与合成推荐，不访问个人密钥、不请求模型。真实模型另经授权伊莉丝连接执行，不能把两者混称为真实网络 UI 验收。没有手机、VoiceOver 手动朗读、稳定成功率或长期能力提升证明。导师“听一个新视角”是独立教材入口，本轮没有把它与 Today 透镜目录混为同一功能。整体思考引导目标继续进行，不发布安装包。
