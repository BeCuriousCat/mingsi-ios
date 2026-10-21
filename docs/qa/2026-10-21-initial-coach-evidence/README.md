# 初始思考建议的材料边界 · 2026-10-21

继续处理明思的最大产品问题：为了走完训练流程，把未知和自愿回顾变成缺陷诊断与作业。本轮在当前源代码确认两条实际链路：

- `CoachDecisionAIService` 旧 schema 只返回阶段、方法和理由，`CoachTurnPolicy.makeInitialTurn` 却把 `fill_evidence_gap` 自动映射为“缺观察事实、缺基线”。模型没有说缺哪一项，客户端仍会展示并把这些缺口带入后续回答复盘。
- 选择视角页在任何模型结果之前调用 `CoachObservationPolicy`，同时把模型选择置信度显示成百分比，再用本地 `CoachTeachingPolicy` 补一套训练路线。当前代码不能证明这些判断来自模型或用户的材料。
- 推荐卡“跳过”仍保留推荐透镜，“只按今天材料继续”仍保留先前选中的内置或自定义透镜；恢复时旧 LensSession 还会覆盖当前明确不选透镜的会话。

## 本轮改动

`diagnoseTrainingCase` 独立 1.1.0 / schema 2，保留 1.0.0 原文回退。只提出一个可能有帮助的观察角度，明确说这是材料建议而非能力诊断，感受不是错误、单次事件不是稳定缺陷、原因未知不等于缺观察。最多一个实际缺口，已有材料不重复索要；没有必要追问或用户停下时允许空缺口，`not_ready` 不再意味着必须修补才能继续。

当前服务只使用本事项已确认且未排除的卡片，要求精确卡片 ID 来源，拒绝缺字段、未知缺口、多缺口、其他事项来源或 ready 与非空缺口冲突。现有 Case ID 是审计范围，不能作为具体材料引用。没有新增自动重试。

两处不选视角入口现统一清除内置/自定义选择及旧回答复盘，保留已填写的问题和答案；先保存明确的无透镜会话，再继续生成。恢复时当前会话的空选择优先于旧 LensSession，旧行及答案保留。修改前实际回归 **0 通过、3 失败**，见[失败摘要](evidence/skip-before-summary.json)；修正后同三条 **3 通过、0 失败/跳过**，见[修正摘要](evidence/skip-fixed-summary.json)，`/tmp/mingsi-initial-coach-skip-fixed-20261021.xcresult`。

`CoachDiagnosis` 携带模型的缺口和来源，初始轮次沿用明确缺口。旧模型决定缺字段时不从阶段补造；显式本地预览保留旧行为。选择页隐藏生产的本地关键词观察与本地训练路线，去掉未校准的置信度百分比，标注“当前材料的暂定理解”“可选视角”。继续不选视角的入口保留。初次 UI 3 项通过后逐张复看发现理由重复、最大字号固定按钮区仍占用过多阅读空间；已移除模型初始理由的重复轮次文案，并让选择视角页的辅助字号操作区随正文滚动。

## 验证记录

恢复空间后的专项 **279 通过、0 失败/跳过**，见[摘要](evidence/focused-summary.json)，`/tmp/mingsi-initial-coach-focused-recovered-20261021.xcresult`。涵盖明确约束缺口而非凭阶段补观察/基线、未知且无必要修补、旧模型缺口未知、非法/未确认/被排除/跨事项来源、损坏字段和 ready 状态冲突。

初次隔离 UI **3 通过、0 失败/跳过**，见[摘要](evidence/ui-summary.json)。包括实际选择页普通浅色/最大字号深色的完整理由阅读与不选视角继续、空缺口没有缺口标签，以及两条既有预览 UI。两张截图已由 Codex AI 打开，仍发现重复理由和大字号固定操作区，因此不把初次绿灯作为最终界面通过，见[阅读复核](evidence/ui/reading-review.json)。这份初次结果不包含后来补齐的真实推荐卡夹具。

