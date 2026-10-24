# 新候选本机完整构建、专项iOS测试与正常启动 · 2026-10-25

对应G1/G2/G3/G10。**本机Debug完整构建与测试包编译通过，28项真实iOS专项测试通过；正常App已覆盖更新，旧数据和配置保留。N02/N03仍未发送，正式窗口未开始。** 全量单元、8条隔离UI和Release由远端候选另验，不以这28项替代。[结构化范围与源码哈希](result.json)。

## 实际候选与构建

**2026-10-25签名结论更正**：后续[实际签名与嵌入权限复核](../2026-10-25-configuration-identity/signature-correction.json)表明0aad77e模拟器包为ad-hoc签名；Xcode日志实际使用`Sign to Run Locally`，传入原证书参数没有证明使用了该证书。原“使用同一证书”断言撤回。模拟器的application-identifier与HealthKit位于Mach-O，嵌入身份匹配已另行确认；没有显式Keychain分组，不把缺失值相等解释为分组已验证。下方实际28项测试、数据库与普通启动结果保留其原范围。

本机空间从此前约1.9GiB恢复到4.4GiB后，在独立DerivedData进行一次Debug构建，成功；随后无签名build-for-testing成功。再按旧回退包证书匹配本机身份并传入Xcode，build-for-testing成功，但模拟器实际使用ad-hoc签名；未选择其他团队或导出私钥。严格签名校验及嵌入application-identifier有证据；HealthKit可选能力存在。签名与Keychain实际配置读取分别验证，后者的普通启动证据只属于当时0aad77e。

实际包内源码为`0aad77eaf48515c8d4b3b471f24ec9c1010a6bec`、clean。它比远端受验头`83c5aa9`多了离线Python对账工具、Python测试和资料，**全部Swift、工程与相关iOS测试源码相同，但整棵Git树不同**。不把本机HEAD或远端受测合并提交冒充已安装版本。

Xcode26.5/Swift6.3.2、固定iPhone17/iOS26.5。成功标记与供应商已有Sendable警告保留在[Debug构建](build-key-lines.txt)、[无签名测试编译](build-for-testing-key-lines.txt)、[签名测试编译](signed-test-build-key-lines.txt)。这些编译未执行模型请求；本机未跑Release或全量单元。

早期签名准备中，以模拟器embedded application-identifier推断Team未选到身份；随后公开证书提取首次把可选前缀作为独立参数被工具拒绝。二者都发生在签名前，没有选用替代身份或修改已安装App。最终从旧App签名提取**公开证书**并匹配其SHA-1后才签名，未读取或导出私钥。私有诊断和旧包保留本机，不公开证书个人名称。

## 28项实际iOS执行

利用本次完整编译出的App和测试bundle，通过test-without-building在固定模拟器执行以下范围；宿主显式加`--mentor-ui-test`，读取内存夹具而非私人库或已配置模型。未启用BYOK导入、连接测试或真实模型验收。

| 范围 | 项数 | 证明范围 |
| --- | --- | --- |
| MentorHTTPObservationTests | 22 | v75/v76/v77升级、原生计数归属/缺失、用量与时点、重复冲突、删除后不复活、写入故障与重开 |
| DirectGLMClientTests两项 | 2 | Chat usage-only事件和两条Responses路径的正常/输出上限用量，全部使用模拟传输 |
| MentorFeatureStoreTests新时点项 | 1 | 预览/保存分开、快回复正文可见、保存失败不记成功、重试保存沿用原请求 |
| MentorReadingPositionTests新几何项 | 1 | 原生UIView的导航/输入inset、隐藏、透明和裁切不制造可见正文 |
| MentorPersistenceTests生产绑定导出项 | 1 | 真正AppDatabase/PromptTracing/导出保留数字用量/时点，并随会话删除 |
| PersistenceCoreTests新导出类型项 | 1 | 完整导出路径保留INTEGER/REAL/TEXT/BLOB/NULL，不用布尔或文本转换吞掉原值 |

