# 原生HTTP计数：本机有界探针

日期：2026-10-24。关联G3。[结果](result.json)仅属于macOS命令行Foundation和本机合成HTTP服务；没有修改产品传输、访问模型、读取凭据或开展正式7天窗口。

实际编译Swift 6/NonisolatedNonsendingByDefault，使用与拟接入路径相同的 `URLSession.bytes(for:delegate:)` 和task metrics回调，串行执行成功、重定向、读到首段后显式取消三项。每项最多等待5秒指标回调；取消路由的服务端合成等待固定8秒。执行后已通过原会话Ctrl-C停止本机服务。

| 路由 | 本机服务收到的HTTP数 | 原生networkLoad数 | 原生指标总项数 | 观察 |
| --- | --- | --- | --- | --- |
| success | 1 | 1 | 1 | 正文与指标均收到 |
| redirect → success | 2 | 2 | 3 | redirectCount=1，另有1项localCache |
| cancel | 1 | 1 | 1 | 读到首段后显式取消，仍收到指标回调 |

原生网络分类合计4次，与[服务端实际请求序列](observed-server-requests.json)吻合；若直接使用指标数组长度则会误报5次。原始安全快照见 [observed-task-metrics.json](observed-task-metrics.json)。缓存行为可能随系统变化，不将“永远有一项缓存”写成产品规则。

这一结果证明该本机环境可以收集这些回调，并改变了实现选择：保留各分类，不能以数组总长度或应用派发数命名实际网络次数。它不能证明iOS、当前App、HTTPS订阅服务、转发服务背后的请求数、进程中止或所有取消时序均已验收。取消项显式调用 `bytes.task.cancel()`；不能拿此结果证明当前App所有返回路径均会显式取消。

## 复现

不需要Key。macOS安装Xcode后，在仓库根目录用两个终端运行；这里只产生本机合成HTTP。

终端一：

```sh
python3 -u docs/qa/2026-10-24-native-http-metrics/server.py --output /tmp/mingsi-http-probe-server-requests.json
```

记录打印的本机端口。终端二将 `实际端口` 替换为该数字：

```sh
xcrun swiftc -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault -parse-as-library docs/qa/2026-10-24-native-http-metrics/probe.swift -o /tmp/mingsi-http-probe
/tmp/mingsi-http-probe 实际端口
```

检查输出和服务端序列，再在终端一Ctrl-C停止服务。复测另存新结果，不覆盖本页已登记的结果。Swift探针与实际运行源相同；归档Python服务仅将固定私有临时输出路径改为必填 `--output`，该打包后的路径参数版本未重新运行，差异已记入结果。

下一步按[设计](../../mingsi-network-observation-design.md)接入请求身份、持久化及未知状态，并验收iOS实际路径；本页不把该后续工作记为完成。

## 原生转换组件的后续准备

后续已在本机准备 `Sources/Services/MentorHTTPMetrics.swift`，将系统原始指标转换为仅含数字的快照，不向后续层暴露task、URL或头部。已使用该实际源文件重新编译[组件探针](component-probe.swift)，在同一本机服务执行成功、重定向和显式取消，网络数1/2/1与服务端4次请求相符，见[组件实际快照](component-observed-task-metrics.json)及[服务端序列](component-observed-server-requests.json)。未知分类或空指标回调不能得到“精确0/1”；非负计数、分类总和及反序列化溢出边界另有5条实际XCTest通过，见[测试日志](component-tests.log)。

[组件结果与源码哈希](component-result.json)明确绑定本机未提交源文件。测试副本只移除App模块import，使用实际XCTest方法和defaultTestSuite执行；首次链接/运行缺Xcode库搜索路径的失败与修正留在本机，不能把仅编译称作测试通过。这里仍是macOS组件准备，尚未进入第六轮CI候选，没有接入App请求、数据库或导出；下一步补这些调用与iOS回归，不宣布G3正式能力完成。
