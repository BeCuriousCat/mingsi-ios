# 远端异步测试等待与可控时钟 · 2026-10-23

关联G1/G3/G10。状态：**原失败保留；修正候选496c526已完成完整远端复验，1531单元通过、24跳过、0失败，2条原生UI通过。**

[运行39854279265](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/39854279265)，候选b03b2ad：Release构建及源码标记通过；单元1555项中1529通过、24跳过、2项失败（17条断言），整体failure。HealthKit产物检查和原生UI因前置失败未执行，没有这两项的通过证据。终态及原始摘要见[失败记录](first-failed-run.json)。

失败一：`testUserCriteriaStayInSamePersistedConversationAfterReopening`在恢复等待处超过测试辅助函数的约2秒观察窗口；原辅助函数只XCTFail但不抛错，于是后续操作在未恢复状态继续，产生连锁断言。上一候选0bd24dd同测试0.430秒通过；这不能证明本次失败没有产品原因。改为最多10秒的测试观察窗口，失败带实际调用行并抛错，保留恢复内容、来源与不重复请求的原断言；如果仍未恢复，继续按实际状态诊断，不吞失败。

失败二：`testWatchdogTimeoutRecordsOneRequestDurationAndNoLateSuccess`使用30毫秒真实截止，却先等待SQLite准备与transport挂起；繁忙runner上可在transport开始前耗尽截止，计时仍为0，测试也拿不到request。生产允许准备期间超时，这个测试原本要验证的是“已有请求超时后只记录一次且迟到结果无效”。故改为可注入watchdog时钟：明确等待transport挂起后，先推进观测用uptime，再显式到期；原终态、1000ms、一次记录和无迟到成功断言全部保留。

同类20毫秒的`testStoreDeadlineTimesOutHeldRequestAndRejectsLateResponse`也改为同一可控时钟。生产默认仍使用ContinuousClock.now和原sleep-until，生产请求预算、SSE内容续期与取消规则未延长。已有真实时钟执行器与截止测试继续运行，不删除超时覆盖。

本机已对实际时钟结构和测试fixture提取编译（Swift6及NonisolatedNonsendingByDefault），执行挂起/显式推进通过；Swift语法与diff检查通过。它不代替明思完整单元或UI，本轮无真实模型调用、无手机安装。

后续候选须重跑完整Release/Debug标记、全部无付费单元、HealthKit可选能力产物检查及两条UI；原失败不覆盖，不能把之前的1531通过/2条UI结果移到b03b2ad或新候选。

## 修正候选的实际结果

[运行39953037902](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/39953037902)，完整源码`496c5266c8ca151df7b15f5b0430bd0f710e62b4`，终态success。42项Python脚本测试、干净检出的Release构建与包内标记、Debug全部1555项单元（1531通过、24显式跳过、0失败）、Debug实际Mach-O可选HealthKit能力检查、两条隔离原生UI均通过。两条UI没有跳过或失败。见[同一候选结果](verified-candidate/verification-run.json)。

已下载并逐张AI审读[8张原始截图及映射](verified-candidate/screenshots.json)：普通浅色和最大辅助字号深色，各覆盖版本、日历请求、健康操作及失败反馈。最大字号下健康操作纵向排列，版本标题与摘要纵向呈现；源码短标记仍可能换行，需要滚动阅读，未宣称同屏全显或全App无障碍通过。测试使用隔离provider，未请求真实系统权限、读取健康资料或调用模型。

本机另从同一干净源码构建并核对签名、包内标记及可执行文件HealthKit能力，再保留模拟器原数据更新；实际快捷输入、进程结束恢复及系统AppIntent的证据单列于[原生交互复核](../2026-10-23-native-current/README.md)。它与远端UI是不同环境的证据；手机、真实网络、真人获益和四周复用均仍缺。此次通过关闭本轮测试时序与候选产物确认的工程缺口，不关闭总Goal。
