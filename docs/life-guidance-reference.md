# 完整人生指南参考库

明思内置了 `eternity4719/HowToLiveBetter` 的离线参考内容。当前同步提交为 `e73cb638b27f12a422546e5c09cadcac6fce03fe`，包含 34 节、670 条建议、10 篇长文和 41 个术语。内容许可为 CC BY 4.0，应用内条目详情会显示来源、提交和许可信息。

## 内容与触达

- **完整参考库**：可从首页打开，按关键词、章节、证据、收益和低成本查阅。670 条全部可以作为每日随机和回顾相关资料卡入口，详情保留完整原文及备注，不把资料陈述当成针对个人的结论。
- **明思精选建议**：12 条经过独立改写、补充边界并审核的内容，继续使用完整发布校验。原条目保持 draft 状态，资料入口使用单独的资格规则。
- **实际使用**：收藏、试过和观察保存到 SQLite，保留完整版本并参与导出；可以将完整材料预填到闪念或导师输入框。长文标题、表格和内部链接在应用内阅读。

## 重新同步

使用认证 `gh` 获取来源仓库、检出固定提交后运行（`--source` 可指向任意本地目录）：

```bash
python3 scripts/generate_life_guidance_reference.py --source /tmp/howtolivebetter-source-20261008 --commit e73cb638b27f12a422546e5c09cadcac6fce03fe --retrieved-at 2026-10-08
python3 scripts/generate_life_guidance_reference.py --source /tmp/howtolivebetter-source-20261008 --check
xcodegen generate
```

脚本会检查来源 HEAD、材料未修改、重复 ID 和必填字段，并重新生成 JSON；`--check` 对照完整来源确认没有遗漏，失败时不覆写资源。多行字段按所属字段保留。同步后应检查：

1. 条目数量和章节数量是否符合 README。
2. 每条是否都有成本、摘要、收益、证据等级、来源和备注。
3. Debug 与 Release 包是否都包含 JSON，应用内是否能打开章节、检索条目和长文。
