# 完整人生指南验证记录

日期：2026-10-09。设备：iPhone 17 Simulator，iOS 26.5，`9F93EE80-68DF-4922-8A73-B0590F5143D4`。

## 内容完整性

来源固定为 `eternity4719/HowToLiveBetter@e73cb638b27f12a422546e5c09cadcac6fce03fe`。导入器 `--check` 对比干净来源目录与打包 JSON：34 节、670 条、10 篇长文、13 个 README 章节、41 个术语。多行收益、来源和备注的独立样本验证通过。资源 SHA256：`1204a0dee94e110a9d56cf4c98a6e075f56b49e2c4c20e74172606b08bd2cd1f`。

完整 670 条原文都具备每日选择资格；逐条检查标题、正文、备注和预填来源。回顾第一步读取全部候选标题；第二步只读取模型选出的最多 5 条完整内容，未使用关键词兜底，也未截断目录。原文保持 draft 状态；未审核的改写建议与虚构候选 ID 被拒绝。

## 自动化结果

- 19 项指南单元测试通过：完整目录、旧数据解码、每日快照、重开与版本更新、14 天去重、当天隐藏、保存失败、旧收藏迁移、来源移除后的正文回看、数据导出、会话删除与迟到模型审计拒绝。
- 18 项 Prompt 文档测试通过。上述 37 项运行结果：`Test-MingSi-2026.10.09_00-35-49-+0800.xcresult`；最终指南断言复查：`Test-MingSi-2026.10.09_00-44-05-+0800.xcresult`。
- 6 个 UI 场景通过：收藏→原文→收藏列表→重启回看；闪念完整预填→保存→重启回看；原文每日卡→试过→观察→重启回看；长文表格→内部链接；回顾相关卡；精选建议预填导师输入框。
- UI 主轮：`Test-MingSi-2026.10.09_00-40-48-+0800.xcresult`。检查截图发现主按钮对比度不足，改为设计令牌 `onAccent`。测试启动参数没有实际改变字号，增加仅 Debug fixture 生效的 Dynamic Type 覆盖后重新运行默认浅色与真实 accessibility5 深色流程，2 项通过：`Test-MingSi-2026.10.09_00-51-15-+0800.xcresult`。
- 最终旧收藏迁移隔离复查：9 项流程单元测试与收藏重启 UI 测试通过，`Test-MingSi-2026.10.09_00-57-01-+0800.xcresult`。生产 AppStore 注入标准 UserDefaults 进行一次迁移，单元测试默认不迁移，UI fixture 使用独立 suite。

结果包目录：`/Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-gjyhvrbegnakhuawwtmljadsxwwc/Logs/Test/`。测试使用隔离 SQLite，收藏迁移使用隔离 UserDefaults，不访问用户数据库。

## 截图复核

[默认浅色详情](details-light.png)、[最大无障碍字号深色详情](details-accessibility-dark.png)、[闪念完整预填](capture-prefill.png)、[长文表格](long-read-table.png)。截图已实际查看：标题和正文正常换行，按钮对比度已修正，长表格转为每行带列标题的纵向阅读块，输入右下角调用统一麦克风组件。最大字号标题较长时允许连续滚动，完整操作仍可到达。

## 发布构建与验证范围

最终 Release 使用 `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO` 的 iOS Simulator 构建通过，确认 JSON 与源码 SHA256 一致、34 节 670 条入包、两份 draft JSON 工作副本排除。这是模拟器发布配置构建，不是已签名手机安装包。

回顾请求使用确定的模型替身验证两步协议、候选覆盖、原话和备注校验；本轮未声称验证远端模型的真实语义质量。Siri、桌面快捷方式和真实麦克风仍属于真机验收范围。
