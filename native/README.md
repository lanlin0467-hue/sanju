# 三句 SwiftUI 核心版本

独立原生工程：`Sanju.xcodeproj`，最低 iOS 17，iPhone 优先。现有 `ios/App` 是 Capacitor 工程，两者可以并存；新工程开发 Bundle ID 为 `com.sanju.native`。

这一版打通创作、生成结果和句库。可准备照片或文字与心情、生成冷峻/浪漫/青春三句、单句替换、复制、系统文字分享、收藏、查看旧句、恢复旧版本，以及搜索和删除本机记录。草稿、照片的压缩副本与句子版本会保存在应用私有目录。

## 先运行示例版本

用 Xcode 打开 `native/Sanju.xcodeproj`，评审界面时优先选择 **Sanju Preview** scheme，再选择 iPhone 模拟器运行。它使用开启编译优化的 Preview 配置，不附加调试器；需要断点调试时选择 **Sanju Demo**。Preview 配置默认使用示例服务，从手机桌面重新打开也保持示例模式；Debug 配置仍通过 `--demo` 启动参数选择示例服务。无需模型密钥、网页构建或 Capacitor 同步。

Preview 配置的桌面名称是「三句·原生预览」，Debug 是「三句·原生开发」，便于与旧版「三句」区分；正式 Release 名称仍为「三句」。两个开发配置使用同一个原生 Bundle ID，互相更新时会保留句库；示例记录仍与连接服务的记录分开保存。

示例模式用固定海边文案，界面明确显示「示例体验」，用于评审界面和交互。它不会根据输入推理，不调用收费模型，不能用来判断实际文案质量。示例句库与真实服务模式分别存储。Release 构建不接受示例与测试启动参数。

