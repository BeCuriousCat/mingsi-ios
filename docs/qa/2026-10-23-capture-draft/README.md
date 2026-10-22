# 闪念草稿恢复 · 2026-10-23

所属指标：G1可信与数据、G2启动负担、G8自主性。总Goal继续进行；本轮不产生真人获益、4周复用或公开安装结论。

## 发现与修改

原闪念正文是QuickCaptureSheet的页面状态；待确认识别在共享组件的内存中，退后台直接discard。关闭保护不能防止进程终止或后台清空待确认文字。

现在正文与待确认转写分开写入本地SQLite单份草稿。正文编辑同步串行提交；语音预览和校对文字分别更新，恢复后仍需明确确认。正文正式保存与清除对应草稿是同一SQLite事务，保留尚未确认的识别；过期快照被拒绝。明确丢弃完成后失效当前编辑会话，拒绝迟到识别重建草稿。

共享语音退后台会停止音频、取消旧识别回调，保留已识别片段待检查。其他输入框同样不再因退后台直接丢弃预览，但跨进程持久化本轮仅接通闪念；原始音频从不保存。

关闭保留原有继续编辑/明确丢弃，并增加保留本机草稿关闭。草稿读取失败禁止空编辑覆盖旧内容；写入失败保留页面文字并给重试；未成功持久化不声称已保留。讨论已有闪念时必须先处理当前正文及待确认语音。

新增`v72_capture_input_draft`迁移（与其他v72项按完整名称区分），不删除旧表或数据；导出包含`capture_input_draft`私人文本。迁移实施初期在本机hosted测试启动正常App时已应用该完整ID，因此保留该迁移身份，不改名清除已存在的迁移记录。最终迁移测试复原上一已发布schema再升级，检查原闪念保留。

## 证据与原失败

- 初次编译失败：新异步测试漏写await；已修正，原日志`/tmp/mingsi-draft-unit-20261023.log`保留。
- 首批专项15项通过、0失败、0跳过：`/tmp/mingsi-draft-unit-fix-20261023.xcresult`。早于最后丢弃会话失效与迁移用例修订，不冒充最终全量结果。
- UI首轮1通过1失败：新用例误以为语音夹具首轮会最终返回，实际首轮故意保持finalizing。改为录音中退后台验证部分识别保留，保留原失败。
- 后续UI一条重启恢复用例通过；另一条遭同模拟器并发启动单元hosted App打断。调度错误不算产品通过，已停止冲突任务。
- 串行回归发现最大字号入口只露在底栏上方一小部分时，XCTest的isHittable仍为真，中心点击没打开弹窗。失败层级证据确认按钮中心在底栏外侧。测试滚动辅助改为让入口中心进入内容区，不删除业务断言。

最终完整单元 **1517通过、24显式跳过、0失败**，总1541项，见[最终单元摘要](unit-final-summary.json)，原bundle `/tmp/mingsi-draft-unit-serial-20261023.xcresult`。最终UI **2通过、0失败、0跳过**，见[最终UI摘要](ui-final-summary.json)，原bundle `/tmp/mingsi-draft-ui-visible-20261023.xcresult`。最终生产代码在两批验证之间没有变化；无并发模拟器任务。未执行项不计通过。所有UI语音均为DEBUG受控识别backend，独立测试数据库；正文保存/识别服务/控制器/草稿仓储为生产代码。不使用个人原文或API Key，无模型付费请求。

## 边界

只保留数据库成功提交的文字与已识别文本；尚未识别的音频、磁盘不可写时的新输入、设备断电前未提交的回调不承诺恢复。单份本机草稿跨日保留，直到保存或明确丢弃；不是云同步，不跨设备。同步写入避免防抖窗口的数据丢失，但真机大输入时的写入成本仍需观察。

固定iPhone17/iOS26.5模拟器；没有真实麦克风、系统权限、来电/路由中断、VoiceOver手势、手机后台/强退或真实网络UI验收。已准备[真机步骤](../../mingsi-phone-acceptance.md)，没有代填结果或更新用户手机。

## 实际交互与审图

最终UI覆盖：正文输入后结束App进程再启动；录音中退后台保留部分识别；未确认识别再结束进程重启；正文与识别分别恢复；显式确认只追加一次；保留草稿关闭再进；正式保存后重启不重复为草稿；明确丢弃后重启不恢复。另一项覆盖普通浅色与实际最大辅助字号深色的关闭/继续/丢弃、录音和校对、保存后关闭。所有结果来自隔离SQLite，不是用户正常数据库的个人内容。

最终截图已逐张AI审读：[普通关闭确认](screenshots/capture-unsaved-confirmation-light.png)、[最大字号关闭确认](screenshots/capture-unsaved-confirmation-dark-largest.png)、[重启前部分识别](screenshots/draft-before-relaunch-unaccepted-speech.png)、[重启后识别仍待确认](screenshots/draft-restored-unaccepted-speech-dark-largest.png)。系统alert三个操作可辨认；大字号正文/转写需要纵向滚动，测试实际滚到确认按钮并操作，不声称所有内容同屏可见。原生TextEditor内部滚动可让首尾不同时显示，数据完整性另由精确字符串断言。机械设计检测Swift文件返回空发现，不能替代审图或VoiceOver操作。

## 构建与公开检查

首次Release优化编译和链接完成，GenerateDSYMFile因磁盘空间不足失败，原日志`/tmp/mingsi-draft-release-20261023.log`保留。清理的是可重新生成的旧Debug/Prompt DerivedData缓存，未删除原始测试bundle、日志、数据库、Keychain或个人导出。随后同一Release配置构建通过（CODE_SIGNING_ALLOWED=NO），日志`/tmp/mingsi-draft-release-recovered-20261023.log`。这是模拟器Release构建，不是手机签名安装包，也没有发布安装渠道。

本轮没有使用模型额度、没有读取或修改API Key。公开证据只有合成短句与测试元数据。新增本机草稿含用户文本，已在README与导出说明中提醒。

共享组件的校对绑定另以现有语音完整生命周期UI复验，**1通过、0失败、0跳过**，见[校对与追加摘要](ui-voice-edit-summary.json)，原bundle`/tmp/mingsi-draft-voice-edit-20261023.xcresult`。使用同一已构建Debug二进制test-without-building，没有改动生产代码或重复跑模型。

测试后固定模拟器已用无夹具参数启动正常App，首页已审图，正常数据库新增迁移身份存在。未执行清库或重置Keychain命令。手机只做连接/已安装App元数据检查，没有安装或启动手机App，也未读取手机内容。

全部暂存公开变更经Gitleaks扫描无发现，`git diff --check`通过；[检查摘要](hygiene.json)不包含密钥。正常Git同步，不生成公开安装包。
