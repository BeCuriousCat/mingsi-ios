# 明思 MingSi

一个开源的 iOS 个人思维教练：记下一件事，换个角度理解，做一次小尝试，再用真实结果检验判断。

明思仍在持续开发，适合愿意自行构建、体验和反馈的用户。当前通过源码分发，尚无公开的 App Store / TestFlight 下载渠道。

## 主要功能

- **随手记录**：首页记录闪念，通过快捷指令打开输入页；共享麦克风控件将语音转成可编辑文字。
- **多轮交流**：围绕具体事件与导师交流，保存理解和历史；导师回应与整理理解支持 SSE 正文预览，中断时提供重新请求入口。
- **思考透镜**：10 种内置视角，包括证据、机会成本、可逆决策、他人视角和控制边界。
- **离线阅读**：24 篇探索教材；人生指南包含 34 节、670 条建议、10 篇长文，支持每日资料卡及回顾相关入口。
- **行动与回顾**：将判断转为可观察的尝试，记录结果和成长证据，支持本地保存和数据导出。

教材如实披露 AI 编写和编辑审核身份。资料与模型输出用于辅助思考，内置内容不代表已证明能提升个人能力。

## 运行前提

- macOS 和 Xcode 26 或更高版本（包含 iOS 26 的 SDK/模拟器）；真机需运行 iOS 26 或更高版本。
- 工程使用 Swift 6 语言模式，启用完整并发安全检查；具体 Swift 编译器版本由 Xcode 提供。
- 使用 Swift 6.2 的 `NonisolatedNonsendingByDefault`：普通异步函数继承调用方的隔离上下文，GRDB 的数据库队列继续负责读写；需要并行执行的耗时计算应显式声明 `@concurrent`。
- 使用 Xcode 打开 `MingSi.xcodeproj`，选择 `MingSi` scheme 后运行或测试。
- 如需根据 `project.yml` 重新生成工程，需要先安装 XcodeGen。

## 从源码运行

```bash
git clone https://github.com/BeCuriousCat/mingsi-ios.git
cd mingsi-ios
open MingSi.xcodeproj
```

1. 在 Xcode 选择 **MingSi** scheme 和一个 iOS 26+ 的 iPhone 模拟器，点击 Run。
2. 安装到自己的 iPhone 时，在 MingSi target 的 **Signing & Capabilities** 选择自己的 Team，并设置自己的唯一 Bundle Identifier。工程不绑定作者的签名团队。
3. 在线交流需在 App **设置 → API 配置** 选择接口类型，填写 API Key、Base URL 和模型名，保存后测试连接。
4. 语音输入需要麦克风与语音识别授权，模拟器与真机的识别环境可能不同。快捷指令可添加到主屏幕，或在支持的设备上绑定操作按钮。

```bash
# 查看本机可用模拟器，选择 iOS 26+ 的设备。
xcrun simctl list devices available

# 不需要个人签名的 Release 模拟器构建。
xcodebuild -project MingSi.xcodeproj -scheme MingSi \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/mingsi-build CODE_SIGNING_ALLOWED=NO build

# 将 iPhone 17 替换为本机的模拟器名称。
xcodebuild -project MingSi.xcodeproj -scheme MingSi \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/mingsi-tests -only-testing:MingSiTests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

普通单元测试不需要模型密钥；真实模型测试默认跳过，需主动配置并承担费用。部分验收脚本绑定维护者的固定模拟器，外部贡献者可用以上标准 Xcode 命令。读取本机 CC Switch 的脚本仅供明确授权的验收使用，运行前请理解其配置读取和付费请求行为。

## API Key 与隐私

明思采用 BYOK（Bring Your Own Key，自行提供密钥）。API Key 保存在设备 Keychain，用户记录保存在本地 SQLite。使用在线 AI 时，请求需要的材料与上下文会发给你配置的服务；请根据该服务的数据政策决定输入什么。

支持 Chat Completions 和 Responses 协议；自定义服务的兼容性取决于实际接口、模型和 SSE 事件格式。项目不附带作者的密钥、订阅或额度，普通聊天订阅不自动等于 API 额度。

数据导出不包含 API Key，但可能包含个人原话和模型交互，分享前请自行检查。系统语音识别是否联网取决于系统能力和语言，不能假定所有转写都在本机完成。

SSE 改善等待反馈，但上游断连、长时间无内容和系统后台限制仍会中断；未完成预览仅保存在当前进程，不提供断点续传。高级资产导入仍属实验功能，Release 拒绝公开测试身份，Debug 测试密钥不能作为正式发布者身份。

不要提交密钥、数据库、个人导出或含隐私的录屏。安全问题见 [SECURITY.md](SECURITY.md)。

## 验证与参与

最近一次流式验收：1,504 项单元测试通过、23 项需主动开启的测试跳过；2 条 UI 测试通过；另完成一次授权 Responses 请求与落库验证。这不覆盖所有供应商、真机后台连接或长期使用效果。见 [验收记录](docs/qa/2026-10-22-mentor-streaming/README.md)。

透镜另有 [GPT 目标评测](docs/qa/2026-10-22-lens-goals/README.md)：22 个合成场景、41 次分版本实际请求，保留语义失败、结构误拦与修复回放。最终相关本地回归 244 项通过；逐条 AI 审读用于检验单次帮助目标，不代表稳定成功率或长期能力提升。

欢迎通过 [Issues](https://github.com/BeCuriousCat/mingsi-ios/issues) 和 Pull Request 参与，开始前请阅读 [贡献指南](CONTRIBUTING.md)。[docs](docs/) 中的旧计划、历史验收和维护者本机路径不代表当前完整交付。

## 开源许可

明思代码采用 [MIT](LICENSE)，可使用、修改和再分发。人生指南来自 [HowToLiveBetter](https://github.com/eternity4719/HowToLiveBetter)，按 **CC BY 4.0** 提供；再分发需保留署名、来源、许可和修改说明。GRDB 的 MIT 许可随依赖保留。详见 [第三方署名与许可](THIRD_PARTY_NOTICES.md)。

## 最新更新

### 2026-10-22

- 导师回应和整理理解逐步显示正文，断流保留当前页预览，等待随有效内容续期。
- 完善闪念快捷入口、共享语音输入、10 种透镜和完整离线人生指南。
- 透镜更明确地区分双方立场、证据与取舍；合理的瓶颈比较不再被旧词汇检查拦截，直接求助和停止意愿优先。
- 补齐公开源码的运行说明、贡献指南和第三方许可，使用自己的签名与模型配置。

完整更新记录见 [发布说明](docs/releases/release-notes.md)。