```bash
xcodebuild -project native/Sanju.xcodeproj -scheme 'Sanju Preview' \
  -configuration Preview -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath native/build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

真机运行时，在 App target 的 Signing & Capabilities 中选择自己的 Team 和可用 Bundle ID。首次开发只需系统框架和本地 Swift package，没有需要联网下载的第三方原生依赖。

### 装到自己的 iPhone

1. iPhone 需使用 iOS 17 或以上。用数据线连接 Mac，解锁手机，按提示信任这台电脑；在 Device Hub 中完成配对。
2. Xcode → Settings → Apple Accounts 登录自己的 Apple 账号。免费账号可以选择 Personal Team 做个人真机测试。
3. 在 iPhone「设置 → 隐私与安全性 → 开发者模式」中开启，按提示重启并确认。如果没有此选项，先在 Device Hub 发起配对。
4. 打开本目录的 `Sanju.xcodeproj`，选择 App target **Sanju** → Signing & Capabilities，勾选 Automatically manage signing，Team 选择自己的团队。如果 Bundle Identifier 被占用，改成自己唯一的英文标识，例如 `com.yourname.sanju`，其中 `yourname` 换成自己的标识。
5. Xcode 顶部选择 **Sanju Preview**，运行设备选择自己的 iPhone，按 ⌘R。首次等待设备准备、签名和安装完成；手机保持解锁。
6. 安装后可从手机桌面打开「三句·原生预览」，断开数据线仍可使用。此版本以固定示例文案测试输入、选图、拍照、收藏、分享和离线保存；真实 AI 服务另行接入。

免费 Personal Team 的描述文件有效期为 7 天，到期后通过 Xcode 重新构建安装。保持相同 Bundle ID 并覆盖安装可延续本机句库；不要先删除 App。以后使用 TestFlight 分发或提交 App Store 时再使用 Apple Developer Program 会员。

[Apple 真机运行说明](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)、[开启开发者模式](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)、[免费账号与有效期](https://developer.apple.com/help/account/basics/about-your-developer-account)

## 真实 AI 与邀请内测后端

真实接口仍使用 `GET/POST /api/v1/generations`。设置 `SANJU_BETA_ENABLED=1` 后启用 PostgreSQL 后端；未开放时仅允许显式开启的本机开发接口，production 不会降级到内存存储或固定文案。

正式路径包含邀请码兑换、钥匙串会话凭据、每位测试者每日 5 次创作、每份创作共享 3 次换句、24 小时换句期限、服务端原始素材摘要校验、跨实例请求去重、原请求恢复、失败退回创作额度、全站内测调用预算，以及反馈入口。同一邀请码的多个会话共享额度；撤销邀请码立即阻止所有会话。服务端忽略客户端伪造的旧句，以数据库版本为准。

数据库只存输入摘要、生成文字和任务状态，不存照片、画面描述和心情正文。每个新任务先在事务中预留最多两次模型调用，再调用模型；最多修正一次格式。终止的任务在两分钟租约过期后可核对并退回创作额度，不自动重复付费调用。数据库提交结果不确定时，App 保留原请求查询。每日总预算默认 40 次模型调用预留，覆盖创作和换句；服务失败也不会退回总预算，防止反复失败造成账单失控。该上限只覆盖新版内测接口，旧网页接口仍沿用原有限制；共用模型账号时需同时设置服务商账号限额。

模型沿用 OpenRouter 的 `qwen/qwen3.7-flash`，支持图片和 JSON 输出。默认禁止路由到用于训练的数据收集端点；模型服务商的保留规则仍以其政策为准。`SANJU_REQUIRE_ZDR=1` 可进一步限定零数据留存端点，但本轮核对的现有模型路由返回不支持此选项，不能直接启用。客户端在发送内容前重新征求 AI 数据处理同意，隐私页为 `/privacy`。

### 开通与部署

数据库使用 Neon PostgreSQL，可通过现有 Vercel 项目连接免费 `free_v3` 套餐。先在 `lan-lin` 团队确认 Neon Marketplace 条款，再创建数据库；如果已经有资源，请复用，避免再次创建。当前创建流程曾返回 `integration_terms_acceptance_required`，是否开通以 `vercel integration list` 的实际资源为准。

连接 production 环境后：

```bash
vercel env pull .env.beta.local --environment production
npm run beta:migrate
npm run beta:invite -- owner-test
npm run beta:status
```

邀请码只写入 `.local/invite-<测试者标识>.txt`，文件权限 600，不输出到命令日志、不提交 Git、不上传 Vercel。数据库只保存邀请码摘要。可通过管理脚本 `revoke <测试者标识>` 撤销资格，`purge <测试者标识>` 提前删除其服务端内容；清理内容不恢复额度。

生产环境需要以下服务端变量，参见根目录 `.env.example`：

| 变量 | 用途 |
| --- | --- |
| `DATABASE_URL` | 共享 PostgreSQL 连接，由集成提供 |
| `SANJU_BETA_ENABLED=1` | 数据库迁移成功后才开放真实内测接口 |
| `MODEL_API_KEY` 或 `SANJU_MODEL_API_KEY` | 仅服务端使用的模型凭据 |
| `SANJU_MODEL_PROVIDER=openrouter` | 当前使用 OpenRouter |
| `SANJU_MODEL_ID=qwen/qwen3.7-flash` | 图片与文字生成模型 |
| `SANJU_BETA_DAILY_MODEL_CALLS=40` | 每日调用预留上限 |
| `SANJU_REQUIRE_ZDR=0` | 当前模型不能要求 ZDR 路由；若换成支持的端点再设 1 |
| `CRON_SECRET` | 随机维护接口凭据，供每日数据清理任务使用 |

production 不得设置 `FAKE_MODEL=1`。部署后先检查 `/api/v1/health` 返回 `ready` 和 `live`，再用自己单独的邀请码做生成验证。仅构建成功不代表数据库或模型已接通。Vercel 的每日维护任务清理生成记录、过期会话与反馈，数据保留上限分别为 8 天和 31 天。

### 本机固定数据回归

现有单进程开发路径继续保留，只用于本机检查布局和 HTTP 协议：

```bash
SANJU_NATIVE_DEV_API=1 FAKE_MODEL=1 npm run dev -- --hostname 127.0.0.1 --port 3001
node_modules/.bin/vite-node --config vitest.config.ts scripts/beta-test-server.ts
```

第二条命令在 `127.0.0.1:3002` 运行独立的 PostgreSQL 引擎 HTTP 测试夹具，覆盖邀请码和认证流程，不调用模型。Xcode 的 **Sanju** scheme 支持 Debug 参数 `--api-base-url http://127.0.0.1:3001`；本机接口默认不要求邀请码。测试认证时使用端口 3002，并加 `--require-invitation`。这些启动覆盖不会进入 Release。

`beta-model-smoke.ts` 是显式运行的真实模型检查，使用本项目图标和非私人测试文字。它会调用收费模型，记录只保存到忽略的 `.local/model-smoke.json`；不会自动在构建或测试中执行。可用 `node --use-env-proxy --env-file=.env.local node_modules/vite-node/vite-node.mjs --config vitest.config.ts scripts/beta-model-smoke.ts` 手动验证；网络不需要代理时可省略 `--use-env-proxy`。

## 后续修改界面的位置

