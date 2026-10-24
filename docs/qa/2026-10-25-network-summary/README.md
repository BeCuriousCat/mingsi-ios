# 离线网络对账工具 · 2026-10-25

对应G3的有界批次对账前置条件。**19项专项与61项全部Python脚本测试通过；只验证离线汇总，不代表自动配额执行、真实App验收或正式窗口已开始。** [源码哈希与边界](result.json)。

后续配置指纹候选将报告升级到v2，见[当前格式](../../mingsi-network-summary.md)。本页v1源码哈希、测试和预期输出是原始历史证据，保持不变；使用当前脚本复现时旧输入没有指纹，全部保留为配置未知，不再生成同配置延迟分位数。不能要求当前v2输出与本页v1预期完全一致。

工具区分请求、派发、原生交易，保留重定向、额外attempt、失败、取消、缺失/冲突；不足以确认实际交易数时不计算剩余预算。输出不含正文、UUID或凭据。用量缺失不填0，各阶段耗时按协议/预算/结果分组且列缺失；费用与完整可用回应数不推算。使用说明见[网络观测汇总](../../mingsi-network-summary.md)。

## 执行证据

- [19项专项测试](focused-tests.txt)：多交易与缓存、unknown/空callback/无callback/冲突、缺attempt、重复与身份冲突、额外派发超限、旧窗口请求的新派发、缺失/明确0/冲突用量、失败无正文、时点矛盾、旧字段缺失、数值类型、隐私与私有新文件拒绝覆盖。
- [61项全部脚本测试](all-script-tests.txt)通过，不触发模型或改模拟器。
- 实际CLI读取[合成输入](synthetic-native-export.json)，输出与[预期汇总](synthetic-native-summary.json)完全一致。它含四个attempt、系统5次networkLoad、3份有效自报用量，以及1个未知输出预算；工具明确要求停止新派发直到核对。

这份输入的数字行来自先前[localhost原生探针](../2026-10-24-request-timings/README.md)最终SQLite，均为合成服务，没有私人正文。探针父请求图没有App的created_at列，适配时把请求创建时刻设为实际派发登记秒，仅用于满足导出形状，**不是独立观察到的App提交时间**。适配来源和窗口见[adapter](adapter.json)。不把该例标为real或正式七天样本，未新增任何HTTP或付费模型调用。

复现公开示例（先从adapter读取其明确窗口，避免将示例日期当实际试用）：

```bash
python3 - <<'PY'
import json, subprocess
from pathlib import Path
folder = Path('docs/qa/2026-10-25-network-summary')
window = json.loads((folder / 'adapter.json').read_text())
subprocess.run(['python3', 'scripts/summarize_mentor_network.py',
                str(folder / 'synthetic-native-export.json'),
                '--from', window['from'], '--until', window['until'],
                '--data-kind', 'synthetic'], check=True)
PY
```

## 完成边界

工具不访问私人导出，不联网、不读取Key、不发送请求。无需为这次维护工具单独修改App发布说明；它不是产品新入口。当前App候选83c5aa9的CI40114680744独立运行，不提前推送取消它，也不把其结果归给新工具。

正式G3仍缺服务配置/参数合同、完整App与正常网络验收、持久化写失败诊断，以及预登记和可复核的七天窗口。导出本身无法查明已删除或未成功写入的记录，因此这个工具不能独立成为完整HTTP账本或宣告总Goal完成。
