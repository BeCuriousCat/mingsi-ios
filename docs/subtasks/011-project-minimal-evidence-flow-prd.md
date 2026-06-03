# 011 Project Minimal Evidence Flow PRD

状态：已实现

目标：把 Project 从“只展示已有链接的看板”推进到 MVP 可用的长期议题证据闭环。

## 1. 背景

明思的 Project 不是公司项目管理，也不是普通标签。它是用户反复面对的一组目标、阻塞、判断和行动的抽象容器。

当前代码已有：

- `Project`、`ProjectLink`、`ProjectInsight` 等数据模型。
- SQLite Repository 和 migration。
- `ProjectsView` 可以按已有 `ProjectLink` 分组展示证据。
- `createProjectFromCurrentFocus()` 可以把当前主线任务保存为长期议题。
- History day detail 可以把 `Quest` 或 `PrincipleAsset` 手动保存为长期议题。
- Projects list 点击项目进入 Project Detail，展示 Overview、证据时间线和“证据不足”的思考变化占位。

后续缺口：

- `ProjectInsight` 数据层存在，但 UI 没有读取或展示。
- 项目重命名、归档、合并和 AI 自动候选仍未实现，属于后续切片。

## 2. MVP 范围

本切片只做最小证据闭环，不做 AI 候选、合并候选、自动项目推荐或复杂编辑。

必须实现：

1. Project Detail
   - 从 Projects list 点击项目进入详情。
   - 展示 Overview：名称、目标、成功标准、当前阻塞、开放问题。
   - 展示 Evidence Timeline：所有 `ProjectLink` 来源记录。
   - 每条证据可跳回 History day detail 并高亮 source id。
   - 如果没有 before/after 思考变化，明确展示“证据不足”，不能编造。

2. History -> Project 手动创建入口
   - 在 History day detail 中允许用户选择一条可靠证据创建长期议题。
   - 第一版证据来源可以限定为 `Quest` 和 `PrincipleAsset`。
   - 创建时生成 `Project` 和 `ProjectLink(isUserConfirmed: true)`。
   - 项目名称默认来自 quest/principle title，用户后续可在下一切片改名。

3. 证据规则
   - Project 必须至少有一条 `ProjectLink`。
   - `ProjectLink.sourceId` 不能为空。
   - 敏感内容不写入 Project 摘要，只保存本地 source id 和用户确认的抽象名称。
   - 没有 source id 的项目结论只能显示为空状态或草稿，不能作为事实展示。

## 3. 非目标

本切片不做：

- AI 自动生成项目候选。
- Project merge。
- Project rename/archive UI。
- ProjectInsight 自动生成。
- Schema 动态 UI。
- 项目百分比进度。

## 4. 用户动线

### 4.1 从 Projects 查看

```text
Projects Tab
-> ProjectEvidenceBoardRow
-> ProjectDetail
-> Evidence Timeline
-> History day detail
```

### 4.2 从 History 创建

```text
History Tab
-> Day Detail
-> Quest / Principle evidence
-> 保存为长期议题
-> Project created + ProjectLink created
-> Projects Tab 可见
```

## 5. UI 要求

设计语言：

- 仍使用 warm paper / ink / graphite。
- Project Detail 应像工作台，不像营销卡片。
- 不使用紫色、蓝紫渐变或大面积 AI 感装饰。
- 卡片不嵌套卡片。

Project Detail 首屏：

- 顶部：项目名、状态、最近更新日期。
- 下面三行紧凑信息：
  - 当前目标。
  - 当前阻塞。
  - 下一条可验证线索，第一版可从最近 main quest 派生。
- 下方进入 Evidence Timeline。

Evidence Timeline：

- 按时间倒序。
- 每条证据显示 source type、标题、日期、简短说明。
- 点击跳 History。
- 不展示无来源总结。

## 6. 数据与接口

优先复用现有结构：

- `Project`
- `ProjectLink`
- `HistoryRecord`
- `ProjectRepository`
- `ProjectLinkRepository`

建议新增 AppStore 方法：

```swift
func createProject(from source: ProjectEvidenceSource) async
func projectDetailItems(for projectId: UUID) -> ProjectDetailModel
```

第一版可以不引入复杂实体：

```swift
enum ProjectEvidenceSource {
    case quest(Quest, dailyEntryId: UUID)
    case principle(PrincipleAsset, dailyEntryId: UUID)
}
```

如果为了避免增加公开 enum，也可以先做两个方法：

```swift
func createProjectFromQuest(_ quest: Quest, dailyEntryId: UUID) async
func createProjectFromPrinciple(_ principle: PrincipleAsset, dailyEntryId: UUID) async
```

## 7. 测试要求

必须新增或扩展测试：

- 从 quest 创建项目会保存 `Project` 和 confirmed `ProjectLink`。
- 从 principle 创建项目会保存 `Project` 和 confirmed `ProjectLink`。
- 重复 sourceId 不会重复创建项目链接。
- Project detail model 只展示有 source id 的证据。
- Evidence Timeline 的 link 能定位到对应 HistoryRecord。

## 8. 验收标准

- 用户不需要等待 AI，也能把历史证据沉淀成长期议题。
- Projects 页面不再只是空状态或当前任务快捷入口。
- 每个 Project 都能说明“为什么存在”。
- 每条进展都能跳回历史证据。
- 没有足够证据时，Project Detail 明确显示证据不足，而不是编造思考变化。
