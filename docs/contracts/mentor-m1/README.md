# 明思 M1 接口契约

本目录落实 [系统设计第 7-9 节](../../mingsi-mentor-m1-system-design.md) 与 [PRD 第 4-5 节](../../mingsi-mentor-m1-prd.md) 的结构契约。三个文件采用 JSON Schema Draft 2020-12，`schema_version` 固定为 `1.0.0`，未知字段会被拒绝。它们是设计与结构检查交付，不代表应用已接入协议。

**本目录没有交付首发的 24 份教材。** `fixtures/lesson.template.json` 是草稿状态的英文结构夹具，哈希为明确的占位值，不能载入发布包。脚本仅在内存复制它来检验 24 条的数量约束；这些复制不是 24 份不同教材，也未经过编辑审核。

## 文件与字段

| 文件 | 顶层字段 | 用途 |
| --- | --- | --- |
| [lesson-pack.schema.json](lesson-pack.schema.json) | `schema_version`、`pack_id`、`version`、`lessons` | 内容包结构；恰好 24 个教材对象 |
| [turn.schema.json](turn.schema.json) | `schema_version`、`action`、`material_status`、`body`、`question`、`question_purpose`、`source_refs`、`lesson_ref`、`suggested_actions` | `mentorRespond` 输出 |
| [understanding.schema.json](understanding.schema.json) | `schema_version`、`text`、`source_refs` | `mentorDraftUnderstanding` 输出；只生成未确认草稿 |

可空的响应字段仍必须出现，空值用 JSON `null`。理解草稿没有 `confirmed`、通知、验证任务或成长写入字段；草稿确认是独立的本地用户命令。

### 教材

单份教材字段为 `id`、`version`、`editorial_order`、`title`、`theme`、`applicable_contexts`、`claim`、`example`、`boundary`、可选 `observation`、`source_type`、`citations`、`content_hash`、`review`。教材 ID 的结构是 `L` 加两位数字；内容版本允许 `1.0` 或 `1.0.0`，与协议版本分开。

主题映射：`observation`=观察、`evidence`=证据、`tradeoff`=取舍、`communication`=沟通、`iteration`=迭代、`attention`=注意力。`editorial_order` 在 1-24 内。上述字段为编辑内容，不用于推断用户职业或能力。

`source_type=teaching_example` 显示“教学示例”，`citations` 必须为空。`external_reference` 显示“外部引用”，至少包含一条 `{title, url}`，URL 结构限定为 HTTP(S)。出处是否可访问、是否支持正文、是否有使用授权仍须核实。

`review.status` 允许 `draft`、`approved`、`rejected`，后两者必须有 `reviewed_by` 和 RFC 3339 `reviewed_at`；`note` 可选。允许草稿通过结构校验是为支持内容制作流程，发布检查必须另行要求每份均为有效的 `approved`。填写审核人字符串并不证明审核真实发生。

哈希字段格式为 `sha256:` 加 64 位小写十六进制。内容包检查器应对以下内容对象按 RFC 8785 JCS 规范化后，以 UTF-8 字节计算 SHA-256：`id`、`version`、`title`、`theme`、`applicable_contexts`、`claim`、`example`、`boundary`、存在时的 `observation`、`source_type`、`citations`。不包含哈希自身、审核记录、包元数据或 `editorial_order`。同 ID 和版本的该内容对象不可变；本目录尚未实现哈希检查器。

Schema 的较大字符串上限是结构安全限额，不是编辑目标。PRD 的约 250-400 个中文字符、单一中心观点、具体例子和适用边界由编辑检查；不能用截断满足长度，也不能把标题占位视为完成。

### 导师回应

`action` 是 `clarify`、`explain`、`compare`、`advise`、`close` 之一；`material_status` 是 `missing`、`usable`、`not_needed` 之一。`question` 是一个字符串或 null，`question_purpose` 是 `material`、`reflection` 或 null；两字段必须同时为空或同时非空。`clarify` 必须带问题，`material_status=missing` 且问题非空时，目的必须为 `material`。

`lesson_ref` 为 null 或 `{id, version}`。选择的新教材必须在本轮候选中且版本一致，客户端读取该版本已审核全文并保存快照；不接受模型自行改写的教材全文。同一逻辑 ID 的旧版本不因 ID 相同就自动获准。

`suggested_actions` 仅允许不重复的 `reply`、`explain`、`another_lesson`、`draft_understanding`、`finish`。运行时与当前本地可用操作求交集，由客户端确定唯一主要操作，不执行模型建议里的副作用。

