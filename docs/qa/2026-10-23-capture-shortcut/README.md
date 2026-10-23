# 主屏闪念快捷入口 · 2026-10-23

关联G1/G2、手机验收P07。当前工作基于`a77515f`，本轮只修快捷入口与请求消费；不把模拟器操作当真人试用或手机验收。

## 实际发现

原实现注册了主屏长按“记录闪念”，并在应用级delegate处理快捷操作、在连接新场景时处理冷启动。固定iPhone17/iOS26.5上通过系统主屏菜单实际点击确认：冷启动可以打开输入；App已运行并停在设置页时，点击快捷菜单只是回到设置，没进入闪念。

基线XCTest先因用完整标题查找系统菜单失败；该按钮的实际无障碍标识为`com.codex.mingsi.open-today-capture`，标题包含副标题。原失败保留在[摘要](baseline-summary.json)与`/tmp/mingsi-shortcut-baseline-20261023.xcresult`。这条失败本身不证明产品暖启动故障。

随后用原生模拟器UI直接操作（CUA），启动隔离数据库、把App停在设置、退主屏、长按明思并执行“记录闪念”，实际仍停在[设置页](screenshots/warm-before-fix-stays-settings.png)。没有发送模型请求或输入凭据。暖启动缺少`UIWindowSceneDelegate.windowScene(_:performActionFor:completionHandler:)`是代码可定位的缺口。

## 修订

连接场景时配置`MingSiSceneDelegate`，暖启动通过它处理与冷启动相同的快捷标识；未知操作仍拒绝。Root切回今日、现有闪念页接收打开请求，正文沿用本机草稿。

闪念页挂载或已挂载时收到重复请求，会消费待处理标记；避免暖启动已完成却留标记，在以后普通启动时再次误开。测试startup分支与生产startup共用同一待处理投递函数；桥接单元测试使用隔离UserDefaults和NotificationCenter，不触发正常UI或改动用户标记。

## 验证记录

场景修订首次实际系统菜单UI **1通过、0失败**，见[首次修订摘要](scene-first-summary.json)。从隔离数据库的正文输入→保留草稿→设置tab→系统主屏→长按App→记录闪念→直接打开输入，完整字符串与原稿相等。[实际恢复截图](screenshots/warm-first-fixed-restored-draft.png)。原bundle`/tmp/mingsi-shortcut-scene-20261023.xcresult`。

系统主屏长按操作出现XCTest等待SpringBoard动画空闲60秒的工具警告；用例通过并不表示入口实际耗时145秒。报告不得把这段自动化等待当成App启动延迟或真实用户负担数据。

最终候选增加普通重启不误开验证及共用投递函数。最终同一构建联合验收 **1519通过、24显式跳过、0失败**（1543项：1517项单元通过、2条UI通过）。两条UI为实际主屏快捷操作/草稿/普通重启，以及离线教材启动与重启恢复。见[最终摘要](final-summary.json)，原bundle`/tmp/mingsi-shortcut-final-20261023.xcresult`。关闭并再次普通启动后没有误开输入页；两条UI均使用生产root与隔离文件库。

## 边界与后续

UI使用生产root、真实系统主屏菜单与隔离SQLite/Keychain命名空间；未用伪按钮代替系统快捷操作。未配置模型、无付费请求。首轮失败后CUA的打字/粘贴没有进入模拟器输入，未把它记为草稿保护成功；草稿字符串保护由XCTest实际输入并逐字断言。

本轮主路径覆盖主屏长按快捷操作，不能推断Siri/AppIntents、用户添加的快捷指令主屏图标、所有其他tab、已有任意弹窗或恢复失败页都通过；这些仍在P07范围内待补。真机系统权限、麦克风、VoiceOver、后台与至少4周复用仍未验收。

真机只检查连接、系统版本与本机签名条件：已连接iPhone16Pro/iOS26.6.2；本机有开发签名身份，但未找到可用描述文件。未请求Apple新注册设备或生成签名权限，未更新手机App。签名身份存在不等于已交付当前手机版本。

Release编译与链接完成，但首次GenerateDSYMFile因磁盘空间不足失败，原日志`/tmp/mingsi-shortcut-release-20261023.log`保留。清理未运行的Debug中间文件/索引/模块缓存，保留安装产物、原测试bundle、日志、数据库与Keychain，随后同一Release模拟器配置构建通过，日志`/tmp/mingsi-shortcut-release-recovered-20261023.log`。不是手机签名包或安装验证。

最终[暖启动恢复截图](screenshots/warm-final-restored-draft.png)已AI审读；正文保留、留白与控件可辨认。本轮未改变页面视觉结构。最终联合验收后的额外实际冷启动复核尚未执行：工具报告Mac锁屏，已请求解锁，没有绕过锁屏，也未将基线冷启动结果改写为最终构建通过。

本轮全部暂存公开变更经Gitleaks扫描无发现，`git diff --check`通过，见[检查摘要](hygiene.json)。公开截图只含合成数据或无Key的隔离设置页。无公开安装包/手机更新、无新付费模型请求；正常App界面恢复待Mac解锁后完成。

## 解锁后的后续复核

同日晚间已恢复电脑操作，并在固定模拟器安装带完整源码标记的后续候选496c526；原App、数据库快照和偏好只留在本机，不卸载、不清Keychain。实际生产App无测试夹具运行，主屏长按冷启动进入编辑器、从设置页暖启动恢复合成草稿、系统应用切换器结束进程后普通启动不误弹编辑器、重新打开仍恢复原文，均有新截图。系统AppShortcuts另发现临时签名导致提供者查找失败；同代码使用现有个人开发证书重签后，系统卡片已能执行。完整操作、原失败与限制见[原生复核](../2026-10-23-native-current/README.md)。这补充后续候选的模拟器证据，不追溯修改原候选的未执行结果；真机P07仍未通过。
