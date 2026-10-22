# 公开源码的干净环境验证 · 2026-10-23

关联G10开源可维护。**修复候选7f45bc7已在干净远端完成Release构建与1526项单元通过（24跳过、0失败）；仍缺其他真实构建者和手机安装验证。**

新增[GitHub Actions工作流](../../../.github/workflows/verify.yml)：干净检出源码，不依赖维护者电脑的DerivedData、Keychain、私人配置或签名账户。首次远端运行[39831630202](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/39831630202)已结束，候选提交`6dbdeefd3b37d59a65c197d31c86c59a806ccc81`。Release构建通过，测试阶段在执行前因目标UUID大小写不匹配失败；整体失败，0项单元执行。

## 环境依据

使用认证gh读取公开仓库状态和Actions权限：仓库公开、Actions启用、默认workflow权限read。此前无工作流运行记录。

实际读取[GitHub macOS26 runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)，其列出Xcode26.5路径`/Applications/Xcode_26.5.app`及iOS26.5 SDK。工作流固定该路径，未使用滚动的latest Xcode。镜像未来删除该版本时应明确失败并评估升级，不悄悄换编译器。

checkout/upload-artifact通过认证gh解析到完整commit SHA后固定；contents只读，checkout不保留Git凭据，不读取仓库密钥，不上传App包、私人材料或原始录像。只保留紧凑单元测试摘要14天，原构建/测试日志由GitHub本身保存。

## 工作流范围

1. 记录实际源码提交、Xcode/Swift/Python版本。
2. 运行Python脚本契约测试、Bash语法、diff检查。
3. 从提交内Xcode工程与vendored GRDB构建Release模拟器App，禁用个人签名。
4. 只读枚举runner已有iOS26+ iPhone，选择其UUID，不创建/删除/重置设备；本机固定模拟器规则不变，选择脚本拒绝在非GitHub macOS环境运行。
5. 运行MingSiTests，临时ad-hoc模拟器签名，关闭测试并行；不选UI或opt-in付费模型测试。
6. 保存真实通过/失败/跳过计数；失败也保留日志，不删除失败后伪称整体通过。

main的相关源码/测试/脚本/工程变更及PR触发，纯文档变更不重复构建；可手动触发。每次最多45分钟，同一分支新提交取消旧运行。没有新增付费模型或手机权限。

## 本机验证与当前边界

修复后39项Python测试通过、0失败；其中5项验证CI选择器只挑选既有可用iPhone、拒绝非法UUID和本机调用。Ruby YAML解析通过，`git diff --check`通过。见[本机检查](local-checks.json)。本轮没有重复占用本机磁盘做相同Xcode构建，干净检出与编译必须由远端真实结果证明。

CI工具本身不改变App产品运行行为，无需新功能发布条目；随后由真实远端测试发现的点拨写入竞态属于产品修复，另记发布说明和专项证据。没有其他真实构建者、3人手机安装、真人获益或4周复用记录；即使远端全绿，G10仍需至少1位其他构建者走通，G1–G9各自门槛不因此通过。

## 首次远端运行：失败保留

运行39831630202在干净检出、工具链、38项脚本测试、Release模拟器构建及设备枚举阶段通过。单元测试命令退出70，尚未运行任何测试。实际artifact的totalTestCount为0、result为unknown；上传成功不代表测试通过。终态及原始计数见[首次远端记录](hosted-run.json)。

失败日志显示脚本输出`e839a11b-51b4-4ad3-acf4-a53b95b7c957`，而Xcode列出的可用目的地为`E839A11B-51B4-4AD3-ACF4-A53B95B7C957`。Python UUID默认转小写；修复为验证后输出规范大写，避免Xcode目的地匹配失败。使用该实际ID补回归：修改前2通过/3失败，修改后5通过；完整脚本39通过。只读与拒绝本机运行的边界保留。

修复后的新提交需要新的远端运行；不覆盖首次失败，不把本机脚本通过当作远端Xcode通过。本轮只修改CI工具与证据，不改变App运行行为，无需产品发布条目。

## UUID修复后的远端复验

提交`4060b80b99fd4d558215af7275ef3b6c78660f91`触发[运行39834309426](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/39834309426)。已结束：脚本39项与Release通过，设备UUID匹配成功；单元实际执行1548项，1523通过、24跳过、1项失败（2条断言）。整体失败，见[独立终态与原始摘要](uuid-fix-run.json)。首次失败继续保留于hosted-run.json。

失败项为`AppStoreStateMachineTests/testSingleNudge_sessionIsPersistedBeforeQuestionRequest`，数据库读回的问题及PromptRun ID为nil，内存里已生成。代码检查发现排队的旧草稿与直接保存的生成结果可能交错写入；修复与复验见[写入顺序专项](../2026-10-23-nudge-save-order/README.md)。没有跳过该测试或修改原断言。

## 点拨保存修复后的完整成功运行

[运行39837132850](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/39837132850)对提交`7f45bc7c831cdb9f5fa7f621e725bf7715546f30`整体success：脚本39通过、Release通过、单元1550项中1526通过/24显式跳过/0失败。原始计数和终态见[修复候选记录](../2026-10-23-nudge-save-order/verification-run.json)。前两次失败仍保留，未通过跳过失败项获取绿色结果。该证据绑定7f45bc7，之后新的App包配置修改需要另外复验；真实构建者、真机和真人价值仍未因此通过。
