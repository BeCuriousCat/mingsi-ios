# 真实试用观测汇总准备 · 2026-10-23

关联G2/G3/G4/G8的证据整理、G10维护可复现性。本轮是离线维护工具；没有改变App运行行为，不增加产品功能发布条目。总Goal继续进行，真实试用尚未据此启动。

## 产物与依据

[汇总脚本](../../../scripts/summarize_mentor_usage.py)读取单份本机App JSON导出，只汇总`mentor_usage_events`批准的粗粒度字段。[使用说明](../../mingsi-trial-summary.md)给出窗口、隐私、字段定义和不能推断的事实。

本轮核对生产`SQLiteDataExportRepository.exportPackage`的schema_version/sections格式、`MentorUsageEvent`及仓储白名单、FeatureStore入口归属与终态记录，沿用[现有统计口径](../../mingsi-mentor-m1-trial.md)。没有从个人数据库提取材料，也没有将真实用户标记为已经试用。

## 实际验证

新增16项测试通过；全体Python脚本测试25项通过、0失败，命令：

```bash
python3 -m unittest discover -s Tests/Scripts -p 'test_*.py' -v
```

原日志`/tmp/mingsi-trial-summary-python-20261023.log`。覆盖：失败/早退保留分母、路径切换不改首次归属、复看不算新内容、完全重复去重/冲突拒绝、同秒反馈不确定、早于窗口的尝试和孤立记录分别报告、未结束窗口、没有观测section不能报零使用、混版本不合并耗时、敏感正文与非法参数不回显、只读原文件、新输出0600并拒绝覆盖。

另外实际执行公开[合成导出](synthetic-export.json)的命令行，得到[合成报告](synthetic-summary.json)。其中3次尝试、1个失败请求、1个“有帮助”枚举；具体获益仍为null，整体Goal仍not_assessed。这个文件不是任何人的真实使用记录。

App Swift源文件未改动，本轮未重跑Xcode或付费模型。现有日志采用秒级时间，工具保留同秒反馈冲突，不伪造排序精度。日志不含完整HTTP请求数，也缺构建/Prompt/服务绑定，因此报告不能直接作G3候选验收。

## 尚未完成

- 对真实手机导出进行本人允许的本地汇总与手工核对。
- 本人14天自然使用、3–5位外部用户试用、至少4周独立复用及普通聊天盲评。
- 真机权限/麦克风/VoiceOver和安装分发。Mac仍未收到解锁确认，本轮未尝试绕过锁屏做原生界面复验。

这些缺口不因脚本测试通过关闭；没有收集到的数据继续保持未知。

公开变更的Gitleaks扫描无发现，`git diff --check`通过，见[检查摘要](checks.json)。本轮为维护工具与试用文档，不更新产品功能发布说明。
