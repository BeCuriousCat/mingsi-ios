# Subtask 017 PRD: History Search and Evidence Filter

## Goal

让用户不用只按某一天回看历史，而是可以在历史中快速找到过去一周、一个月或更早的相关证据。

## Scope

MVP 只做本地派生搜索和证据类型过滤：

- 搜索关键词匹配每日原始输入、卡片、任务、原则、验证、透镜问题、项目链接、成长归因。
- 证据类型过滤支持全部、卡片、任务、验证、原则、项目、成长。
- 过滤结果不改变 `HistoryRecord`、Project、Growth 或数据库结构。
- 结果按现有 `historyRecords` 顺序展示，用户点选后仍进入原有单日详情。

## Non-Goals

- 不做全文索引。
- 不做 AI 语义搜索。
- 不做跨项目聚类。
- 不做保存搜索条件。
- 不改变日历组件。

## UX

- History 顶部在日期标题下方增加一个紧凑搜索栏。
- 搜索栏使用系统放大镜图标和单行输入，不做大面积卡片。
- 下方使用横向分段/胶囊筛选证据类型。
- 有筛选条件时显示匹配数量。
- 若当前选中日期不在筛选结果中，自动显示第一条匹配结果。
- 若无匹配结果，保留页面结构并显示空状态。

## Data / Architecture

- 新增本地派生类型：
  - `HistoryEvidenceFilter`
  - `HistorySearchQuery`
- `HistorySearchQuery` 只接受 `[HistoryRecord]`，返回匹配后的 `[HistoryRecord]`。
- 匹配逻辑放在 Domain，不放在 SwiftUI View 中，方便测试和后续替换为 FTS/语义搜索。
- 不新增 migration。

## Acceptance Tests

- 搜索卡片正文能返回对应记录。
- 搜索任务完成标准能返回对应记录。
- 选择项目过滤时，只返回含 ProjectLink 的记录。
- 选择成长过滤时，只返回含 MetricContribution 的记录。
- 搜索关键词与证据类型同时存在时取交集。
