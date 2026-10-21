# iOS 26 / Swift 6 升级验证

日期：2026-10-10。基于用户确认的自用场景和 iOS 26 手机，提高系统最低版本并迁移 Swift 6 语言模式。

## 最终配置

| 项目 | 配置 |
| --- | --- |
| 最低系统 | iOS 26.0 |
| Swift 语言模式 | 6.0 |
| 本轮工具链 | Xcode 26.5 / Apple Swift 6.3.2 |
| 并发规则 | 启用 `NonisolatedNonsendingByDefault`，普通异步函数继承调用方隔离 |
| 默认 Actor | 保持原有声明，不启用全工程默认 MainActor |

`project.yml` 与 Xcode 工程的 Debug/Release 设置一致。Swift 6.0 是语言模式，编译器版本由 Xcode 提供。本轮未运行 XcodeGen。

## 迁移内容

- 数据库异步闭包避免捕获非 Sendable 的服务实例；数据导出在数据库队列内序列化，只返回 Data 与类型明确的计数。
- 共享日期格式改为值类型的 `Date.ISO8601FormatStyle`；新增旧毫秒日期和时区偏移记录兼容测试。
- 请求执行器与流接口显式保留调用方隔离，新增跨 suspension 的 MainActor 回归测试；现有超时和取消测试继续通过。
- UIKit 外观入口和相关测试明确 MainActor 隔离，测试网络桩共享状态由 `Synchronization.Mutex` 保护。
- App Intent 元数据改为不可变值；日历权限请求直接使用当前系统 API；移除已弃用的应用启动快捷项分支，保留 scene 冷启动入口。
- 初轮全量回归发现人生指南 shortlist 的提示词约束与固定评估用例不完整。补齐用户自主性、隐私和语言约束，统一校验最多 5 个唯一且有效的候选 ID；发布门槛未降低。

## 验证结果

| 验证 | 结果 |
| --- | --- |
| 全量单元测试 | 1299 项：1297 通过、2 跳过、0 失败 |
| 关键 UI 流程 | 6 项：6 通过、0 失败 |
| Release 真机目标构建 | 成功，`CODE_SIGNING_ALLOWED=NO` |
| Release 产物最低系统 | `MinimumOSVersion=26.0` |
| `git diff --check` | 通过 |

单测与 UI 使用 iPhone 17 Simulator / iOS 26.5（`9F93EE80-68DF-4922-8A73-B0590F5143D4`）。跳过的两项是需要显式启用并提供 API Key 的远端 GLM 验收测试。单测日志仍有一条测试 fixture 的 `UIWindow(frame:)` 弃用警告；最终 Release 日志无 warning/error。

UI 覆盖：五个 Tab 可达；闪念语音取消、重录、确认、追加与保存（浅色/深色）；导师交流键盘打开后的输入与退出；最大无障碍字号深色指南观察操作；完成回顾后的相关指南入口。UI 运行后只调整了 shortlist 提示词和评估用例，这些最终修改由全量单测及 Release 构建验证。

## 截图复核

实际查看了浅色/深色语音确认、导师键盘输入和最大无障碍字号指南截图。语音确认文字与操作没有遮挡；导师输入、麦克风和顶部退出操作在键盘打开时可达；最大字号长标题可以正常换行，后续操作由滚动到达。

代表截图：[深色语音确认](voice-review-dark.png)、[最大无障碍字号指南](guidance-largest-text-dark.png)。

## 本机验证产物

- 单测结果：`/tmp/mingsi-swift6-unit-tests-final.xcresult`
- 单测日志：`/tmp/mingsi-swift6-unit-tests-final.log`
- UI 结果：`/tmp/mingsi-swift6-ui-tests.xcresult`
- UI 日志：`/tmp/mingsi-swift6-ui-tests.log`
- UI 截图及 manifest：`/tmp/mingsi-swift6-ui-attachments/`
- Release 日志：`/tmp/mingsi-swift6-release.log`
- 未签名 App：`/tmp/mingsi-swift6-release/Build/Products/Release-iphoneos/MingSi.app`

这些临时结果路径仅用于本机排查，仓库保留代表截图和本记录。

## 验证边界与收益

Swift 6 的直接收益是编译期并发安全检查，以及此次修正的跨隔离数据传递；系统最低版本提高后，可直接采用 iOS 26 API，减少旧系统兼容分支。版本升级本身不保证所有问题消失，也不会自动改善自定义界面或语音识别质量。

本轮未在用户手机验证真实麦克风、Siri 或桌面快捷入口，也未生成新的已签名安装包。模拟器语音流程采用测试替身，不能据此认定真机识别质量已经通过验收。
