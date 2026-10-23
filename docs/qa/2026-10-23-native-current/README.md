# 带源码标记的生产 App 原生复核 · 2026-10-23

关联G1/G2/G9/G10。候选`496c5266c8ca151df7b15f5b0430bd0f710e62b4`，固定iPhone17/iOS26.5模拟器。Mac解锁后用真实系统界面操作正常App，无UI测试启动参数、无模型/语音/provider夹具。不是手机验收、真人获益或四周复用证据。

## 产物与数据保护

初始已装App只有0.1.0(1)，没有源码标记，其操作不归到当前候选。随后从干净源码实际Debug构建，核对完整源码标记、clean、Bundle ID、严格签名验证；实际主可执行文件的`__TEXT,__entitlements`内HealthKit为true，Info未要求healthkit设备能力。见[构建与安装核对](build.json)。安装后再次核对标记和可执行文件SHA256，不能用电脑HEAD代替已装版本。

更新前在受限本机目录保留旧App、SQLite一致性快照及偏好；私人原文和Keychain不导出到仓库，不卸载/清空App，不改手机。安装更新保留同一模拟器App数据。此次只输入合成文字`Native capture check`，未提交为正式闪念、未请求麦克风或健康权限、未发送模型请求。保留合成草稿以便复查，没有替用户丢弃内容。

## 实际路径

| 操作 | 实际结果与截图 |
| --- | --- |
| 安装后从系统主屏长按明思→记录闪念 | 冷启动直接进入可编辑闪念。[输入页](screenshots/cold-shortcut.png) |
| 键盘输入合成短句 | 完整文字可见，保存动作可用，提示本机草稿已保留。[输入完成](screenshots/draft-entered.png) |
| 点击关闭→保留草稿并关闭 | 实际关闭保护提供丢弃、保留和继续编辑。[保护弹层](screenshots/keep-draft-dialog.png) |
| 转到设置→返回主屏→长按记录闪念 | 暖启动直接恢复同一合成正文。[暖启动恢复](screenshots/warm-shortcut-draft.png) |
| 在闪念页通过系统应用切换器关闭明思进程→普通点App图标启动 | 首页未误弹编辑器。[普通重启](screenshots/normal-relaunch-home.png)；重新点闪念后原文恢复，显示恢复提示。[进程结束后恢复](screenshots/relaunch-draft-restored.png) |
| 系统快捷指令→明思→打开今日闪念 | 临时签名版本首次执行失败，随后同代码证书重签版本执行成功，分别记录于下节 |
| 系统卡片长按→添加到主屏幕→添加 | 实际创建独立“打开今日闪念”图标。[系统菜单](screenshots/add-to-home-menu.png)、[主屏图标](screenshots/home-shortcut-icon.png) |
| 系统切换器关闭明思进程→单击新增主屏图标 | 冷启动直接到编辑器，原合成草稿保持完整。[桌面冷启动](screenshots/home-shortcut-cold-draft.png) |
| 保留草稿关闭→设置页→主屏→单击新增主屏图标 | 暖启动直接到编辑器，原合成正文保持完整。[桌面暖启动](screenshots/home-shortcut-warm-from-settings.png) |

本机字体、主题沿用现有设置，没有为取证切换系统偏好。截图中的长文本可滚动；不声称所有字号、页面或VoiceOver均通过。工具首轮中文paste没有进入正文，之后typeText的完整英文输入已实际看到；因此不把那次paste记作成功，也不凭工具问题认定用户手机无法粘贴。

## 系统 AppShortcut 的真实失败与签名差异

系统快捷指令能发现两个明思动作，见[系统卡片](screenshots/system-shortcuts-cards.png)，但临时签名版本点“打开今日闪念”报[无法运行App快捷指令](screenshots/system-shortcut-run-failed.png)。范围日志明确包含：

```text
Failed to generate bundleIdentity:
 -Not a platform binary, checking teamId...
 -Unable to get teamId from com.codex.mingsi
Attempted to fetch Auto Shortcuts, but couldn't find the AppShortcutsProvider
LNActionForAutoShortcutPhraseFetchError Code=1
```

实际包内`Metadata.appintents/extract.actionsdata`包含两个动作和正确提供者名称，Debug dylib也包含该类型；不能根据弹窗就改写业务代码或宣布AppIntent未实现。

使用本机已有有效个人开发证书，对同一App副本及其中dylib重签；不重新编译、不改业务源码、不导出私钥、不选择组织团队。确认签名Team与原模拟器嵌入application-identifier的Team一致，严格验证签名后覆盖更新同一模拟器App；核对已装文件哈希，再执行同一系统卡片成功，并恢复原合成草稿。见[签名对照](certificate-signature.json)和[成功界面](screenshots/system-shortcut-certificate-success.png)。

这证明该环境中同代码证书重签后的系统路径可用，不能推广为所有模拟器失败都只由签名导致。临时签名CI只验证其规定路径，不把它当成系统AppShortcut已执行的证明。手机描述文件和账号会话问题仍另见[实际复查](../2026-10-23-phone-delivery/account-recheck.json)。没有用模拟器成功推断手机签名可用。

## 后续包内配置核对

后续Mac再次锁屏，实际网络UI仍未执行。只读当前已装496c526 App包，核对自身PrivacyInfo.xcprivacy的UserDefaults CA92.1、SystemBootTime 35F9.1，日历FullAccess/健康/麦克风/语音识别用途说明存在、旧日历说明键不存在，且无healthkit设备限制。见[实际包内字段检查](package-permissions.json)。未请求系统权限或读取私人正文，也不将这项文件检查当作系统弹窗、健康读取或语音通过。

## 仍缺

手机P01–P12、真实系统中文语音/中断/拒绝、VoiceOver、Siri、操作按钮、真实网络SSE，以及普通用户安装与真实价值均未因此通过。桌面入口的实际添加方式另写入[操作指南](../../mingsi-capture-shortcuts.md)。全部公开截图只含合成文字或系统界面，由Codex AI审读；文件哈希见[截图索引](screenshots.json)。

同源码的远端Release/Debug、1531单元/24跳过/0失败、2条隔离UI、HealthKit实际产物检查及8张截图，独立记录于[完整CI复验](../2026-10-23-ci-timing/README.md)。两类证据不合并成真机、全App或真人价值验收。
