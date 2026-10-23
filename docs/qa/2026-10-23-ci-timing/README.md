# 远端异步测试等待与可控时钟 · 2026-10-23

关联G1/G3/G10。状态：**已保留实际失败，修正等待与测试时钟；完整候选复验仍待运行。**

[运行39854279265](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/39854279265)，候选b03b2ad：Release构建及源码标记通过；单元1555项中1529通过、24跳过、2项失败（17条断言），整体failure。HealthKit产物检查和原生UI因前置失败未执行，没有这两项的通过证据。终态及原始摘要见[失败记录](first-failed-run.json)。

失败一：`testUserCriteriaStayInSamePersistedConversationAfterReopening`在恢复等待处超过测试辅助函数的约2秒观察窗口；原辅助函数只XCTFail但不抛错，于是后续操作在未恢复状态继续，产生连锁断言。上一候选0bd24dd同测试0.430秒通过；这不能证明本次失败没有产品原因。改为最多10秒的测试观察窗口，失败带实际调用行并抛错，保留恢复内容、来源与不重复请求的原断言；如果仍未恢复，继续按实际状态诊断，不吞失败。

失败二：`testWatchdogTimeoutRecordsOneRequestDurationAndNoLateSuccess`使用30毫秒真实截止，却先等待SQLite准备与transport挂起；繁忙runner上可在transport开始前耗尽截止，计时仍为0，测试也拿不到request。生产允许准备期间超时，这个测试原本要验证的是“已有请求超时后只记录一次且迟到结果无效”。故改为可注入watchdog时钟：明确等待transport挂起后，先推进观测用uptime，再显式到期；原终态、1000ms、一次记录和无迟到成功断言全部保留。

同类20毫秒的`testStoreDeadlineTimesOutHeldRequestAndRejectsLateResponse`也改为同一可控时钟。生产默认仍使用ContinuousClock.now和原sleep-until，生产请求预算、SSE内容续期与取消规则未延长。已有真实时钟执行器与截止测试继续运行，不删除超时覆盖。

本机已对实际时钟结构和测试fixture提取编译（Swift6及NonisolatedNonsendingByDefault），执行挂起/显式推进通过；Swift语法与diff检查通过。它不代替明思完整单元或UI，本轮无真实模型调用、无手机安装。

后续候选须重跑完整Release/Debug标记、全部无付费单元、HealthKit可选能力产物检查及两条UI；原失败不覆盖，不能把之前的1531通过/2条UI结果移到b03b2ad或新候选。