[原始测试摘要](unit-summary.json)：**28通过/0失败/0跳过**；[执行日志](focused-tests.txt)保留选择器和终态。日志另有UIKit appearance-transition警告，不隐去，也不凭测试通过宣布所有视觉场景通过。

## 覆盖更新与正常启动

test-without-building按正常XCTest机制覆盖安装同Bundle ID的签名测试宿主，没有卸载/重置。运行前已保留0700目录下0600一致性SQLite快照，并核实旧回退App的90个文件与原安装包完全一致。专项结束后先只读对比数据库逻辑dump：私人库尚未改动；核对新安装可执行文件与本次构建一致。

随后通过CUA点击桌面明思，**不带测试参数普通启动**。首页有继续入口，打开后原N01合成原话与回应均可见，底部输入和发送可到达，见[恢复截图](screenshots/restored-before-n02.png)。历史旧草稿仍保留，没有回写清空旧版已发送文字。截图由Codex AI检查，只含此前登记的合成材料，不是真人获益或视觉批准。

设置页只读核对仍为Responses、原模型别名、原HTTPS服务和“API Key已配置”；没有点保存、粘贴并保存或测试连接，未重新导入凭据。配置截图保留受限本机目录，不在此公开服务地址或任何凭据。

普通启动后再次核对：SQLite integrity为ok；旧user/assistant的ID、归属、payload及请求ID/归属/state与原快照一致，v75–v78正常应用；`mentor_http_attempts`仍为0。见[运行核对](normal-runtime-verification.json)。正常恢复和设置查看没有偷偷发模型请求。

## N02/N03未完成

沿用[最多三次生成操作的原登记](../2026-10-23-network-ui/README.md)，N01不重跑。N02编辑框已能到达；选择旧草稿后，CUA中文paste/typeText没有让新条件进入输入框。尚未确定是模拟器粘贴板桥接、输入法还是App问题，不能仅凭工具无效归因产品。没有点击发送。

查看模拟器输入菜单时Mac再次锁屏，CUA明确无法继续；已请求手动解锁，不绕过锁屏。N03未开始。两项均保留未发送，新增实际模型调用0，也没有为了补测自动追加请求。后续应从现场继续，先解决输入再发送各项一次。

远端CI40114680744继续运行，步骤状态暂不一致，未提前推送取消；没有把本机28项称为远端全量通过。模拟器新包不代表手机签名分发、真机麦克风、VoiceOver、三人安装、14天获益或四周复用通过。总Goal继续active。

## 后续完整CI终态

同日已取得[CI40114680744最终证据](ci-final/result.json)：候选83c5aa9、受测合并提交3665153同树；Release/Debug标记、42项脚本、**1582单元通过/24跳过/0失败、8条隔离UI通过**及可选HealthKit检查全部通过。日志与实际artifact已核对，未把滞后步骤列表当成执行失败或重启理由。

新打包步骤实际成功，模拟器zip已下载到受限本机目录，SHA-256、manifest、包内源码/clean标记、Bundle ID、平台、测试数和树身份均已校验。公开仅保存manifest/验证结果，不把二进制提交仓库。**该CI包未安装**：正常模拟器仍是前述本机0aad77e包，Swift/工程与CI相同、整树不同。

23张CI截图保存；本轮逐张AI审读其中4张（浅色预览、深色最大字号预览、最大字号键盘续输、语音校对），没有将其余19张称为已审读。浅色预览手动滚动前正文可读，深色最大字号可见部分预览，键盘/语音校对控件可达；这不是实际麦克风、真实服务流或真人视觉批准。后续离线对账工具61项脚本结果不属于本CI的42项，分别报告。

这些新证据补齐本批工程门槛；N02/N03、普通App真实网络、手机、正式7天窗口和真人价值仍未通过。
