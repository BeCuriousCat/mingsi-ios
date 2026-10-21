# 行动建议清晰度与未知结果 · 2026-10-18

本轮继续处理明思思考引导的核心问题：建议像作业、字段重复，且有些本地说明把证据不足错误地当成必须明天解决的事。上一轮真实输出的两份样本已保留：网络重试和已有交接记录对照。第二条把“尚不足以说明交接沟通改善”作为被支持/减弱的目标，方向容易混淆，why 中还套用了未经用户表态的“我现在相信”。

## 已修改并完成本轮有限验收

- generateQuests 1.12.0 独立组织字段，保留 1.11.0/1.10.0 原文回退与历史来源边界；目标是具体暂定命题，原始不确定性和用户边界不被改写为更强判断。具体否定预测合法，元证据限制留在解释中。
- 各字段只讲各自内容，软字数预算不能触发截断或自动重发。仍只允许一个主行动、精确来源、无侧任务，历史 AI 标签不能变成训练要求。
- 行动确认页不再重复“对应判断”，填写检查移至可选详情；保留编辑、旧原则、缺少目标时的返回修复。
- 不再要求“明天必须”留证据；没有重试、条件不可比或缺少记录可暂不能判断，空阻力不产生新作业，训练说明不作因果保证。

## 修改前与过程证据

修改前专门回归 0 通过、2 失败，见 [before-summary.json](evidence/before-summary.json)，证明强制套句式和本地未知结果边界确有问题。首次相关套件 491 通过、5 失败，见 [related-initial-summary.json](evidence/related-initial-summary.json)：旧文案断言与新字段职责不符，保留相应行为约束后更新测试。修订后定向合同 71 通过、0 失败/跳过，见 [contracts-summary.json](evidence/contracts-summary.json)。

早期 UI 摘要虽有 2 个通过（[ui-captured-final-summary.json](evidence/ui-captured-final-summary.json)），当时的辅助函数允许文字只部分进入可见区。复看最大辅助字号截图发现固定操作栏占据近半屏，正文末段仍会被挡住；增加底部留白也没有消除固定栏的阅读负担。因此撤回之前“最大字号可读性通过”的结论。这些绿灯不能作为完整阅读或操作验收。

修正方向是仅在行动确认页的辅助字号下，把操作区放进正文底部一起滚动；普通字号保留原有固定操作栏。测试改为要求目标、完成证据、校准问题各自完整落在状态栏下、固定栏和 Tab 栏上方，并检查保存按钮可点、保存后进入完成状态。首轮严格检查 2 通过/1 失败，见 [ui-reading-initial-summary.json](evidence/ui-reading-initial-summary.json)：两个页面回归通过，真实回应回放在浅色的保存按钮上失败。检查活动和截图确认是测试把固定栏里的按钮也当成必须滚到固定栏上方的正文；正文读取检查保留，固定按钮另检查位置和可点性。下段记录修订后的严格结果，不以先前通过替代。

修订后该回放测试 **1 通过、0 失败/跳过**，见 [ui-reading-final-summary.json](evidence/ui-reading-final-summary.json)，`/tmp/mingsi-action-reading-fix-20261020.xcresult`。Codex AI 打开全部五张不同截图：浅色正常字号的目标与观察标准可读；深色最大辅助字号的操作栏已随内容滚动，目标、观察标准各自能完整读完，保存按钮也完整露出。六个附件中浅色保存与上一张观察标准截图共用同一图像，清单保留两个名称，见 [截图](evidence/ui-reading-final/manifest.json) 和 [阅读复核](evidence/ui-reading-final/reading-review.json)。测试另检查校准问题完整可见，并实际保存进入完成状态。只认可此页有限内容的阅读和保存路径，最大字号滚动距离仍长；不以此证明全 Today 阅读负担、VoiceOver、真实网络 UI 或手机通过。

