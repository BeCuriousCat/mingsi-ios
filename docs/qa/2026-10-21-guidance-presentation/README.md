# 辅助提示的上下文、复用与展示记录

日期：2026-10-21。衔接[透镜设计](../../lens-library-design.md)与[初始建议恢复](../2026-10-21-initial-decision-lifecycle/README.md)。范围是 Today 辅助提示；不把它与每日人生建议卡、导师教材混为一条功能。

## 问题与实现

原辅助提示在相同事项重开时取消并重新调用模型，只读取卡片/行动/昨日结果，遗漏当前问答、已有讲解和回答复盘中的停止边界。冷却时间仅在点击偏好操作时保存。退出概览或改写同一张卡片后，迟到结果仍可进入当前页面。

现在同日、同日记录、事项/步骤/模式/视角、完整材料/问答/讲解/复盘、候选/状态、实际 Prompt 模板及配置修订共同构成请求身份。相同请求合并，成功的 show/hold 在进程内最多复用 16 项；失败/取消/过期结果不缓存。退出、切换事项、修改回答、开始回答复盘、无行动/完成步骤、重置与配置刷新会取消或拒绝过期结果。配置刷新与重置清空缓存。hold 不跨重启持久化。

`recommendGuidance` 1.1.0/schema 1，完整保留 1.0.0 回退文本。候选触发信号不代表用户缺陷；缺少 fact 类型卡片不等于缺事实。个人价值、真实取舍和一般讲解不需要先证明事实缺口。已有问答或讲解足够、用户想停下或提示只会追加任务时应 hold。用户问答与 AI 讲解/复盘分字段，后者不是行为或能力证据。不是本地关键词替代模型 show/hold 判断。

模型选中时仅生成带身份的 offer。SwiftUI 提示出现后才通过真实 repository 合并保存 lastShownAt，保留较新的掌握/暂缓偏好与行为证据；重复 appearance 不重复写。这个记录只代表渲染出现，不代表用户读完、学会或能力提升。没有新表或迁移。

界面沿用 DESIGN.md 的页边距与信息层级。提示展开后的两项操作保持至少 44pt 点击高度，普通字号并排，辅助字号纵向排列，避免挤压文字。生产提示的 appearance 连接展示回执；隔离 UI 夹具的选择内容是合成内容，偏好与展示使用真实内存 SQLite repository，不访问个人数据库或模型。

## 基线与测试过程

修改前的三项回归 **0 通过、3 失败、0 跳过**，见[基线摘要](evidence/baseline-summary.json)，原结果 `/tmp/mingsi-guidance-display-baseline-20261021.xcresult`。分别复现重复请求、退出后重现、同 ID 材料改写仍接收旧响应。

首轮完整单元有一项失败：新测试错误预期修改回答后仍保留旧讲解。现有契约是问题/回答改变时清除旧讲解；本轮保留该契约，改为分别检查修改前讲解已传入、修改后旧讲解为空，而不是修改生产行为来满足测试。首轮结果保留在 `/tmp/mingsi-guidance-display-unit-20261021.xcresult`；新版 summary 子命令报 unbalanced end of stream，已通过 legacy object 导出[原始结果与指标](evidence/unit-initial-legacy-result.json)：总 1502，失败 1，跳过 17，即通过 1484。

最终签名构建与完整单元 **1485 通过、0 失败、18 opt-in 跳过**，见[摘要](evidence/unit-final-summary.json)、[逐项跳过范围](evidence/unit-skipped-scope.json)与[提示相关测试](evidence/unit-guidance-tests.json)。覆盖请求合并/缓存、hold 与回答变化、失败可重试、迟到与停止/退出边界、真实 SQLite 展示冷却及新 store 恢复、延迟回执不覆盖偏好/证据、历史解码和 Prompt 回退。夹具服务证明生命周期，不代替真实模型效果。


磁盘低空间时，三份旧结果已压缩归档，并在移除原目录前逐文件核对 SHA256 与归档 CRC；源结果仍可从同名 `.xcresult.zip` 恢复，详见[归档记录](evidence/old-results-archive.json)。没有删除个人数据库、Keychain 或测试证据。原结果已经内部压缩，因此归档节省空间有限。


## 实际模型与页面

[页面测试](evidence/ui-summary.json)：**1 通过、0 失败、0 跳过**，单个测试覆盖浅色普通字号和深色最大辅助字号，两次均展开并点击“暂不显示”，提示消失。两张截图已分别打开审读，见[实际截图与限制](evidence/ui-visual-review.json)。普通字号保留两侧页边距和展开内容留白；最大辅助字号操作纵排，标签完整，仍需较多滚动，截图上方说明的开头在前一滚动位置。不能据此声称所有文字同时在屏幕内或全 App 阅读密度已解决。布局 detector 为[空发现](evidence/layout-detector.json)，不把静态扫描作为视觉通过的替代。

沿用授权的当前 CC Switch 伊莉丝 HTTPS Responses，配置别名 gpt-6.1-sol，每个新合成场景一次请求，无自动重发。[在线测试](evidence/live-summary.json) **1 通过、0 失败、0 跳过**，包括两个实际回应；Codex AI 已逐条读完[原正文与语义审查](evidence/live-semantic-review.json)。

- 已明确家庭优先、要求解释机会成本且想停下：hold。理由承认已有解释足够，价值取舍无需事实证明，不越过停止边界。
- 用户主动想检查“取消见面就一定不重视我”：show，仅选择当前候选。理由区分已知取消与态度推断，明确无需查明原因，可用现有经历作答。

页面夹具与外部模型验收分开执行，不能合称网络 UI 全流程。实际正文保存在适配后的 normalized envelope，不是原 SSE；模型别名不证明上游身份、计费或稳定成功率。两个场景不证明长期能力提升。

## 收尾

签名 App 已重新安装至固定 iPhone 17 / iOS 26.5，并无夹具参数正常启动（PID 23927）；没有重置个人数据库或 Keychain。[正常首页](evidence/normal-app.png)已留存，外部调用用的受保护临时 xctestrun 均移除。单元、UI 和实际模型验收使用同一最终源码构建；后续仅更新说明与证据。最终检查见[hygiene.json](evidence/hygiene.json)。未运行手机、VoiceOver 手动朗读或长期使用测试，未发布安装包；整体思考引导目标保持进行中。
