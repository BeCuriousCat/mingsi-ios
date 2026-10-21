# 第三方署名与许可

根目录 MIT 覆盖明思自己的代码，不替换第三方内容的原许可。再分发请保留本文件和对应许可文本。

## 高性价比人生指南

- 作者：GitHub 用户 **eternity4719** 及 [HowToLiveBetter 项目贡献者](https://github.com/eternity4719/HowToLiveBetter/graphs/contributors)。
- 来源：[eternity4719/HowToLiveBetter](https://github.com/eternity4719/HowToLiveBetter)。
- 离线参考库：`Sources/Resources/LifeGuidance/life-guidance-reference.json`，固定提交 [e73cb638b27f12a422546e5c09cadcac6fce03fe](https://github.com/eternity4719/HowToLiveBetter/tree/e73cb638b27f12a422546e5c09cadcac6fce03fe)，同步日期 2026-10-08。
- 精选建议及草稿：`Sources/Domain/LifeGuidanceModels.swift`、`Sources/Resources/LifeGuidance/life-guidance-m1.draft.json`，基于提交 [b4048d14960fec19c0367f8c0e6891f2b038c7ef](https://github.com/eternity4719/HowToLiveBetter/tree/b4048d14960fec19c0367f8c0e6891f2b038c7ef)。
- 许可：**CC BY 4.0**。见 [许可摘要](https://creativecommons.org/licenses/by/4.0/) 和 [完整法律文本](LICENSES/CC-BY-4.0.txt)。
- 修改：将 Markdown 整理为离线 JSON、章节、索引和检索字段；精选条目重写为小动作，补充适用边界和观察信号。保留原文、来源和同步版本。原作者未因此认可或代言明思。

资料中的研究引用和外部链接归各权利人；请查阅原始来源。本声明不对链接材料授予超出原有许可的权利。

## GRDB.swift

- 作者：Gwendal Roué 及 GRDB.swift 贡献者。
- 来源：[groue/GRDB.swift](https://github.com/groue/GRDB.swift)。
- 本地副本：`Vendor/GRDB.swift`。
- 许可：MIT，见 [原始许可](Vendor/GRDB.swift/LICENSE)。
- 本地修改：仅分发运行库；`Package.swift` 移除未随副本分发的上游 `GRDBTests` 测试目标，确保克隆后可以解析依赖。明思自身的测试保留在根目录 `Tests` 中。
