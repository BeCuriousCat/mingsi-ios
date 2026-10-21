# 感受不覆盖请求，倾听无需训练

日期：2026-10-21。整体目标继续进行。本轮检查主导师是否把用户情绪误当作停止意愿，或为了训练形式忽略实际请求。

## 源文本问题与实现

2.14.0 将“疲惫、只想聊、不想总结”一并要求“不分析”，又要求“每轮一个而且只有一个可辨认的思考动作”；最终检查也重复强制动作。前者可能覆盖疲惫用户明确提出的建议请求，后者可能向倾听与收束强加分析。英文“不替用户决定”也未区分剥夺决定权与提供用户请求的建议。这里确认的是源文本冲突，不断言每次实际响应都会出错。

mentorRespond 2.15.0/schema 1 保留完整 2.14.0 回退，分别识别感受、当前请求和继续意愿。感受不需要证明，也不证明他人动机或人格缺陷。用户请求比较或建议时，简短承接后用用户明确标准给帮助；明确只想被倾听则不追加分析、问题、任务或训练评价。后来主动请求帮助时按新请求继续。仅在需要分析时聚焦一个思考动作；倾听、表达示范和收束无需训练，system 与 user 最终检查同步。

不新增本地情绪关键词路由、响应字段、数据库迁移、等待预算或自动重试。原三轮未知原因验收仍保留，共用保存/重开 harness；新增独立 opt-in 场景为“疲惫但要建议 → 明确只想被倾听 → 改变条件后再次比较”。每轮使用实际 MentorFeatureStore、SQLite 同会话保存及新 repository/store 重开，每个新表达只允许一次模型调用，任何失败立即停止后续调用。安全错误诊断沿用白名单。

## 验证范围

新增资产回归验证请求优先、倾听无需训练和历史回退；完整回归与实际外部效果结果在执行后记录。自动检查动作、问题数、来源、请求数和保存恢复；具体建议是否依据用户标准、倾听是否偷加分析、续轮是否更新条件需逐条 AI 审读正文。测试不是网络 UI、手机或长期能力提升证明。

上一轮 2.14.0 的约 114 秒传输失败仍保留在[原报告](../2026-10-21-mentor-uncertainty/README.md)，不重发相同请求以求通过。

## 构建与空间

首轮编译实际报告 PCM 写入 No space left on device，随后 CodeSign 与 build.db 也失败；[原日志](evidence/build-initial-failure.log)保留，不计为构建或测试通过。该次同时发生文档写入失败。确认构建已结束后仅清理依赖 JSON 未引用的可再生 PCM 缓存约 16 MB，[清单](evidence/obsolete-cache-cleanup.json)留存。下一轮使用同配置串行构建，关闭调试符号仅为本次命令参数，不改项目设置；保留个人数据库、Keychain、源码和验收记录。

串行轮写 MingSi.swiftmodule 仍报 No space left on device，[日志](evidence/build-serial-failure.log)保留。构建结束后移除可再生 ModuleCache，并对已结束 QA 的 352 个内容完全相同文件做 APFS clone、逐项核对 SHA256，保留路径、字节内容、权限和时间戳；[清单](evidence/qa-clone-deduplication.json)与[恢复记录](evidence/cache-recovery.json)保留，目录和证据未删除。可用空间约 337 MiB 后最终签名构建通过，[日志](evidence/build-final.log)留存。链接与 codesign 校验完成后仅清理可再生链接对象和 PCM，[清单](evidence/post-link-cache-cleanup.json)保留。

## 初次完整回归与旧断言修正

最终签名二进制首次完整回归 **1486 通过、1 失败、20 opt-in 跳过**，见[原摘要](evidence/unit-summary.json)、[关键测试](evidence/unit-initial-key-tests.json)、[跳过范围](evidence/unit-initial-skipped-scope.json)。失败为既有 LocalPromptProviderTests.testMentorPromptRoutesListeningAndThinkingMovesWithoutForcingAnalysis，仍断言“思考与引导的最低标准 / 每轮必须一个思考动作”，与本轮明确去掉强制训练的产品要求冲突；[原失败详情](evidence/unit-stale-assertion-failure.json)保留。将该断言更新为“服从当前请求、需要分析时只推进一个动作、倾听/表达示范/收束不附加训练”；来源、单问题、隐私及用户决定权检查保留。生产 Prompt 没有为迎合旧测试改回。

再次编译前，仅对已结束测试安装到模拟器的 App bundle 与已构建产物中内容完全相同的文件做 APFS 共享，逐一核对 SHA256、保留路径和元数据，见[清单](evidence/bundle-clone-deduplication.json)。未触碰 App 数据容器和 Keychain；这不是功能修改或验证证据。后续构建和验证使用同一最终生产源码，仅修正上述测试断言。

修正断言后的构建仍遇到磁盘瓶颈：先在 ld write 报 errno=28，见[日志](evidence/build-assertion-link-failure.log)；对同项目内完全相同的编译文件共享 clone 后，[下一轮](evidence/build-relink-testcompile-failure.log)完成 App 链接但测试编译未完成。之后清理可再生 Xcode 索引、符号与 SDK 缓存，并通过命令参数 COMPILER_INDEX_STORE_ENABLE=NO 关闭本次索引生成，见[清单](evidence/index-cache-cleanup.json)。项目设置未改。

