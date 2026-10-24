# 从本机导出核对网络观测

维护者离线工具`python3 scripts/summarize_mentor_network.py`只读一份App导出，不访问网络、Keychain或模型，不修改原文件。它帮助核对[请求观测设计](mingsi-network-observation-design.md)中的数字，**不批准发送、不启动正式窗口、不判定G3达标**。实际发送仍由原登记和授权约束。

先运行[公开合成示例](qa/2026-10-25-network-summary/README.md)，再按实际登记窗口处理自己的导出。私人导出包含正文、草稿和上下文，留在可信本地目录；工具输出不带原文、模型文本、UUID、URL或凭据。

```bash
mkdir -p work/trial
python3 scripts/summarize_mentor_network.py /path/to/private-export.json \
  --from '2026-10-25T00:00:00+08:00' \
  --until '2026-11-01T00:00:00+08:00' \
  --max-http 50 --data-kind real \
  --output work/trial/network-observations.json
```

日期是命令示例，不代表真实窗口已经开始。`--max-http`只能是1–50，默认50；它是操作者传入的登记上限，不是工具验证过的授权。`--data-kind real`也是操作者声明，不验证真人身份。`--output`只创建新的0600文件，已有文件拒绝覆盖；省略则仅输出JSON。单份输入最多128MiB，不合并多次导出快照。

## 分开核对三个数量

| 报告 | 口径与限制 |
| --- | --- |
| `application_requests` | `created_at`落在起点包含/终点不包含窗口内的请求，包括prepared、失败、取消、中断和committed。不能把committed直接计为完整可用 |
| `dispatch_registrations` | 登记派发时间落在窗口内的attempt。每次不同attempt均计入，包括同请求的额外派发；登记不证明网络已发生 |
| `native_http` | 系统原生networkLoad总和，缓存另列。重定向和多交易按原计数，不把一个attempt压成一次HTTP。窗口前创建的请求在窗口内派发，仍计入实际交易预算 |

相同ID且批准的观测元数据相同才去重；同ID冲突、外来session/request/epoch/revision、负数、小数、布尔假数值、原生分项合计矛盾等会用固定错误码拒绝，不输出输入片段或私人路径。整份导出中的观测关联都校验，不静默跳过坏行。其他分区正文忽略。

原生callback缺失、空交易数组、unknown分类或conflict均不能推定0/1。`known_network_lower_bound`只数已明确观察的networkLoad；`exact_total_if_fully_observed`与`remaining_if_fully_observed`在仍有未知原生计数或窗口请求没有attempt时为null。任何pending/conflict传输、未知计数、未知输出预算、缺配置指纹或同窗多配置都使`stop_new_dispatches_until_reconciled=true`；已超上限如实报告，不裁掉失败或重定向。

即使该标志为false，也只表示这份快照的已观测元数据没有上述阻碍；**不表示允许再发请求**。会话删除和观测写入失败可使记录消失，单一导出无法发现所有缺失；必须与原预登记、实际按钮操作和服务记录核对。此工具不是App里的自动配额闸门。

## 用量和时点

服务自报input/output/total/reasoning分别给已报告之和和报告数；没有报告为null，明确0保留0，不根据输入输出补总数。invalid/conflict/empty不计可用用量，固定分类仍显示。实际费用始终null，自报数字不能认证上游身份或账单。

四阶段时点按配置指纹、协议、实际输出预算字段和值、传输终态分组。每组同时给样本数、缺失/冲突/未绑定数、nearest-rank p50/p95，失败和取消不会并入成功或被删掉。没有正文的失败保留首段null，不拿终态时间替代。可见晚于正式保存是正常情况；已知时间先后矛盾的整组attempt时点不参与分布。配置未知的旧记录保留数量，延迟不合并成同一服务的分位数。

`cfg1_`指纹来自协议、规范化端点、请求模型名、温度、空闲期限和JSON格式开关的版本化SHA-256摘要；不输入API Key，不存原始地址/模型名，地址带用户信息、查询或片段时保持未知。它不能识别换Key/账户、验证上游身份，或证明构建、Prompt、内容相同。延迟只用于诊断；不得据此把多个候选拼成G3通过率。`complete_usable_responses`固定null，`goal_status`固定not_assessed；还需原登记、正式回应校验、保存、界面与人工验收证据。

## 当前支持范围

输入支持schema_version=1及v75–v79相关导出字段；旧行没有用量/时点/预算/配置指纹时保持未知。当前输出为report_schema_version=2：时点字段改为`timing_by_configuration_protocol_budget_and_outcome`，组内缺失字段改为`missing_conflicting_or_unbound`，增加`configuration_binding`。旧版报告保留原版本，不覆盖历史证据。[原合成示例](qa/2026-10-25-network-summary/README.md)的历史预期是v1，当前命令会产生v2且将全部旧配置标未知，不能要求两版JSON完全相同。新候选已修复数值布尔化；旧版本把INTEGER/REAL导成true/false的文件会拒绝，无法从旧布尔值还原原始数字，应更新并从原数据库重新导出。

结果依然含日期、粗粒度行为和计数，分享前由本人决定范围。该工具不新增外部遥测；当前[测试与示例](qa/2026-10-25-network-summary/README.md)全部是合成数据，不计真人试用或正式可靠性窗口。
