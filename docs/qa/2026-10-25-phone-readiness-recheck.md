# 真机交付条件只读复查 · 2026-10-25

对应G9/G10。**仍无当前签名iPhone候选包或新安装结果。** 本次没有构建/安装手机App、启动手机进程、读取手机私人数据、创建描述文件或修改Apple账户。

本机`xcrun devicectl list devices`的实际结果：一台iPhone16 Pro，paired，localNetwork，tunnel connected。只证明开发工具当前可以发现已配对设备，不证明设备已解锁、开发者模式/授权、当前安装代码或签名能力。

只读搜索两个常用描述文件目录：`~/Library/Developer/Xcode/UserData/Provisioning Profiles`存在且无`.mobileprovision`；`~/Library/MobileDevice/Provisioning Profiles`不存在。合计0份本地描述文件。没有据此断言Apple账户会话或所有其他目录的状态，也没有重复运行已知No Accounts的自动签名构建。

此前[模拟器新候选](2026-10-25-native-candidate/README.md)已匹配原App的实际签名证书、通过28项专项并保留数据；模拟器不需要真机开发描述文件，这些结果不能代替手机安装门槛。手机的旧App版本仍未知，没有把模拟器0aad77e标记归给手机。

下一步保持[真机安装步骤](../mingsi-phone-acceptance.md)：本人在Xcode确认账户可用并选择自己的Team后，先执行只构建与包内标记核对。确有相容Bundle ID、签名、有效描述文件和用户自行控制的数据备份后才覆盖更新；不卸载、重置Keychain或复制私人数据到仓库。账户登录、验证码和系统授权由本人完成。

本次设备JSON及诊断保留受限本机位置，公开仅上述设备类别/连接状态/文件数量，不公开设备ID、账户、证书个人信息或任何凭据。新模型调用0，未启动真人试用、三人安装或正式G3窗口。
