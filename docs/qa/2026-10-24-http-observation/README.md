# 导师实际HTTP观测接入 · 2026-10-24

关联G1/G3/G10。状态：**候选已实现，macOS隔离运行和本机真实HTTP探针通过；完整iOS构建/全量测试/产品绑定与导出集成测试待干净CI。** 不是正式7天/50请求窗口，也不是手机或供应商兼容性验收。[候选源码与结果](result.json)绑定全部相关哈希，不借用此前ec444881的全绿结论。

候选`3c211d0858b68c0649b229317c0b1cd9fadfb1c3`已提交[CI 40039311779](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/40039311779)，[登记回执](ci-submission.json)仅证明提交且观察时在运行，不代表终态或通过。冻结该候选至CI终态，不提前推送取消它。

该 CI 已于 2026-10-24 成功结束：Release/Debug 标记、42 项脚本、**1558 项单元通过 / 24 跳过 / 0 失败**、8 项隔离 UI 全通过及可选 HealthKit 检查通过。最终日志、23 张截图和摘要保存在 [ci-final](ci-final/result.json)。它绑定的是 `3c211d0`；后续输出预算改动尚未包含在这次结果中，必须由下一轮 CI 单独验证。

## 实现范围

生产`PromptTracingLLMClient`在验证导师请求归属后，从SQLite审计仓库取得独立观测存储，绑定不可变session/request/epoch/semanticRevision/trace。Direct客户端的Chat普通完成、Chat导师SSE和Responses完成路径在派发前登记新的attempt UUID，并将本次delegate传给实际URLSession调用。注册只证明计划派发；从登记到系统调用之间仍可能取消，不能把登记行自动当作一次HTTP。

`v75_mentor_http_attempts`保存协议、实际发送的输出预算字段和值、登记时间、传输终态、登记起点至传输返回的单调耗时，以及系统报告的network/cache/serverPush/unknown/redirect计数。`returned_data`仅表示客户端返回数据，不表示语义有效、正式保存、界面可见或用户获益。该耗时不用于首字指标。

指标写入不走当前轮次的正文审计。它只能更新与全部身份相符的既有attempt：取消、保存或切到下一轮后，迟到指标仍属于旧请求；删请求/会话时外键级联，回调不会重新插入。相同指标幂等，不相加；冲突保留原计数并标记conflict，精确计数返回未知。无回调、空指标或unknown分类均不能填成0/1。传输退出时取消本次SSE任务以释放接收；前台截止与后台记账独立，不能因此恢复回答。

本机导出增加`mentor_http_attempts`白名单分区，不含原文、提示词、响应正文、认证头、URL、地址、证书或原始错误；已记录实际发送的预算字段和值，但尚未记录服务自报用量。私有导出仍含关联UUID，不应直接当匿名公开报告。未给历史请求补造观测。未知兼容网关不会猜测字段，预算字段保留为空，不能进入正式G3窗口。

## 实际证据

- [本机14项测试](local-tests.txt)：9项实际存储测试覆盖身份拒绝、回调乱序/重复/冲突、多attempt、取消后旧归属、删除、迁移/重开、真实SQLite写入故障及缺指标未知。5项从产品测试提取的传输测试覆盖三个完成路径、登记失败不派发、HTTP400不回退，以及两种协议的实际URLSession截止取消后记账。使用实际组件、Direct客户端、执行器与本地GRDB；请求/Prompt模型是[最小夹具](harness-models.swift)，不是整个App。
- [原生结果](native-result.json)和[服务接收记录](native-server-counts.json)：真正本机HTTP服务收到4个请求，三个场景的系统networkLoad计数分别为 **1 / 2 / 1**；中间场景发生307重定向，第三场景确已解析出正文预览后才取消。数据由实际Direct客户端→delegate→SQLite保存后读回，传输终态分别returned_data/returned_data/cancelled。没有从URLProtocol推断原生计数。
- [探针源码](native-probe.swift)、[本机服务脚本](run-native-probe.py)、[提取的传输测试](transport-tests.swift)与[SwiftPM配置快照](Package.swift.snapshot)保留复查。该快照用`<REPOSITORY_ROOT>`替代原机器绝对路径；在独立临时包中按快照组织Sources/MingSi、Sources/NativeProbe、Tests/MingSiTests，并把实际源码和新存储测试链接进去即可复验。主产品仍以Xcode工程为准。
- 补充缺父表不记迁移成功的保护后，本机测试增至14项并重建原生探针，再以全新数据库复验上述三场景；[先前13项](local-tests-initial13.txt)及[早期原生结果](native-initial/native-result.json)保留，两个本机探针各4次HTTP接收分别计数，不混成一个批次。原探针首次编译仅因测试驱动遗漏GRDB异步调用的await而失败，[失败日志](native-first-build.txt)保留；修正探针后[编译通过](native-build.txt)。未据此改产品逻辑，也未抹去失败。

另已加入真实AppDatabase/PromptTracing/导出/级联删除集成测试，以及pre-vNext不提前登记v75的回归；这些不在上述macOS14项范围内，等待完整iOS CI。Xcode源文件与测试引用已显式增加，语法解析和工程plist检查通过，不能替代实际构建。

输出预算字段的编码规则和官方依据见 [output-budget.md](output-budget.md)。当前候选默认 Chat 8,192、Responses 16,000；未知兼容网关不猜字段。输出预算改动发生在 `3c211d0` CI 之后，不能引用该 CI 证明预算字段已经通过 iOS 构建。

输出预算候选首次 CI [40043067169](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/40043067169)保留为失败：Release 和脚本通过，单元 1559 通过/1失败/24跳过；失败是配置刷新重建策略时丢失 Responses 的16,000预算，回归用例实际观测到8,192。UI独立执行8项通过，但不把单元失败候选称为通过。修复已在后续工作树中加入，下一轮CI重新验证。

## 尚未完成

后台指标写入失败时，内存标志记录失败；持久化行若未成功更新仍是pending/未知。尚无独立的持久化写失败分类或导出前等待指标收齐的界面。进程中止缺指标也保持未知，不能宣称已实现所有观测诊断要求。

正式G3前仍需输出预算及授权服务合同、配置版本、自报用量、首次解析正文/界面可见/正式保存各自时点和有界批次对账。真实网络N02/N03未发送，正常模拟器新候选未安装，手机未更新；本轮模型调用0。所有真人使用、四周复用、盲评、普通安装和其他构建者门槛继续未完成。
