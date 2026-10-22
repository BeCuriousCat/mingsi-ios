# 手机交付前置检查与安装脚本真实性 · 2026-10-23

关联G9普通用户可安装、G10交付可复查；依据[当前手机验收](../../mingsi-phone-acceptance.md)。本轮不改App Swift运行行为，无需功能发布条目；没有当前签名包或手机安装通过结论，总Goal继续。

## 当前外部条件：实际检查

开发工具确认已有iPhone16Pro/iOS26.6.2连接，手机已安装`com.codex.mingsi`，版本号0.1.0(1)。该信息不能定位源码提交。只读取设备/App元数据，没有读取手机个人正文、导出或Keychain，也没有卸载/安装/清空App。

本机有开发证书，但两个标准描述文件目录不存在可用文件。随后实际构建当前候选：

1. 指定现有开发Team，真机Debug构建无允许更新签名：失败，Xcode报告找不到`com.codex.mingsi`的iOS App Development描述文件。日志`/tmp/mingsi-phone-signing-preflight-20261023.log`。
2. 使用同一Team，允许Xcode利用现有账户补齐签名再构建：失败，明确`No Accounts: Add a new account in Accounts settings`，且仍无描述文件。日志`/tmp/mingsi-phone-signing-account-20261023.log`。

没有通过注册新账户、绕过登录或接受协议解决；已请求本人解锁Mac并在Xcode Settings → Accounts登录自己的Apple账户。密码/验证码由本人操作，不发聊天。未找到账号不等于没有开发者订阅，也不能据此断定付费会员状态；当前只证明这台Xcode不能用现有配置完成签名。

## 原脚本的问题与修复

- `--skip-install`原来仍启动手机上旧App并报告试用就绪；现在只构建，明确不安装、不启动、不验证手机旧版本。
- `--launch-check-only`原来允许把当前checkout的commit关联到已装旧App；现在声明已装源码版本未知，不报告候选安装完成。
- 原先find第一个iphoneos产物可能选到其他configuration的旧构建；现在只认本次请求configuration的精确产物路径，缺失即失败。
- 原启动失败帮助文案一律提示信任证书；现在区分未定位的锁屏/连接/签名/身份信任等可能性，只在系统明确报告时建议检查信任，不自动判原因。
- 增加本地`--team`参数；不将个人Team写入工程，不默认启用签名更新或设备注册。失败后不安装、不启动、不删旧App。
- 默认证据文档改为当前P01–P12清单；安装和进程启动不代表手机手动验收、真实获益或14天观察通过。旧单日训练文档保留历史身份，避免过时流程要求覆盖当前自由结束原则。

## 验证

对未修改的`6919b46`脚本运行3项反例，全部失败，见[基线](script-baseline.json)。使用隔离命令stub，不触碰实际手机：只构建启动旧App、只启动错误绑定源码版本、配置产物混用三条原行为均不满足新断言。

新脚本9项契约测试通过；全体Python脚本测试34项通过、0失败：

```bash
python3 -m unittest discover -s Tests/Scripts -p 'test_*.py' -v
bash -n scripts/prepare_coach_quality_phone_trial.sh
```

原日志`/tmp/mingsi-phone-preparation-all-python-20261023.log`。覆盖构建/安装/启动失败停止、只构建不动手机、只启动不伪造代码版本、只安装仍待手动验收、配置产物不混用、Team校验、dry-run无构建安装启动。首轮新实现曾因macOS Bash3.2的空数组+nounset行为导致6项失败；改为非空构建参数数组后通过，未放宽断言。

真实连接设备的`--skip-install --dry-run --allow-dirty`另行执行，仅检查计划和设备元数据；不构建、不安装、不启动，输出标明launch check skipped，日志`/tmp/mingsi-phone-preparation-real-dry-run-20261023.log`。这不是签名或安装验收。

## 尚未完成与下一动作

本人Xcode账户/描述文件可用后，先生成签名候选，核对Bundle ID、签名身份及数据保留条件；已有App先导出私人记录，再按授权更新，遇到必须卸载时停止，不能用删除重装绕过数据迁移。实际手机P01–P12、3人安装、独立构建者、14天使用与4周复用均保持未完成。

本轮App运行代码未变化，不为脚本修改重跑Xcode模拟器或付费模型；真机的两次构建失败保留，不记为产品交付通过。没有生成公开安装渠道。

公开暂存变更Gitleaks扫描无发现，Bash语法与`git diff --check`通过，见[检查摘要](checks.json)。日志中签名身份、设备标识等本机信息不复制为公开原日志；公开只记录必要错误原因。
