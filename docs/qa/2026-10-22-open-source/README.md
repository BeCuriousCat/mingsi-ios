# 开源发布验收 · 2026-10-22

## 范围

本次检查确认仓库可以作为源码公开使用：许可证、第三方署名、构建说明、签名可移植性、密钥扫描和干净副本依赖解析均纳入验收。

## 结果

- GitHub 仓库 `BeCuriousCat/mingsi-ios` 为 PUBLIC，默认分支为 `main`，根目录 MIT 许可保留。
- 发布前本地 `main` 比 `origin/main` 多 72 个提交；本次提交会正常追加到 `main`，不改写历史。
- 从 Git 暂存内容导出的独立目录曾因 GRDB vendor manifest 引用了未分发的 `Tests` 目录而无法解析；已移除仅用于上游测试的 test target，并在第三方声明中记录该本地修改。
- 从独立 Git 暂存副本完成 Release 模拟器构建；同一副本的 Debug 针对性资产信任测试 1 项通过。Release 产品模块按预期未启用 `-enable-testing`，因此不把 `@testable` 测试目标误作为 Release 安全测试。
- 暂存内容与未推送历史均通过 Gitleaks 扫描，无发现；没有提交密钥、数据库、用户导出、签名配置或超过 10 MB 的文件。
- 明思仍是源码分发项目，不提供现成 iPhone 安装包、TestFlight 或 App Store 渠道。

## 可复核命令

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project MingSi.xcodeproj -scheme MingSi \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/PersistenceCoreTests/testDefaultAssetTrustOnlyEnablesPublicFixturesInDebug \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
