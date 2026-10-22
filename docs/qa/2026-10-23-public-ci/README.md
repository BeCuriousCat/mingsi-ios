# 公开源码的干净环境验证 · 2026-10-23

关联G10开源可维护。新增[GitHub Actions工作流](../../../.github/workflows/verify.yml)：干净检出源码，不依赖维护者电脑的DerivedData、Keychain、私人配置或签名账户。首次远端运行[39831630202](https://github.com/BeCuriousCat/mingsi-ios/actions/runs/39831630202)已启动，候选提交`6dbdeefd3b37d59a65c197d31c86c59a806ccc81`。实际结果尚待登记；工作流文件存在不等于构建已通过。

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

38项Python测试通过、0失败；其中4项验证CI选择器只挑选既有可用iPhone、拒绝非法UUID和本机调用。Ruby YAML解析通过，`git diff --check`通过。见[本机检查](local-checks.json)。本轮没有重复占用本机磁盘做相同Xcode构建，干净检出与编译必须由远端真实结果证明。

本轮为工程交付检查，不改变App产品运行行为，无需新功能发布条目。没有其他真实构建者、3人手机安装、真人获益或4周复用记录；即使远端全绿，G10仍需至少1位其他构建者走通，G1–G9各自门槛不因此通过。

## 首次远端运行快照

运行39831630202的干净检出、工具链记录及脚本检查已成功；Release模拟器构建仍在进行，单元测试尚未开始，整体尚无通过/失败结论。见[远端状态快照](hosted-run.json)，最新状态以GitHub实际运行页为准。观察进程为`gh run watch 39831630202 --interval 30 --exit-status`，本机日志`/tmp/mingsi-public-ci-watch-39831630202.log`，不因观察时间变长重启或补跑。

本轮公开变更Gitleaks扫描无发现，YAML解析、38项Python脚本测试和diff检查通过。公开CI文件与脚本已推送；远端Xcode结果、另一真实构建者和手机安装仍未完成。
