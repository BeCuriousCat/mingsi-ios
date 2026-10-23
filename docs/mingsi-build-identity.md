# 核对手机上的明思版本

状态：后续候选496c526的Release/Debug实际包标记、1531项单元和2条原生UI已通过，最大辅助字号布局的8张截图已审读，见[本次证据](qa/2026-10-23-ci-timing/README.md)；此前0bd24dd的[历史证据](qa/2026-10-23-build-identity/README.md)保留，真机安装未验收。

在“设置 → 应用版本”查看版本号、构建号、源码短标记和是否含本地修改。长按可选择“复制构建信息”，得到完整源码标记。未注入有效标记时显示“来源未标记”，不会用当前电脑的Git提交冒充手机中的代码。

## 构建和安装

[手机准备脚本](../scripts/prepare_coach_quality_phone_trial.sh)会从本次工作目录读取完整Git提交和真实修改状态，传给Xcode；构建后核对App的Info.plist中两项标记与预期一致，以及Bundle ID与启动目标一致，才继续安装。标记缺失、过时或不匹配时保留旧App并停止，不改用别的构建。

`--skip-install`只构建和核对本地包；`--launch-check-only`仍只证明已有App可启动，不能绑定本次提交。`--allow-dirty`允许诊断构建，但标记会如实记录是否实际含本地修改；参数本身不等于源码已修改。签名与保留数据的步骤见[手机验收](mingsi-phone-acceptance.md)。

直接用Xcode GUI构建时，默认源码与状态都是unknown。需要登记可复查候选时，在自己的构建设置中提供`MINGSI_SOURCE_REVISION`和`MINGSI_SOURCE_STATE`；不把个人Team写入仓库。命令行模拟器示例：

```bash
MINGSI_BUILD_REVISION="$(git rev-parse HEAD)"
MINGSI_BUILD_TREE=clean
if [ -n "$(git status --porcelain)" ]; then MINGSI_BUILD_TREE=dirty; fi
xcodebuild -project MingSi.xcodeproj -scheme MingSi \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/mingsi-marked-build CODE_SIGNING_ALLOWED=NO \
  MINGSI_SOURCE_REVISION="$MINGSI_BUILD_REVISION" \
  MINGSI_SOURCE_STATE="$MINGSI_BUILD_TREE" build
```

公开CI使用干净checkout的GitHub SHA，并实际核对Release包内标记。开始编译后保持输入文件不变；此标记是构建时提供的信息，不是独立的密码学证明。

## 如何用于真实试用

安装完成后，在手机中复制构建信息，对照候选提交和本次验收记录，再开始[真实试用](mingsi-mentor-m1-trial.md)。换构建时记录日期和版本分界；有本地修改的诊断包单独记录，不当作同一干净候选。来源未标记时明确记未知，不能猜测已安装代码版本。

该信息只说明当前应用，不自动说明历史记录来自哪次构建；不会把旧会话重新归到最新版，不修改导出或既有观测数据。版本、Prompt、内容与服务配置仍需分别登记。TestFlight/App Store上传仍须使用可区分的构建号，源码标记不替代Apple的版本管理。

复制内容仅包含应用版本、源码标记和修改状态，不含Key、个人原文或手机标识；不会自动发送到任何地方。它帮助核对安装与反馈，不能证明真实获益、四周复用或Goal已经完成。
