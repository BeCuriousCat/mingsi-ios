# 服务自报用量接入 · 2026-10-24

对应G1/G3/G10。**已实现并通过44项macOS局部测试、42项脚本测试与本机真实HTTP探针；完整iOS、App导出集成与真实供应商验证尚未完成。** 此切片不是正式七天/50请求窗口，也不能证明实际费用或真人价值。[范围及源码哈希](result.json)。

## 改变了什么

- 审计导师路径在正文解析前提取Chat完整响应、Chat流usage-only事件、Responses完成/失败/incomplete事件的自报数字用量。输出上限仍是失败；失败用量不因没有正式回答而被遗漏。HTTP错误体若不是这几种已支持结构，仍不推断用量。
- 只存input/output/total/reasoning四个可选整数和来源枚举，不存原始usage对象、正文、model字符串、URL或凭据。总量和reasoning均不由其他字段补算；合法0与未知区分。任意字符串、布尔、小数、负数、溢出、不一致总量或reasoning大于输出会标invalid；空对象标empty。
- v77向独立attempt表追加`usage_state`和`usage_json`。缺失保持pending，received/empty/invalid/conflict分别保留。重复完全一致时幂等；冲突保留第一份报告、禁止当可用计费数据。不把多个报告相加，也不把多个attempt合成一次。
- 用量归属不可变的旧请求；取消后可记账，切换轮次不改新草稿，删除后不重建。观测写失败会使本次传输不能冒充正常完成，但独立持久化写失败诊断仍未实现。
- 仅官方OpenAI Chat导师流请求声明`stream_options.include_usage`；未知兼容网关不猜支持，收到用量则提取，没收到保持未知。参数被拒绝不删字段重发。返回服务是否实际遵守合同仍需真实验证。

## 证据

[44项局部测试](local-tests.txt)：传输11、存储17、执行器16。使用实际Direct客户端、请求执行器、指标与SQLite存储及本地GRDB；请求/Prompt模型是[最小夹具](harness-models.swift)。覆盖纯用量事件在stop后/DONE前、截断失败、两条Responses路径的正常与输出上限、自报缺字段、敏感字符串排除、重复/冲突、协议拒绝、旧库升级、写入故障、取消归属与文件重开。AppDatabase/PromptTracing/完整导出集成另有正式测试改动，未包含在此局部包。先前42项结果也保留，不将早期日志冒充最终用例集合。

[本机原生结果](native-result.json)：真正localhost服务与实际URLSession、delegate、SQLite组成四场景，服务器[实际收到5次](native-server-counts.json)：Chat成功1次、Responses307重定向2次、输出上限失败1次、收到可读预览后取消1次。系统networkLoad分别1/2/1/1；前三场景自报12输入/8输出/20总量/5推理正确读回，取消场景没有自报用量，保持pending/null。固定数字来自本机合成服务，不是实际模型账单。未公开私人数据库。

[服务脚本](run-native-probe.py)、[探针](native-probe.swift)、[传输测试提取](transport-tests.swift)、[包快照](Package.swift.snapshot)与构建日志保留。按快照组织独立SwiftPM包，使用实际源码、最小模型和测试，再将探针放进Sources/NativeProbe构建；将包绝对路径作为脚本第一个参数，脚本会创建全新SQLite文件，已有文件则拒绝覆盖。原始运行使用本机临时包；可移植脚本仅替换二进制路径获取方式。本轮新增付费模型请求0，先前HTTP探针结果保持独立。

## 正常App候选准备

本机剩余空间约1.9GiB，Mac锁屏阻止直接UI验收。CI新增在全部工程门槛成功后保存相同Debug模拟器App的步骤：包内源码/状态/Bundle ID/平台核对、测试计数、源码树与zip哈希一起保留7天，不包含模拟器数据容器、Keychain或模型凭据。内嵌Python语法已检查，实际打包尚未执行，不能称产物已可下载或安装。它只能用于模拟器，不是iPhone签名分发或G9通过。

上一候选c120e8c的[CI 40048831633](../2026-10-24-http-observation/ci-upgrade-final/result.json)已成功：1565单元/24跳过/0失败、8条隔离UI及Release/Debug等门槛通过；它不含本次用量、打包和后续时点/导出修复。现可提交后续候选单独验证，PR保持草稿。

## 仍缺什么

2026-10-25后续[本机完整iOS候选](../2026-10-25-native-candidate/README.md)已执行28项专项，包括实际App绑定导出、用量与时点；正常App已覆盖更新，现有Responses配置仍可读。真实供应商、N02/N03、完整远端CI终态与打包产物仍未通过；不能把局部专项升级为整个G3完成。

实际转发服务合同和配置标识、服务返回model的安全标识方式、首次解析正文/界面可见/正式保存的各自单调时点、持久化观测写失败诊断、有界窗口对账仍缺。用量缺失/invalid/conflict不能用估算补成零或费用；`returned_data`不能等于验证、保存和UI成功。

正常App的新候选、N02/N03、真机语音与VoiceOver待验；正式G3窗口、真人14天、四周复用、盲评和安装门槛继续未完成。
