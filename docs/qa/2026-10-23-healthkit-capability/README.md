# 可选健康连接的签名能力 · 2026-10-23

关联G1/G9/G10。状态：**已准备所需entitlement并验证轻量模拟器产物；明思完整候选、真机签名、系统授权和读取尚未验收。** 未请求本人健康权限、未读取数据、未修改Apple账户或描述文件。

## 依据与缺口

已存在的健康连接入口会调用HealthKit授权与查询，但target没有`CODE_SIGN_ENTITLEMENTS`或HealthKit entitlement。权限说明和错误提示不能补上应用能力本身。

2026-10-23实际读取Apple的[HealthKit设置](https://developer.apple.com/documentation/healthkit/setting-up-healthkit)与[HealthKit entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit)：使用前须启用该能力；该布尔entitlement允许App请求用户授权，不等于用户已同意读取。可选健康功能不应在`UIRequiredDeviceCapabilities`里要求healthkit，否则会限制其他设备安装。

## 配置改动

新增`Sources/App/MingSi.entitlements`，仅声明`com.apple.developer.healthkit=true`。手写工程与project.yml的Debug/Release都引用该文件，XcodeGen排除它作为普通资源复制。未添加临床记录、后台传输、App Group、写入类型或健康设备安装限制。原请求的toShare仍为空，读取类型仍是步数、活动和睡眠；不改变数据归约与模型输入范围。

源码中构建设置的DEVELOPMENT_TEAM已经为空，但发现PBXProject的MingSi TargetAttributes仍遗留个人团队值；现一并清空，避免公开项目默认带入个人签名选择。本机账户和证书未改动。其他构建者需使用支持该能力的有效团队、App ID和描述文件，不能因模拟器通过宣称手机签名可用。

## 实际验证与发现

1. 两份工程（手写及临时XcodeGen生成）的Debug/Release entitlement路径一致，团队设置与目标属性无个人值，文件不在资源复制阶段；plist与diff检查通过。
2. 真实Xcode26.5构建空main的隔离App，使用正式entitlement文件与ad-hoc模拟器签名。实际arm64可执行文件的`__TEXT,__entitlements`内HealthKit为true；Info没有healthkit设备要求。没有安装或运行夹具，不访问系统健康数据。
3. 另用实际Swift Debug目标、启用Debug dylib构建，确认主可执行文件仍含HealthKit entitlement；避免仅在简化Release夹具上成立。
4. 初次尝试读取codesign entitlement未能得到所需结果：新版工具默认输出抽象表示，而模拟器的ad-hoc签名本身又是空字典。检查真实编译日志后确认Xcode将模拟器entitlement嵌入Mach-O。改为读取实际可执行文件的arm64 section；不能以源文件或错误的签名检查宣称通过。
5. 初次XcodeGen目标属性检查也失败：本机2.45.4将尝试写入的嵌套SystemCapabilities属性输出为字符串。已撤去该非必要显示属性，以实际CODE_SIGN_ENTITLEMENTS输入和产物为依据；手写与重生成工程复核均通过。

轻量构建结果见[本机诊断](local-probe.json)。CI新增实际明思Debug可执行文件检查，解析相同Mach-O section并核对HealthKit为true、Info没有healthkit设备限制。它只证明模拟器构建产物的能力配置，不验证真实设备签名或读取；最终结果待候选运行登记。

## 真实验收仍缺

拥有者需先解决Xcode账户和有效签名条件，保留旧App数据后安装对应候选。由本人点击健康连接并选择允许/拒绝，检查无数据、部分允许、拒绝后仍可使用核心功能，以及系统设置变更后的表现；健康读取范围继续标为由系统管理。普通手机安装、VoiceOver和G4–G8真实价值均不因此通过。