本轮官方方法依据为 [OpenAI Docs / Prompt guidance](https://developers.openai.com/api/docs/guides/prompt-guidance)：同一指令只写一次，并复跑相同样本。第三方模型别名不用于推断上游身份；没有因此改动接口或模型。

## 尚未证明

本轮模型语义、严格局部 UI 和完整单元回归已有证据；全页面 UI、手机和长期个人使用尚未在本轮证明。截图中的 DEBUG 视觉验证提示表明使用隔离夹具，不代表正常用户页面。不能把这部分改进解释为整个 App 完成。本轮发现无主行动返回仍被既有解析器拒绝为空结果；后续已接通可保存的无行动回顾，验证见 [无行动回顾](../2026-10-20-no-action/README.md)。其他本地提示中还存在“明天”措辞，未把本轮对未知结果的修正扩大宣称为全部路径已清理。

最终完整 MingSiTests **1427 通过、0 失败、11 跳过**，见 [full-unit-final-summary.json](evidence/full-unit-final-summary.json)，`/tmp/mingsi-action-clarity-full-unit-20261020.xcresult`。已逐项检查跳过列表，均为显式 opt-in 的模型调用或连接导入；本轮已有的三个真实模型回应单独留档，没有重复付费调用来追求通过。完整回归使用正常 xctestrun，未启用 live 或导入环境变量。

`git diff --check` 和接入脚本语法检查通过；669 个当前修改/新增文件与本轮相关日志未检出当前订阅密钥字面值，构建目录没有本次 CC Switch 临时凭据文件，见 [security-check-20261020.json](evidence/security-check-20261020.json)。这不替代全历史秘密扫描。

## 真实调用的首个发现

首轮 1.12.0 实际请求一次、完整回应一次，无重试；生产服务被旧 weakCompletionCriteria 门拒绝，测试 0 通过/1 失败，见 [live-initial-summary.json](evidence/live-initial-summary.json) 和 [完整请求与准确归一回应](evidence/live-initial/manifest.json)。Codex AI 已审读两份附件，见 [semantic-review.json](evidence/live-initial/semantic-review.json)：同一朋友、自然重试、网络恢复和说明不变均保留；不催促、不改说明、不做沟通训练；没有重试或条件不明仍未知，不把结果证明为说明质量/退出原因。

旧门只认“记录、完成”等词，不认“观察提交是否成功”，使有效且无需另造文档的行动被拒绝。局部修正为观察/对照/比较/核对须与具体结果或比较信号同时存在，保留最少长度、来源、忙碌任务和其他检查；单说“观察想法和感受”仍拒绝。准确回应进入生产服务回放，不重新请求该样本来追求绿灯。之后用当前伊莉丝连接执行剩余两个样本：2 次请求、2 次完整回应、0 重试，见 [live-remaining-summary.json](evidence/live-remaining-summary.json)、[完整附件](evidence/live-remaining/manifest.json) 和 [语义复核](evidence/live-remaining-semantic-review.json)。

首个样本六个主要字段由 362 字到 199 字，见 [字数记录](evidence/network-length-comparison.json)。保留必要限制优先于软预算；该比较不是稳定效果估计。

## 验证基础设施过程

磁盘不足导致一次签名构建失败（0 测试执行，非行为失败），见 [摘要](evidence/storage-failed-build-summary.json)。先清除本任务可重建索引/模块缓存，再把早期同任务结果包打包：逐文件校对 SHA256、文件数和符号链接通过后才移除原目录，见 [storage-recovery.json](evidence/storage-recovery.json)，恢复路径为 `/tmp/mingsi-principle-practice-final-unit-ui-20261018.xcresult.tar.gz`。两次空间不足的压缩尝试仅删除自身未完成文件，原包保留。另一次 DEBUG 夹具编译错误是将 thinkingCards 误写为 cards，已修正，未执行测试。没有清除模拟器、凭据或个人记录。

一次 UI 复验还没结束时误启动了同一模拟器的 live 套件，导致被测 App 被另一测试杀掉；该“App 未运行”不能归因于产品崩溃。之后设备套件串行执行。早期部分中间 xcresult 已删除，只保留部分摘要、日志或导出附件，未完整归档，无法声称保留全部中间证据；最终与真实调用结果包继续保留。
