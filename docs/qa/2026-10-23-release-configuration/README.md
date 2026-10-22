# 分发配置前置修正 · 2026-10-23

关联G1/G9/G10。状态：**配置已准备，本机静态检查通过；新候选完整构建、包内测试和真机权限尚未验收。** 没有上传、发布、联系测试者或修改个人签名。

## 来源核对与具体改动

2026-10-23实际读取Apple文档：

- [Required-reason API要求](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)：App和第三方SDK分别声明自己的用途，SDK清单不能代替App本身。
- [API类别与批准理由](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)：`CA92.1`用于App自身可访问的UserDefaults；`35F9.1`用于事件间耗时/计时，允许发送App内事件之间的耗时，不能发送原始启动时间或其他派生设备信息。
- [日历完全访问说明键](https://developer.apple.com/documentation/bundleresources/information-property-list/nscalendarsfullaccessusagedescription)：读取日历数据的当前API需要`NSCalendarsFullAccessUsageDescription`。

源码实际用法：`CaptureShortcutBridge`和偏好使用App自己的UserDefaults；`MentorFeatureStore`在内存中用systemUptime计时，只将事件间毫秒差写入本地观测。此前App没有独立PrivacyInfo，只有GRDB资源bundle中的空用途清单。新增App根资源`PrivacyInfo.xcprivacy`声明上述两个已核对理由；不额外声称在线数据没有被模型服务收集。

`SystemSideQuestContextProvider.requestCalendarAuthorization`调用`requestFullAccessToEvents`，此前工程仅有旧的`NSCalendarsUsageDescription`。改为当前所需说明键，明确主动授权、仅归约忙闲、不修改日历和不上传事件原文；手写工程Debug/Release与project.yml同步。没有在本机请求日历权限或读取用户日历。

## 已完成检查

- App隐私plist和Xcode工程plist解析通过；Swift测试文件语法解析通过；diff检查通过。
- 在临时目录用XcodeGen 2.45.4生成工程，检查手写和生成两份工程：MingSi资源阶段各只含一份App清单，Debug/Release均包含新日历说明键。
- 新增实际Host App包测试：从Bundle.main读取清单并核对已使用API的理由，再读取生成Info中的日历完全访问说明。尚未运行时不计通过；源文件存在不能替代真正打包。

没有重复运行与本次配置无关的本机完整构建。远端新候选必须经过实际Release构建和单元测试，随后真机确认授权、拒绝和继续使用路径。

## 安装与剩余边界

[普通用户分发准备](../../mingsi-public-delivery.md)补齐Xcode/TestFlight/App Store路径、Apple实际条件、三人安装空记录和升级限制；这些准备不是实际下载渠道或安装成功证据。

HealthKit entitlement尚未配置和真机验证；同时当前`healthAuthorizationStatus`在系统可用时返回authorized，尽管HealthKit不能公开读授权结果，现有“已允许”展示可能误导。日历write-only也不能作为读取授权。它们仍需单独修正能力与状态表达并实际验收，不能因本次清单或日历键修正而宣布系统集成完整可用。

商店隐私信息、真实签名归档、审核在线体验、权限弹窗和三人安装均未通过。App清单只覆盖已核对的required-reason API，不代表App Store审核、整个数据流审计或G1/G9/G10完成。
