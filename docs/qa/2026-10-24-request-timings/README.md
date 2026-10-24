# 请求分阶段时点与真实数值导出 · 2026-10-24

对应G1/G3/G10。**50项macOS局部测试及真实localhost探针通过；App保存/界面回调、UIKit裁切及完整导出集成已增加测试，尚未执行完整iOS验证。** 不据此开启正式七天/50次请求窗口，不宣称真实供应商延迟或真人价值。[范围与源码哈希](result.json)。

## 本次实现

每个生产导师流复用同一`MentorStreamProgress`起点和单调时钟，最多记录四个首次事件。它们不是四个模型请求，不以写数据库完成的时刻替代事件时刻：

| 字段 | 观测含义 | 缺失含义 |
| --- | --- | --- |
| `first_readable_body_ms` | 顶层`body`/`text`首次解析出非空白正文；键名、嵌套内容、内部推理和仅空白不算 | 没观察到可读正文，不补为总耗时 |
| `first_visible_body_ms` | 原生正文marker与同一阅读可见区有正面积交集，或保存后的同一正文marker首次可见 | 没有可见证据；State赋值、onAppear、内容已保存均不代替它 |
| `request_transport_finished_ms` | 同一起点到实际传输操作返回/失败/取消 | 与旧的attempt派发起点`elapsed_ms`分开，不能混用分母或相减 |
| `response_saved_ms` | 正式回应事务成功返回；整理理解在保存及请求完成写入成功后记录 | 预览、解析成功、保存失败均不填；重试保存沿用原请求起点 |

v78在已有attempt表追加固定数字字段和`timing_state`。事件绑定不可变request/attempt；一个progress不能重绑另一attempt。绑定前发生的数字事件保留原时间；重复事件不重记。后台写入只更新已有行，删除不重建，迟到事件不改新草稿。不同值重报或已知时序矛盾标conflict，保留原始数字但不作为可用延迟数据。没有回调的历史行全部null；跨进程不恢复旧Instant，也不补造历史计时。

界面候选为实际正文增加独立marker，预览和已保存正文marker均携带确切request ID；既有整张回应的呈现回执和下一轮发送规则保留，不把整卡回执当正文可见证据。阅读采样排除导航/固定输入/键盘对应inset、窗口外区域、隐藏/透明祖先、原生祖先裁切；后台、离开和已知设置/来源/更正弹层等状态暂停采样。这里只证明几何可见，不推断人已阅读或理解。整理理解若快速完成且没有预览，最终编辑器尚未增加正文marker，first-visible保持未知。

## 发现并修正的导出缺陷

实际`SQLiteDataExportRepository.exportValue`先尝试`Bool.fromDatabaseValue`，会把所有SQLite整数和浮点转换为布尔；更早的String转换还会把可解码UTF-8 blob转换为文本。局部提取实际旧函数运行同一回归，得到[1项测试/5处断言失败](export-before-failure.txt)：12变成true、1.25变成true、blob不再是base64等。

修复按SQLite存储类型逐类导出：INTEGER保持数字、REAL保持小数、TEXT保持文本、BLOB保持base64、NULL保持null。数据库中布尔本来存作0/1，原始导出现在保留0/1，不再猜测字段语义。数据库和已有导出文件不修改；旧文件已经丢失的数值无法从true/false恢复，应从原数据库重新导出。schema_version仍为1，分区名和数据不迁移；依赖旧错误布尔表示的外部读者需按实际字段语义适配。

该修复适用于全部原始SQLite导出分区。已增加真正App导出路径的INTEGER/REAL/TEXT/BLOB/NULL回归（仅内存测试库追加夹具列）和HTTP时点数字回归，完整iOS执行仍待验。

## 已执行证据

- [最终50项局部测试](local-tests.txt)：传输11、存储22、执行器16，加1项从当前生产文件精确提取的[导出转换](export-value-tests.swift)。使用实际生产组件和GRDB，最小请求/Prompt模型及包组织沿用[用量专项](../2026-10-24-service-usage/README.md)；不能把提取函数等同整个App已构建。
- [原生探针](native-result.json)：四场景服务器[实际收到5次](native-server-counts.json)，系统计数1/2/1/1。成功与接收中取消分别保留首次解析和传输终态；输出上限失败没有正文，首段字段缺失。探针没有UI或业务回应保存，相关字段保持缺失。毫秒值是localhost夹具观测，不是模型性能基线。与之前两批探针独立，不合并为正式窗口。
- v78列名改为冻结字面清单，避免未来扩展事件枚举时隐式改写已应用迁移；随后重新通过50项局部测试及全新数据库的原生探针。此前同场景5次HTTP的[初始结果](native-initial/native-result.json)独立保留，不与最终批次合并。另有42项脚本测试通过。
- [首次编译失败](initial-compile-failure.txt)保留：增加默认时钟闭包改变了旧尾随闭包解析。现保留原构造入口，另用必传`clockNow`注入测试时钟；[初始48项](initial48-tests.txt)及最终结果均保留。未用删除旧调用替代兼容修复。
- [探针源码](native-probe.swift)、[服务脚本](run-native-probe.py)、[构建日志](native-build.txt)及实际传输测试提取保留。服务脚本接收独立SwiftPM包路径，拒绝覆盖已有探针数据库。新增付费模型请求0，个人数据库与手机均未修改。

## 仍待验收

本次Feature保存/快回复可见回调、原生UIView的inset/隐藏/裁切测试、完整App导出路径、SwiftUI页面与8条隔离UI必须由新候选完整CI验证。此前c120e8c的CI不含本次改动，结果不能挪用。

正常App安装、N02/N03和真机/VoiceOver仍待实际操作。当前Mac锁屏且本机空间不足，已准备CI保留通过门槛的模拟器App，但新打包步骤未执行。未知服务合同、配置/返回model标识、独立持久化写失败诊断、正式窗口有界对账仍未完成。后台时点写入未收齐或失败时可能保持null；不以成功保存回答掩盖缺指标。

真人14天、外部试用、四周复用、盲评和安装门槛不因这些工程证据通过，总Goal继续active。