此前另一次 `ui-final` 的三条通过修复了重复理由和固定操作区，但其夹具没有构造真实形状的 TrainingPrescription，不能证明推荐卡或卡内跳过可用。本次夹具补上推荐卡，并先接受推荐、再分别点击“不选视角继续”和卡内“跳过”，要求实际进入回答页；修正夹具的最终 UI **3 通过、0 失败/跳过**，见[摘要](evidence/ui-card-summary.json)，`/tmp/mingsi-initial-coach-card-ui-20261021.xcresult`。两张最终截图均已逐张打开，见[清单](evidence/ui-card/manifest.json)与[阅读复核](evidence/ui-card/reading-review.json)：浅色能同屏看到完整理由和推荐卡，实际最大辅助字号能完整读完理由，并通过滚动操作接受/跳过。截图没有捕获跳过按钮本身，按钮可操作由实际 UI 测试另证。推荐卡仍重复同一理由，最大字号滚动较长，不认可全页面低阅读负担或 VoiceOver 通过。

伊莉丝生产适配器实际调用 **3 次请求、3 次完整回应、无重试**，对应 1 条 live 测试通过，见[执行摘要](evidence/live-summary.json)、[完整 Prompt/上下文与归一正文](evidence/live/manifest.json)、[逐条 AI 语义复核](evidence/live/semantic-review.json)。已有观察但原因未知、明确停止、自愿只看自然重试均保留原边界，没有重复索要已有事实或增加作业。所有样本返回空缺口是合理的，但不证明模型在应当指出缺口时仍能提供具体帮助；另一个新正向引导样本已单独完成 **1 次请求、1 次完整回应、无重试**，见[摘要](evidence/live-positive-summary.json)、[完整附件](evidence/live-positive/manifest.json)和[逐条 AI 复核](evidence/live-positive/semantic-review.json)。用户把一次晚交推断成“肯定故意不配合”，模型明确指出缺因果联系，未从 fill_evidence_gap 补造缺观察/基线；允许未知且不安排新任务。测试沿用了“上传回看”的通用 Case 标题，正文匹配但场景真实性有限。不重复之前三次请求，不据四个样本估计稳定成功率。

真实停止样本选择 slow_down_convergence；其正文尊重结束，但旧客户端通用标签会显示“补齐关键证据”，与正文冲突。已移除生产初始卡的本地阶段/通用建议标签和重复的接受/放慢/推进按钮，保留具体理由、明确缺口以及独立的视角选择/跳过控件。不能只凭正文通过认定原产品边界已通过。

最终当前源代码完整单元 **1437 通过、0 失败、12 项 opt-in 跳过**，见[摘要](evidence/full-unit-current-summary.json)，`/tmp/mingsi-initial-coach-unit-current-20261021.xcresult`。已逐项检查[测试范围](evidence/full-unit-current-test-scope.json)，跳过项全部是需显式开关的外部模型/连接导入测试；本轮四次真实初始决定在独立 live 测试中完成。先前 `unit-final` 的 1435 通过结果早于跳过修复，保留为历史证据。单元、隔离 UI 和实际模型输出分别验收；任何一项通过均不能代替完整个人使用或手机验收。最后已无夹具参数重启正常 App，见[启动记录](evidence/normal-app-launch.json)。[定向凭据扫描](evidence/security-check.json)未检出当前密钥字面值或临时凭据 xctestrun，脚本语法和 git diff --check 通过。

本机存储不足背景下，先后将 73 个早期同任务结果包压缩，逐文件核对 SHA256 与符号链接后才移除原目录，路径见[恢复记录](evidence/storage-recovery.json)。未清除用户数据或模拟器 Keychain。第一次本轮构建到达签名阶段后报签名子系统 internal error，未执行测试。手动对生成 dylib 的 ad-hoc 签名成功后，第二次构建成功；不把初次失败归因于已证明的单一原因。首轮专项执行随后遇到磁盘不足，四条文件数据库测试报失败且结果摘要写出失败；保留 `/tmp/mingsi-initial-coach-focused-20261021.xcresult` 和日志，不把它统计为通过。进一步归档后只执行 test-without-building，避免重新生成构建缓存。

## 尚未证明

来源 ID 校验不证明模型理由在语义上必然被原文支持。初始接口仍要求选择一个候选透镜，尚没有完全独立的“不推荐方法”结果；候选可跳过，不能宣称全产品已没有训练惯性。恢复时重发初始决策、回答页“看明思为什么这样问”仍调用本地观察/训练路线，其他本地回答观察与提示、跨仓储恢复一致性、VoiceOver、手机和长期个人使用仍待审视。未发布安装包，总体目标继续进行。
