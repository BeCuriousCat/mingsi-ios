# 从本机导出汇总试用观测

这是维护者离线工具，用来减少整理[14天试用记录](mingsi-mentor-m1-trial.md)的工作。它不启动试用、不发模型请求、不读取Keychain、不把勾选反馈认定为获益，也不判定[长期Goal](mingsi-long-term-goal.md)完成。

## 如何运行

在明思设置中使用现有数据导出，把JSON留在自己的设备或可信的本地目录。导出含私人正文、草稿、模型上下文和自愿反馈；不需要把原文件发到聊天或提交仓库。

先用公开的合成示例查看格式：

```bash
python3 scripts/summarize_mentor_usage.py \
  docs/qa/2026-10-23-trial-summary/synthetic-export.json \
  --from 2026-10-01T00:00:00Z \
  --until 2026-10-15T00:00:00Z \
  --data-kind synthetic
```

整理真实记录时使用实际登记的窗口。下面的日期与文件名只是命令示例，不代表已经开始真实试用：

```bash
mkdir -p work/trial
python3 scripts/summarize_mentor_usage.py /path/to/private-export.json \
  --from '2026-10-23T00:00:00+08:00' \
  --until '2026-11-06T00:00:00+08:00' \
  --data-kind real \
  --output work/trial/observed-summary.json
```

不填`--output`时仅输出JSON；指定后只创建新文件，权限为0600，拒绝覆盖已有文件。`work/`被Git忽略。原导出只读，不修改。`--data-kind`默认unknown；real是操作者声明，不是工具验证过真人身份或使用行为。

窗口按首次`entry_started`时间选取，起点包含、终点不包含。后续事件也只观察到终点。窗口前开始的旧尝试、没有入口事件的孤立记录分别列出，不补进主分母。如果导出早于窗口结束，报告会标记`window.snapshot_before_window_end=true`；不能把中途快照当成完整14天。

## 如何读报告

| 字段 | 含义与使用边界 |
| --- | --- |
| observed_entry_attempts / by_initial_entry | 各首次入口的已观测尝试数；失败、早退、没内容或没反馈仍保留。日志写入失败及删除导致的缺失人数未知，不能称覆盖全部真实使用 |
| initial_material_presence | 初次点击时有无材料；不等于无需准备长材料，不能直接代替G2 |
| switched_entry_events | 单列实际切换的事件；不把回看切到听讲后的结果改归听讲初始入口 |
| presentations | 新呈现和复看分别计事件；阅读不自动算理解、获益或新推荐 |
| first_complete_content_latency_by_presentation | 首份完整内容呈现的耗时，按新内容/复看分开，含样本数；不是首字延迟或纯模型延迟 |
| request_terminal_events / request_latency_by_terminal_reason | 已观测请求终态和各终态耗时；失败、超时、取消、中断单列，不只展示成功请求。不是完整HTTP台账，不能用来宣布G3的48/50通过 |
| latest_feedback_enum_by_attempt | 每次尝试最后一条反馈枚举。missing表示没观测到；明确unknown仍为unknown。同一秒的冲突反馈标ambiguous_same_timestamp，不按UUID或文件顺序猜哪条最后 |
| understanding_confirmed_attempts | 发生确认理解操作的尝试数；不能据此认定获益 |
| concrete_benefit_cases | 始终为null：必须结合本人自愿说明或后续复用事实另行复核；不能把benefit_helped标签计成具体获益案例 |
| mixed_entry_content_schema_versions | 发现多个初始内容/协议版本时，保留计数和版本分布，停止输出合并耗时统计。未发现混用也不证明构建/Prompt/服务相同，因为这些字段不在事件中 |
| goal_status | 始终not_assessed；工具不替代G1–G10逐项验收 |

p50/p95采用nearest-rank（向上取样本排名），报告会注明方法；没有样本时为null，不写0毫秒。多个不同事件都声称是同次尝试的首份内容时，该尝试不进入首份耗时分布，并报告歧义数。相同event_id的完全相同记录去重；同ID观测元数据冲突、重复入口归属、非法属性、未知事件类型或缺失观测section会拒绝生成报告，不静默丢掉坏数据后报成功。

现有App观测时间按秒存储，反馈在同一秒内发生冲突确实可能无法排序。原日志不重写，工具如实标记不确定。

## 哪些结果仍需本人提供

自动汇总后，把计数与证据ID填入试用记录；私人描述仍留在本人控制的记录中。下面的事实不能从埋点推断：

- 当次到底理解、表达或判断清楚了什么，以及失败/放弃原因。
- 是否先整理过长材料、负担是否可接受、为什么没有打开。
- 回来是主动还是因催促、是否在另一真实情境独立复用。
- 盲评偏好、手机安装是否顺利，以及构建/Prompt/模型配置的真实版本。

同一会话的获益不能因多次恢复而重复计数；本工具只给尝试级枚举，具体获益以会话/案例的自愿证据另做去重。真实结果缺失继续记未知，不由AI补齐。

## 隐私与支持范围

仅支持schema_version=1的单份App JSON导出（最多128MiB），不合并多份快照。只将批准的粗粒度事件字段用于统计，忽略其他section的正文，不输出原文、反馈描述、音频、会话/尝试ID或输入文件路径。错误使用固定原因码，不回显JSON片段或未知属性值；参数错误也不回显传入的私密值。

汇总仍包含观察窗口、粗粒度行为与计数，分享前需要本人决定范围；它没有自动上传或遥测。当前验证只有合成数据与契约测试，未处理或标记真实用户试用数据。证据见[本轮记录](qa/2026-10-23-trial-summary/README.md)。