创作页已采用原创海底水彩背景、宋体标题、米白便笺和珊瑚色生成按钮。背景与页面调色板集中在 `Sanju/CreationVisuals.swift`；素材和生成提示词见 [CREATION-ART.md](CREATION-ART.md)。背景是静态资源，按压效果尊重「减弱动态效果」，没有持续粒子动画。

点击选图区直接进入系统相册，拍照为独立入口；所选照片完整显示，可更换、移除。读取过程中可取消，新选择或移除会使旧读取结果失效；失败不会覆盖已有照片。画面与心情均可单独清空，输入时显示字数，键盘提供「填写心情」和「完成」，焦点变化时滚动到输入位置。原有草稿保存、邀请码、同意说明和生成流程继续沿用。

中文衬线字体随 App 打包，离线可用；在结果页与句库改版时扩展为基本汉字、拉丁文字及常用标点的阅读字库，约 10.1 MB。心情标签在正常字号下三列排列，辅助字号调整为两列或一列，避免选中标记挤压文字。创作页 4 项相关 UI 用例已分别通过：生成/换句/收藏/重启、相册选择/移除/取消、自定义心情/草稿恢复/清空校验、最大辅助字号输入。报告为 `native/build/WatercolorCreationFlow.xcresult`（两项通过，首次输入用例因两个「完成」按钮定位歧义失败）、`WatercolorInputFlow.xcresult`（添加明确标识后输入用例通过）和 `WatercolorLargeTextFinal.xcresult`。相机、真实 HEIC 与真机键盘体验仍需实际 iPhone 验收。

结果页以冷峻、浪漫、青春的淡纸色卡片呈现三句，复制有即时状态，换句提供等待状态，旧版本页显示当前句子与收藏信息。句库以浅纸色、衬线句子预览、心情和日期显示记录，提供全部/收藏筛选、搜索及空状态。收藏详情可复制、分享及进入本次三句；搜索命中历史文字时，预览会标明旧句。视觉组件集中在 `Sanju/PoetryVisuals.swift`，数据保存与额度逻辑继续复用 SanjuCore。

结果页与句库的本轮 UI 回归已通过：`native/build/PoetryReadingFinal.xcresult` 检查生成、复制、收藏、换句、重启、搜索和详情；`PoetryHistoryFinal.xcresult` 检查独立旧句页的关闭、恢复与返回；`PoetryReadingLargeText.xcresult` 检查最大辅助字号下的结果页与收藏详情。实际截图保存为 `deliverables/sanju-watercolor-result.png`、`sanju-watercolor-library.png`、`sanju-watercolor-favorite.png`。

| 文件 | 修改内容 |
| --- | --- |
| `Sanju/Theme.swift` 和 `Assets.xcassets/AccentColor.colorset` | 全局颜色、卡片、圆角、主按钮 |
| `Sanju/CreationVisuals.swift`、`Sanju/PoetryVisuals.swift` | 海色与纸色、文风色、阅读字体、水彩背景和共享卡片 |
| `Sanju/CreationView.swift` | 选图、描述、心情标签、键盘与生成入口 |
| `Sanju/ResultView.swift` | 三张句子卡片、操作排列、旧版本交互 |
| `Sanju/LibraryView.swift` | 历史、收藏、搜索和删除 |
| `Sanju/SanjuApp.swift` | 标签导航与结果页路由 |
| `Sanju/BetaAccessView.swift`、`SessionVault.swift` | 邀请码、反馈表单与安全会话保存 |
| `Config/LocalOverrides.xcconfig` | 公开 API 地址和 Bundle ID；本机签名覆盖放在忽略的 `Signing.local.xcconfig` |
| `Sanju/Previews.swift` | 三个页面的 Xcode Canvas 固定预览 |
| `SanjuCore/Sources/SanjuCore` | 模型、生成服务、请求恢复与本机存储 |

普通的颜色、字体、卡片和布局调整集中在界面层，可以继续迭代。更改数据字段时需要同步考虑已经保存的句库格式；单纯改界面无需改变已有记录。

新增或移除 App 的 Swift 文件后运行 `python3 native/scripts/generate-project.py` 更新工程引用。一般修改现有文件不需要重新生成工程。Xcode 三个 Preview 使用内存示例，不会改动设备上的句库。

## 验证命令

```bash
swift test --package-path native/SanjuCore --scratch-path native/build/core
npm test
npm run lint
npx tsc --noEmit
```

在上述本机测试接口运行时，可以运行模拟器端到端测试：

新增相册回归需要模拟器相册至少有一张测试图。可以先运行 `xcrun simctl addmedia <模拟器 UDID> native/Sanju/Assets.xcassets/CreationOcean.imageset/creation-ocean.png` 加入本项目的原创图片。测试只选择图片，不会删除系统相册内容。

