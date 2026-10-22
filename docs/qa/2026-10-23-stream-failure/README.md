# 流式失败分类与终态真实性 · 2026-10-23

关联G1数据与状态真实、G3网络诊断。本轮基于`964ab4f`，没有启动真实使用窗口，没有模型付费请求，也没有解释过去三次服务失败的原因。

## 实际缺陷与基线

检查普通Chat Completions的生产流式分支发现：EOF会直接发.completed；HTTP200的error数据包解析失败后会被忽略，随后DONE仍发.completed。通用网络错误还将error.localizedDescription拼到用户提示，可能含URL或私人诊断。

三项修改前测试全部失败，见[基线摘要](baseline-summary.json)，原bundle`/tmp/mingsi-stream-failure-baseline-20261023.xcresult`。这证明规定路径中的问题，不代表真实网络所有故障已定位。

## 修订

- 普通Chat流要求明确DONE才结束，EOF、HTTP200内错误、length/content_filter/tool_calls等非正常finish_reason不能当完成。导师仍要求stop与DONE同时成立；普通兼容流沿用仅DONE的供应商支持，不能据此保证供应商语义完整。
- Responses的failed/incomplete/error/refusal分别归入固定事件和原因枚举。只有批准的code/type映射为额度、频率、权限、服务暂不可用、上下文、输出上限等；未知值保持unknown，不看message猜原因，不保留原message/param/ID/未知code。
- HTTP已知额度失败不自动重试；普通未分类429/5xx既有有界重试策略保留。导师仍一次HTTP、无格式回退，不增加自动Agent循环。
- 用户提示说明可操作的下一步；通用transport不再拼接系统描述。合成在线验收附件保留固定safeDiagnosticCode，不能把泛型NSError枚举序号当服务原因。未发送新在线请求验证。
- 部分预览仍留给用户检查，不能作为完整assistant落库；明确取消与迟到结果隔离沿用原协议。

## 官方依据与适用边界

已搜索并实际抓取OpenAI Docs：[Responses streaming events](https://developers.openai.com/api/reference/resources/responses/streaming-events)。其中response.failed携带response.error，response.incomplete携带incomplete_details.reason（示例max_output_tokens），顶层error有code/message/param，refusal有独立delta/done事件。

另实际读取[错误码说明](https://developers.openai.com/api/docs/guides/error-codes)，计费/额度失败应处理账户限制，重复请求不能恢复额度。代码对常见兼容服务code采用有限映射；这些映射不是对自定义网关含义的保证。未知或缺失字段不据文案推断额度、权限或网络原因。

## 验证记录

第一次编译因ChatStreamAccumulator隐式初始化访问级别失败；加显式init。第二次编译因TodayAIService的错误switch未补新分支失败；已补审计分类。原日志`/tmp/mingsi-stream-failure-targeted-20261023.log`、`/tmp/mingsi-stream-failure-targeted-fix-20261023.log`保留。

首次编译后的相关回归191通过1失败，见[原摘要](first-targeted-summary.json)。失败为新预览用例给了纯文本delta，而导师预览按JSON的body字段展示；已改为真实协议形状，保留部分预览断言及原失败，没有削弱解析要求。

最终同一候选构建完整单元 **1524通过、24显式跳过、0失败**，总1548项，见[最终摘要](unit-final-summary.json)，原bundle`/tmp/mingsi-stream-failure-unit-final-20261023.xcresult`。覆盖传输、导师状态机、取消/恢复、审计及现有持久化回归。本轮未调整Prompt，没有真实模型输出，不把状态/传输回归当语义质量或长期能力效果。

## 未覆盖

真实网络UI、供应商真实账户/额度/限流反应、真机后台、中文识别和VoiceOver仍未验收；Mac原生工具此前报告锁屏，本轮不绕过锁屏。固定模拟器的hosted单元测试可运行不等于人工交互或手机操作。

已有历史31请求中的3次providerResponseFailed没有原始细分类信息，保持未知；不回填为额度不足或上游繁忙。新版只改善下一次失败的可解释性。

## 交付检查

最终Release模拟器构建通过（CODE_SIGNING_ALLOWED=NO），日志`/tmp/mingsi-stream-failure-release-20261023.log`。构建前清理未运行的Debug中间文件/索引/模块缓存以留出空间，保留安装产物、测试bundle、数据库与Keychain；本轮没有新的磁盘不足构建失败。25项Python脚本测试通过，原日志`/tmp/mingsi-stream-failure-python-20261023.log`。没有新增UI控件或布局，本轮未做新截图/VoiceOver/真机复验。

固定模拟器测试后已用无夹具参数发起正常App启动，命令返回进程ID；因Mac锁屏，未将命令成功称为已审读首页。无公开安装包、无手机更新。

全部暂存公开变更经Gitleaks扫描无发现，`git diff --check`通过，见[检查摘要](checks.json)。按同日发布记录同步用户可见变化；历史失败证据没有覆盖。