最终所有源码和修正后的测试编译、链接完成，但测试 bundle CodeSign 报内部错误，见[原日志](evidence/build-final-codesign-failure.log)，此轮 xcodebuild 退出码仍为失败。确认所有编译/链接进程结束后移除生成对象与 PCM，保留最终二进制和 Swift module，[清单](evidence/post-test-link-cleanup.json)留存，可用空间恢复约 372 MiB。对同一最终测试 bundle 重新 ad-hoc 签名，再用构建生成的 App-Simulated.xcent 签名宿主 App，codesign --verify --deep --strict 通过；没有重编或改写源码来绕过失败。仅凭内部签名错误不能确定其根因。之后以 test-without-building 运行同一最终产物，避免重复占用编译空间。

上述手动恢复最初没有完整恢复可启动状态：test-without-building 在启动前失败，零测试实际执行，见[摘要](evidence/unit-final-summary.json)。检查发现根目录的 MingSi.debug.dylib 未签名，另外错误将 App-Simulated.xcent 作为真正的签名 entitlement 传入。补签 debug dylib 后仍启动被拒绝；移除额外签名 entitlement、回到 Xcode 模拟器的普通 ad-hoc 签名方式，重新安装后正常启动成功。App-Simulated.xcent 继续以构建生成的 __TEXT 模拟权限保留，不向实际签名附加权限。首次 codesign --verify --deep 不足以证明根目录 debug dylib 可加载；本次补做该 dylib 的独立验签，实际启动与后续回归分别验证。最终签名状态见[记录](evidence/final-products-signing.json)。该错误由本次恢复操作引入并已纠正，不归因于 Prompt 或供应商。

## 最终完整本地回归

同一最终编译产物修复签名后，test-without-building 完整单元 **1487 通过、0 失败、20 opt-in 跳过**，原结果 `/tmp/mingsi-mentor-request-unit-verified-20261021.xcresult`，见[摘要](evidence/unit-verified-summary.json)、[关键资产/历史回退测试](evidence/unit-verified-key-tests.json)、[跳过范围](evidence/unit-verified-skipped-scope.json)。旧断言失败与启动失败均保留，不用后续通过改写原结果。20 项跳过不计为真实外部效果通过；本轮新的三轮请求单独显式执行，结果另列。

## 实际三轮与正文审读

复核当前 CC Switch Codex provider 仍为已授权的伊莉丝，HTTPS Responses、配置模型别名 gpt-6.1-sol。显式执行一次新场景验收，在线 **1 通过、0 失败、0 跳过**，原结果 `/tmp/mingsi-mentor-request-live-20261021.xcresult`，见[摘要](evidence/live-summary.json)、[完整附件索引](evidence/live/manifest.json)及[逐条语义审读](evidence/live-semantic-review.json)。三条不同新输入共三次实际调用、无自动重试。每轮同一 SQLite 会话保存后用新 repository/store 重开，实际保留三条用户和三条助手记录；恢复本身不发请求。本次复核的是该 harness，不能推断所有生产入口均零额外调用。

1. 疲惫但要求建议：action=advise，约 2.788 秒，正文“我建议周日陪父母吃饭”，按明确的陪伴优先级、房租已备足与两周无其他相聚机会给建议，说明放弃收入的代价。没有只安慰或替用户增添优先级。
2. 明确只想倾诉：action=close，约 5.068 秒，正文“我在听。今天真的很累，这会儿不必解释，也不必把它整理成结论。”没有分析、问题、任务或能力评价；close 未阻止下一轮。
3. 主动重新比较：action=compare，约 18.687 秒，按用户提出的新条件，将建议更新为本周接兼职，说明房租缺口与相聚可改期的取舍。“按这些条件”保留了条件范围，没有将单例变成普遍原则。

三轮 question 均为 null，正文均已由 Codex AI 逐条审读。附件保留的是含 assistant 原文的适配后 envelope，不是原始 SSE；配置别名不证明上游身份或计费。没有旧版同输入 A/B，不声称旧版一定失败，也不将成功或等待时长归因于本轮 Prompt 修改。原 2.14.0 的不同请求传输失败仍未查明，不由本次成功覆盖。本轮是合成场景、实际模型及持久化验收，不是网络 UI、个人实际经历、真机或长期能力提升证明。

## 正常恢复与收尾

实际验收完成后，将同一最终签名 App 无 fixture、无测试启动参数正常安装启动到固定 iPhone 17 / iOS 26.5；未重置数据库或 Keychain。[进程记录](evidence/normal-app-restored.json)与[首页截图](evidence/normal-app-restored.png)保留，截图已打开审读：首页四个入口正常显示、深色主按钮可读，未显示离线缺配置提示。首页截图不能替代本轮网络正文或连接效果验收。

git diff --check、runner Python AST 与本轮源文本/证据的密钥字面量扫描通过，受保护的临时 xctestrun 剩余零，见[收尾记录](evidence/hygiene.json)。当前仍保留完整工作区改动与所有原失败，未发布安装包。整体目标继续进行；超长会话显式选片段后的指代连续性仍需设计与验证，不能擅自传回未选私密材料。