```bash
xcodebuild -project native/Sanju.xcodeproj -scheme 'Sanju Demo' \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath native/build/DerivedData \
  -collect-test-diagnostics never -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES test
```

新增核心测试检查读写不在主线程、慢速磁盘期间继续输入并收藏不会覆盖彼此、合并草稿不触发句库观察者、重复点击只发起一次生成，以及生成期间的新草稿会保留。

UI 测试使用独立的随机句库目录，不清空正常示例/正式模式的记录。它验证本机 HTTP 生成与换句、收藏旧句、重启恢复，以及邀请码加入后钥匙串会话与收藏都能跨重启保留。单元测试覆盖失败不扣额、结果未知时禁止重复创作、磁盘写入失败、删除不恢复额度和本机文件损坏保护。

本轮验证记录：原生核心单元测试 16 项通过，Node/PostgreSQL 接口及既有回归测试 34 项通过，ESLint 和 TypeScript 检查通过；Debug 模拟器和未签名 iPhone Release 构建通过。三条 UI 测试用例已在 iPhone 18 Pro / iOS 27 模拟器执行通过。真实模型已使用项目自有图标完成三种文风和单句替换的技术验证，输出通过字数与去重校验；照片场景的文案质量仍需人工验收。

评估交互流畅度时，先确认正在运行原生版本；Xcode Canvas 和未优化的 Debug 构建不作为正式性能结论。生成示例文案时的约 0.65 秒等待用于演示加载状态，它与滚动、输入、切换页面的卡顿需要分别判断。句库读取、JSON 编码和文件写入现由独立存储 actor 执行；修改按顺序保存，成功后才更新收藏、版本和生成结果。输入即时更新内存，350 毫秒合并保存，离开页面和进入后台时补存草稿；草稿保存不会触发句库列表更新。照片在独立 actor 中解码并缓存，列表使用最长边 240 像素的缩略图，详情使用最长边 1280 像素的图，避免在视图 body 中重复解码。这些改动消除了已知的主线程 I/O 和重复图片解码路径，尚未进行真机帧率和长时间使用测量。[Apple 响应速度与主线程工作](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)、[Apple Instruments 性能验证](https://developer.apple.com/tutorials/instruments/executing-work-asynchronously)

本次邀请认证 UI 测试报告：`native/build/BetaAccessSignedFlow.xcresult`；此前核心流程报告为 `native/build/BetaAccessFlow.xcresult`（前两项通过，未签名的钥匙串用例失败后已用正常模拟器签名复测通过），结果为 `TEST SUCCEEDED`。本机首次测试在用例通过后停在诊断收集；关闭额外诊断并串行执行后报告正常生成。真实运行截图位于 `deliverables/sanju-swiftui-home.png`、`deliverables/sanju-swiftui-result.png` 和 `deliverables/sanju-swiftui-library.png`。

本机网页生产构建仍因 Turbopack CSS 子进程无法绑定临时端口而中止；云端 Vercel 预览生产构建已成功，确认不是代码无法生产构建。未为绕开本机限制改动网页样式构建配置。

## 当前范围与后续工作

当前按用户最新决定暂不上传或分发 TestFlight。现有模型密钥已获用户确认可继续使用，真实看图生成和换句技术验证已通过。共享后端、邀请码、反馈、隐私说明和数据清理已经实现；云数据库开通与真实服务的部署验收仍需要完成后才能称为已接通。上架资料、图片分享卡片和后续界面迭代继续保留；相机和真实 HEIC 选图仍需真机验收。

普通删除会连同所属创作的旧版本和收藏一起删除，操作前明确确认。存储失败时结果暂留内存供复制，恢复保存后可确认原请求。网络结果未知时保留原请求标识，先确认原结果，避免再次创建。


## 本轮外部状态

- 已成功创建 Vercel 独立预览部署并完成云端生产构建；没有将它切换成生产别名。预览隐私页可访问，真实接口在未配置数据库时返回 503。
- Neon 创建请求仍返回 `integration_terms_acceptance_required`，`lan-lin` 团队的安装列表为空；云数据库尚未创建，尚未设置 `DATABASE_URL`、迁移线上数据库或开放生产内测开关。
- 因此当前不能称为“已接通线上正式后端”。完成正确账号下的 Marketplace 确认后，才可继续创建明确免费的数据库并做线上端到端验证。
- 未上传 App Store Connect，未发布 TestFlight，未向任何测试者发送邀请。继续评审界面可使用 **Sanju Preview**；连接真实服务的 **Sanju** 需要后端开通后再使用。
