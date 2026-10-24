# 输出预算实现记录

日期：2026-10-24。当前候选的工程默认值是 Chat 导师 8,192、Responses 导师 16,000。这些字段向服务声明生成上限，其中可能包含推理或其他不可见token；兼容网关是否接受并执行仍需实测，不能用来推断可见中文字数或费用上限。这两个默认值未经真实质量/成本批次验证。

已获取的官方 OpenAI 文档说明：Reasoning API 使用 `max_output_tokens`，达到上限时可能以 `incomplete` 结束并且可见正文尚未出现；官方 Chat 使用 `max_completion_tokens`，这些参数也限制不可见 token。依据页面：

- [Reasoning models](https://developers.openai.com/api/docs/guides/reasoning)
- [Counting tokens](https://developers.openai.com/api/docs/guides/token-counting)

当前请求组装规则：

| 配置 | 字段 | 观测表记录 |
| --- | --- | --- |
| Responses | `max_output_tokens` | 字段名和值 |
| `api.z.ai` / `open.bigmodel.cn` Chat | `max_tokens` | 字段名和值 |
| `api.openai.com` Chat | `max_completion_tokens` | 字段名和值 |
| 其他兼容网关 | 不猜字段 | 空字段，不能进入正式 G3 窗口 |

无效预算（0 或超过 100,000）在执行器中被拒绝，不会发起传输。预算字段和值随 attempt 身份写入 `mentor_http_attempts`，重复登记必须保持一致。当前服务转发配置的实际参数合同尚未核实，所以这项实现尚未开启正式 7 天/50 次观察。

预算列由v76迁移追加，不修改已应用的v75定义；已有中间候选列时保留。历史无预算证据保持为空。数据库登记拒绝任意字符串、跨协议字段、缺一半字段和值、无效整数。供应商拒绝预算时请求失败，不删字段后重试。