`source_refs` 使用有类型的稳定字符串：`item:<uuid>`、`capture:<uuid>`、`legacy-nudge:<uuid>`、`lesson:L01@1.0`、`understanding:<uuid>`。Schema 只检查形状和数组内重复；**返回集合必须是本轮实际输入来源集合的子集**，并与真实来源及其快照版本匹配。不能凭字符串前缀、合法 UUID 或数据库里存在这条记录，就认定它本轮已发送、可访问或有资格被引用。

### 理解草稿

理解输出 `source_refs` 至少一条，结构层直接拒绝教材来源。其余合法来源键也不自动合格：运行时只接受本轮实际发送、可定位到真实用户文字及其明确修正的来源。助手文本、教学按钮的意图、单纯点了“听讲”、仅阅读教材、未经确认的旧 AI 理解草稿，都不是“用户获得了收获”的证据。

用户未提交自己的表达时不能请求模型生成理解草稿。用户自己写一句使用本地 `user_note` 路径；模型输出只能成为 draft，确认后才建立不可原位覆盖的理解版本。草稿是否忠实于原话需要语义评估，非空正文及合法来源键不能证明其真实性。

## 结构检查之外

| 约束 | 后续检查方式；本目录不声称已验证 |
| --- | --- |
| 24 个唯一 ID、24 个唯一编辑序号、包含 L01/L02、六组各四条 | 内容包检查器检查字段级唯一性与分类分布；Schema 这里只保证条目数与单字段形状 |
| 内容哈希正确、相同 ID+version 不变、24 份均完成审核 | 哈希复算、版本清单与真实编辑审核；格式正确或 `approved` 字符串不等于完成 |
| 来源属于本轮输入且仍可访问 | 原请求快照、会话所有权、来源角色、版本及删除状态检查 |
| 用户意图与两轮补材料预算 | 对所有主动作中 `question_purpose=material` 的问题统一检查预算；首次实际呈现才递增，同条再次打开不重复计数；到 2 后禁止新补材料问题。只有用户主动开始新的探索段可重置，不由模型解锁 |
| 不以问题代替用户明确要求的讲解 | 按本轮 intent 动态检查；语义评估还需识别把补材料问题藏在正文或谎报 reflection 的情况 |
| 教材候选、已知道、不相关、14 天去重 | 注入 Clock/Calendar 与会话反馈状态检查，包含版本、时区、恢复与历史回看例外 |
| 正文只有一个主动作、最多一个问题且建议有边界 | 字段形状无法数清自然语言里的问题或判断建议是否越界；使用黄金案例与人工评估 |
| 请求预算、一次 HTTP 尝试、流式 600 秒无内容截止及持续内容续期、取消与迟到结果 | 服务与仓储集成测试；Schema 不验证网络行为、epoch、semantic_revision 或审计事务 |

回看首轮的具体入口不计入补材料预算。理解保存、会话删除、通知及成长副作用始终由明确用户命令和事务约束控制。无效响应不得呈现为成功、不得用本地假讲解替代；保存失败的重试复用已收到结果，不重新调用模型。

## 运行结构验证

需要 Node.js 18+、npm 及依赖下载网络。在仓库根执行：

```bash
bash docs/contracts/mentor-m1/validate.sh
```

脚本将固定版本的 Ajv 8.17.1 与 ajv-formats 3.0.1 安装到新建临时目录，使用严格模式编译三个 Schema，执行正反例后清理该目录。不会修改仓库的 package 元数据、安装仓库依赖或改动应用；npm 自身缓存可能更新。

[validate.mjs](validate.mjs) 基于 [fixtures](fixtures) 的结构正例生成变体，覆盖枚举、必填字段、额外字段、来源形状、来源重复、问句用途耦合、教材版本、教材引用、审核字段和数量边界。`SCHEMA-ONLY` 案例故意让需要动态或人工判断的无效业务情形通过结构校验，显示边界，不把这些结果记为业务约束已通过。

这些英语夹具只用于结构测试，不验证中文教学质量、自然语言中的真实问题数量、用户理解变化或产品价值。

2026-09-10 本地实际运行上述命令，退出码为 0：三个 Schema 均通过 Ajv 严格模式编译，8 个结构正例通过、32 个结构反例被拒绝、14 个 `SCHEMA-ONLY` 边界案例按预期通过结构检查。此结果不代表内容包检查器、运行时动态验证或应用行为已实现。
