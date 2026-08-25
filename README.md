# 明思

明思是一个帮助用户把日常材料转成可验证判断的个人思维教练。

它将日常记录整理为可行动、可回顾的事项，并围绕证据、复盘和成长轨迹帮助用户检验自己的判断。

## 运行前提

- macOS 和 Xcode（包含 iOS 17.0 或更高版本的 SDK/模拟器）。
- 使用 Xcode 打开 `MingSi.xcodeproj`，选择 `MingSi` scheme 后运行或测试。
- 如需根据 `project.yml` 重新生成工程，需要先安装 XcodeGen。

## API Key 与隐私

明思采用 BYOK（Bring Your Own Key）方式。需要模型能力时，请由每位用户在 App 的 **Settings > BYOK** 中本地配置自己的 API Key；应用将其保存在设备的 iOS Keychain 中。

不要把 API Key 写入源代码、配置文件、测试数据、日志或 Git 提交。`.env.example` 可以作为不含真实凭据的配置模板，真实的 `.env` 文件会被忽略。

## 最新更新

### 2026-07-15

- Today 支持一天多事项，先在“今日概览”确认，再一次训练一件。
- 到期验证可完成或暂缓；成功后结算新增成长证据，不显示单次分数涨跌。
- History、Projects 和 Growth 可以回到具体事项与来源证据，项目结束需要填写真实结果复盘。
- 多 Provider 扩展已延后，当前开发目标以 vNext 证据闭环为准。

完整更新记录见 [发布说明](docs/releases/release-notes.md)。
