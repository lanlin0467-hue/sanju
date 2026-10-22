# 三句 sanju2.0 上架交接说明

交接日期：2026-10-20；设计补充：2026-10-22。接收方：负责 SwiftUI 客户端、后端部署、签名及 App Store 提审的开发者。

「三句」让用户提供照片或画面描述、选择心情，生成冷峻、浪漫、青春三种文风的短句。当前原生客户端和邀请内测后端代码已经实现，原生极简界面已推送；**生产后端尚未接通，尚未上传 App Store Connect 或分发 TestFlight。** 接手范围包括部署、真机验收及审核准备，不能只做打包上传。

2026-10-22 产品所有者已确认 [紫藤纸景系列](../native/Design/Wisteria/README.md)为最新视觉方向，三页设计稿覆盖创作、结果和句库。当前可运行客户端仍是原生极简版；接手开发需按新稿完成 SwiftUI 接入和适配，再进行发布验收。

## 接手入口与版本

| 项目 | 交接信息 |
| --- | --- |
| GitHub 仓库 | [lanlin0467-hue/sanju](https://github.com/lanlin0467-hue/sanju)，已由所有者授权公开；查看代码和文档无需邀请，直接推送代码仍需协作者权限 |
| 当前开发分支 | [`sanju2.0`](https://github.com/lanlin0467-hue/sanju/tree/sanju2.0) |
| 界面改版基线 | [`26a99d040e58a0f0a9a71d7d359d630fb1855290`](https://github.com/lanlin0467-hue/sanju/commit/26a99d040e58a0f0a9a71d7d359d630fb1855290)，提交说明为「sanju2.0: 接入原生极简界面与状态交互」；后续文档提交在此之后 |
| 原开发机目录 | `/Users/zero/Desktop/sanju`；接收方可 clone 到自己的目录 |
| 正确 iOS 工程 | **`native/Sanju.xcodeproj`**，App target 为 `Sanju` |
| 平台 | 独立 SwiftUI，最低 iOS 17，目前仅配置 iPhone，竖屏 |
| 历史版本 | `sanju1.0` 分支保留；`ios/App`、`mobile/` 为旧 Capacitor 路线 |

先读本说明，再读 [native/README.md](../native/README.md)。[旧开发交接说明](sanju开发交接说明.md)及 [2026-10-08 部署记录](../docs/部署记录.md)描述旧网页阶段，不能作为新版生产服务已可用的依据。

## 正确工程与运行方式

在仓库根目录执行 `open native/Sanju.xcodeproj`。原生 App 只依赖系统框架、本地 Swift package 和已提交素材；运行示例无需安装 Node 依赖，也无需 `npm run ios:sync`。后端及接口测试使用 Node.js 22+，按已提交的锁文件执行 `npm ci`。

| Scheme | 运行配置与用途 |
| --- | --- |
| `Sanju Preview` | Preview 优化配置，无调试器，固定示例服务；从手机桌面再次打开仍是示例模式，不调用收费模型，适合评审布局和交互 |
| `Sanju Demo` | Debug，加 `--demo`，用于调试固定示例流程 |
| `Sanju` | Debug 运行真实服务；**正式归档选择此 scheme，Archive 配置为 Release** |

Release 不接受 `--demo`、`--api-base-url` 或测试场景参数。Preview 和 Demo 不能用来验收实际文案质量；正式发布包必须验证真实服务、邀请准入和同意流程。

关键目录如下：

| 路径 | 用途 |
| --- | --- |
| `native/Sanju/` | SwiftUI 页面、相册与相机、隐私说明、钥匙串、字体和图片 |
| `native/SanjuCore/` | 数据模型、AppStore、HTTP 生成服务、JSON 持久化及核心测试 |
| `native/SanjuUITests/` | 独立随机句库的模拟器 UI 回归 |
| `native/Config/LocalOverrides.xcconfig` | 公开 API 地址与 Bundle ID 配置 |
| `native/scripts/generate-project.py` | 工程生成脚本；新增或移除 App Swift 文件后运行 |
| `native/Design/Wisteria/README.md` | 最新确认的紫藤纸景视觉、三页设计稿、提示词及接入要点 |
| `native/Design/NativeMinimal/design-tokens.json` | 本轮原生极简设计 Token；动态颜色在 App 的 Asset Catalog 中 |
| `src/app/api/v1/`、`src/lib/beta/` | 新版邀请内测 API、数据库、额度和模型调用 |
| `db/migrations/001_beta.sql`、`scripts/beta-admin.mjs` | PostgreSQL 迁移及内测管理工具 |
| `src/app/privacy/page.tsx` | 网页隐私政策；客户端离线版本在 `native/Sanju/SettingsView.swift` |

### 正式签名与构建配置

当前开发 Bundle ID 为 `com.sanju.native`，版本为 `0.1.0`、Build 为 `1`，采用自动签名；正式 Team、Bundle ID 和发布版本尚未确认。不要把旧 Capacitor 的 `com.sanju.app` 当作新版正式标识。

本机签名覆盖可放入已忽略的 `native/Config/Signing.local.xcconfig`，例如：

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
SANJU_BUNDLE_ID = com.yourcompany.sanju
```

上述值仅为示例，必须替换为所有者确认的实际标识。正式 Bundle ID 要与 App Store Connect 记录、签名描述文件一致。确定后妥善保存；改变 Bundle ID 也会影响应用身份、本机数据和钥匙串访问。

公开后端地址通过 `SANJU_API_BASE_URL` 编译进 App，当前为 `https://sanju-two.vercel.app`。在 xcconfig 中沿用现有 `https:/$()/…` 写法，避免 `//` 被当作注释。原生工程不读取旧 Capacitor 的 `NEXT_PUBLIC_NATIVE_API_BASE_URL`。确认服务地址后重新构建 Release。

工程由脚本生成，版本号等生成设置调整时同步修改生成脚本，避免下次生成覆盖 Xcode 中的修改。构建缓存、证书、描述文件及 `Signing.local.xcconfig` 均不提交 Git。未签名 Release 构建通过，仅证明编译通过，不代表分发签名或上传已验证。

## 已完成的产品与技术进度

| 范围 | 已实现内容 |
| --- | --- |
| 创作 | 相册、拍照入口、预览、更换、移除；异步照片读取与取消；照片或画面文字至少一项；描述最多 200 字，心情最多 30 字；快捷及自定义心情、清空、草稿保存与恢复 |
| 结果 | 冷峻、浪漫、青春三句；复制、收藏、单句替换、系统文字分享；旧版本查看与恢复，换句后保留旧句收藏 |
| 句库 | 按日期分组、全部和收藏筛选、搜索句子及画面和心情、历史版本命中、照片缩略图、详情、确认删除与空状态 |
| 本轮界面 | 系统分组背景、深海青主题色、句子宋体、浅深色和大字号；创作、结果、句库、详情、旧句及异常状态已接入 |
| 本机数据 | JSON 文件异步持久化；草稿 350 毫秒合并保存；后台图片解码、缓存与缩略图；兼容已有句库，尚无应用内云同步 |
| 请求可靠性 | 防重复点击、未知结果保留原请求、回到前台和网络恢复后查询；恢复只 GET 原 requestId，404 不自动重新 POST 付费生成；保存失败提示与复制保留 |
| 邀请后端代码 | PostgreSQL、邀请码摘要、钥匙串会话、服务端额度、去重与结果恢复、调用预算、反馈、隐私说明和定期清理 |
| 素材 | 字体、许可证、App 图标及历史原创水彩素材已入库；当前页面使用原生极简设计 |

当前内测规则为每位测试者每天 5 次创作，北京时间 00:00 恢复；同一邀请码多个会话共享额度。每份创作共享 3 次换句，24 小时有效；恢复旧句不扣次数，删除记录不恢复额度。设计稿中的 7/10 次是占位显示，不应写回业务逻辑。

没有实现订阅、支付、句库云同步或图片分享卡片；现有分享为系统文字分享。图片卡片与付费功能属于后续产品范围，是否纳入首发由所有者决定。

## 已有验证与实际限制

界面改版基线的验证结果：

- Node/接口 34 项、Swift 核心 19 项通过；Preview 模拟器和未签名 iPhone Release 构建通过。
- 11 项 UI 用例通过，覆盖生成、同意与取消、离线隐私说明、复制、换句、收藏、重启、旧句恢复、搜索、详情与删除、请求恢复、邀请与钥匙串、相册、浅深色、大字号、草稿和输入限制。
- 主报告 `native/build/NativeMinimalVerified.xcresult` 为 9 项通过，早期自定义心情确认点击失败；最终 `NativeMinimalInputDone.xcresult` 的自定义心情/草稿与输入限制 2 项通过，使用键盘「完成」提交。系统弹窗确认按钮另做过手动验证，iOS 27 模拟器的自动确认点击仍不稳定。
- 真实图片生成和换句做过 OpenRouter 技术验证；这不等于线上端到端、真实照片质量和内容安全已验收。此前 ESLint、TypeScript 检查通过，接手修改后应重新执行。

测试代码和 [界面截图](sanju-native-minimal-home.png)已入库，截图共 9 张，文件名为 `sanju-native-minimal-*.png`。`native/build/` 中的原始日志与 xcresult 属于被忽略的本机构建产物，clone 后需要重新生成。完整命令和报告说明见 [原生验证说明](../native/README.md#验证命令)。本次交接文档提交未修改程序，也不代表重新跑过上述回归。

运行 UI 回归前，按原生 README 启动本机 3001/3002 固定数据服务并准备模拟器相册测试图。涉及钥匙串的模拟器测试需正常 ad hoc 签名：`CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES`，不能沿用无签名构建的设置。

真机相机、真实 HEIC、大图、弱网、真机键盘、覆盖安装和长期性能尚需实际 iPhone 验收。保持同一 Bundle ID 覆盖安装并检查数据延续，勿先卸载有待保留句库的 App。

## 上架前必须完成的工作

| 工作 | 当前状态 | 负责人及完成标准 |
| --- | --- | --- |
| 开发者会员与账号归属 | 账号主体、Team 待确认 | 所有者确认个人或组织账号并完成会员及协议；接手人用受邀账号协作 |
| 正式应用身份与签名 | 正式 Bundle ID 未定，未验证分发签名 | 所有者确认标识；接手人完成 App Store Connect 记录、签名、Archive 和 Validate |
| 紫藤纸景界面接入 | 三页设计稿已确认，SwiftUI 尚未接入 | 按设计说明完成三页原生布局、相关状态与辅助页面的视觉统一，并复核深色、大字号、键盘和真机表现 |
| 生产服务 | 数据库开通、迁移、部署和线上联调未完成 | 授权后部署；真实客户端完成有图生成、换句、恢复、额度和反馈验收 |
| 隐私与支持 | App 内说明可离线阅读，生产网页返回 404；支持邮箱未定 | 所有者确认运营主体和联系方式；接手人上线可公开访问的隐私与支持页面，统一 App 和商店披露 |
| 内容安全 | 提示词含安全约束，已有反馈和资格撤销；完整治理未验收 | 接手人补齐服务端输入/输出过滤、拒绝与举报处理流程，测试风险样本，明确人工处理责任 |
| 真机与覆盖安装 | 模拟器回归完成，真机专项未完成 | 接手人提供设备、系统、构建号、结果及问题修复记录 |
| 上架资料 | 未完成 | 所有者确认名称、文案、销售地区和首发范围；接手人准备截图、隐私标签、年龄分级、审核说明及所需地区资料 |
| TestFlight 与正式提审 | 未上传、未分发、未提交审核 | 获具体授权后上传；完成测试、审核沟通及发布，记录链接和构建号 |

### 生产后端接通顺序

2026-10-20 再次只读检查现有 `https://sanju-two.vercel.app`：`/api/v1/health` 和 `/privacy` 均返回 **404**。此前独立 Vercel 预览部署构建成功，预览隐私页可访问；未接数据库时 API 返回 503。旧生产网页可打开，不能据此认定新版 `/api/v1` 已部署。

1. 核实所有者现有 Vercel 项目 `lan-lin/sanju` 和 Neon 资源。此前 Marketplace 创建流程返回 `integration_terms_acceptance_required`，开通被暂缓；先检查实际资源，避免重复创建。需要开通或付费时由所有者确认。
2. 在获授权的生产数据库执行 `db/migrations/001_beta.sql`，核实 `sanju_beta` 表及权限。环境变量模板见 [.env.example](../.env.example)，真实值只放服务端或被忽略的本机环境文件。
3. 配置真实模型与维护任务后部署新版 Next.js 服务，最后开放 `SANJU_BETA_ENABLED=1`。任何 Next.js 代码修改前先读根目录 `AGENTS.md` 和本机安装版本的相关官方指南。
4. 核对健康接口 HTTP 200，且返回 `status: ready`、`mode: live`。该接口检查配置和数据库，不执行模型调用；随后仍须用独立邀请码进行少量真实生成验收。
5. 确认定期清理实际执行；再将真实 HTTPS 地址写入原生配置、重新打包并从手机访问。国内 Wi-Fi 与蜂窝网络的可达性需实测。

| 服务端变量 | 当前配置或用途 |
| --- | --- |
| `DATABASE_URL` | 生产 PostgreSQL 连接凭据 |
| `SANJU_BETA_ENABLED=1` | 迁移和配置就绪后开放新版邀请接口 |
| `MODEL_API_KEY` 或 `SANJU_MODEL_API_KEY` | 服务端模型密钥，客户端不得包含 |
| `SANJU_MODEL_PROVIDER=openrouter` | 当前模型提供方 |
| `SANJU_MODEL_ID=qwen/qwen3.7-flash` | 当前代码配置；上线前确认该模型仍可用及图片能力、费用和数据政策 |
| `SANJU_BETA_DAILY_MODEL_CALLS=40` | 全站每日模型调用预留上限，含创作及换句；每任务最多预留两次，失败不退此预算 |
| `SANJU_REQUIRE_ZDR=0` | 既有技术验证的模型路由不支持强制 ZDR，不能直接改为 1；更换端点后重新核实 |
| `CRON_SECRET` | 随机维护凭据；对应 `vercel.json` 的每日 `/api/v1/maintenance` 任务 |

生产不得启用 `FAKE_MODEL=1`。新版预算不涵盖旧 `/api/generate` 网页接口，上线前评估是否保留旧入口，并配置模型供应商侧账单限额和告警。

以下命令只供接手人在核对目标环境并获授权后执行，本次交接没有执行迁移、创建邀请码或部署：

```bash
npm ci
# 将授权的生产连接变量放入已忽略的 .env.beta.local，勿输出真实值
npm run beta:migrate
npm run beta:invite -- reviewer
npm run beta:status
```

新邀请码默认有效 30 天，仅保存到 `.local/invite-<tester UUID>.txt`，权限为 600，数据库只存摘要。`reviewer` 是备注，不是管理命令的标识。撤销或提前删除服务端内容时使用实际 tester UUID：

```bash
node --env-file-if-exists=.env.beta.local scripts/beta-admin.mjs revoke TESTER_UUID
node --env-file-if-exists=.env.beta.local scripts/beta-admin.mjs purge TESTER_UUID
```

以上 `TESTER_UUID` 是需替换的占位符。删除服务端内容保留用量计数，不恢复额度。邀请码经授权单独提供给测试者或填入 App Review 的受控审核资料，不放 GitHub 文档、截图或日志。

### 隐私与内容安全收尾

当前实际数据路径为手机 → 三句服务端 → OpenRouter 及其下游 Qwen 服务商。数据库保存输入摘要、任务状态和生成文字，不保存原始照片、画面描述或心情正文；手机保留照片压缩副本、草稿、句子和收藏。定期清理按现有设计将结果/请求保留控制在最多 8 天、反馈最多 31 天，必须验证维护任务持续生效。第三方和托管平台的数据处理需按其实际政策披露。

正式隐私政策要写明运营主体、联系方式、第三方处理、用途、保存时间、撤回与删除路径，并与 App 内 `PrivacyPolicyView`、同意版本及实际服务商同步。清空本机句库不会自动提前清除服务端记录，当前提前清理由维护者执行 `purge`。隐私清单 `PrivacyInfo.xcprivacy` 已存在，但 App Store Connect 的隐私问卷仍须按真实数据流单独填写和复核，不能填成“完全不收集数据”。参见 [Apple 隐私披露说明](https://developer.apple.com/app-store/app-privacy-details/)。

Apple 要求向第三方 AI 分享个人数据前清楚披露并取得明确同意；当前已实现同意和撤回流程，正式包应逐项验收。内容治理还需覆盖风险输入、生成结果、举报响应及滥用者处置；现有提示词、反馈入口和 `revoke` 不能替代完整验收。相关要求见 [审核指南 5.1.2 和 1.2](https://developer.apple.com/app-store/review/guidelines/)。

### 真机与线上验收

- 在真实 iPhone 测试拍照、拒绝权限、相册取消/更换、真实 HEIC、大图和方向；旧图片异步读取不能覆盖新选择。
- 测试中文输入法联想、200/30 字限制、系统心情弹窗确认、键盘焦点；浅深色、大字号、长句和按钮均可用。
- 真实服务验证无图和有图创作、三种文风、复制与分享、三次共享换句、旧句恢复、收藏与搜索、退出重开及删除。
- 验证同邀请码跨会话额度、每日恢复、24 小时过期、失效/撤销凭据、每日调用预算耗尽，明确 UI 提示。
- 模拟超时、断网、重回前台及服务器错误，检查原 requestId 恢复、无重复付费调用、失败不覆盖原句和收藏。
- 验证保存失败提示、草稿持久化，以及相同 Bundle ID 下覆盖安装后的句库、照片、收藏、旧版本与钥匙串会话。
- 验证实际第三方 AI 同意和撤回、公开隐私页、支持入口、反馈接收、内容拒绝/举报及服务端清理。

## Apple 账号与提审安排

账号、Team、应用记录、域名和云资源应归产品所有者掌控。通过 App Store Connect 的 Users and Access 邀请接手人；负责完整提审可考虑 App Manager，具体签名资源权限按实际工作单独配置。个人开发者账号的受邀用户只有 App Store Connect 访问权，不会自动获得开发者会员资源，证书与签名环节需所有者配合。参见 [用户邀请](https://developer.apple.com/help/app-store-connect/manage-your-team/add-and-edit-users/)及 [角色权限](https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions/)。

截至 2026-10-20 核对，Apple 自 2026-04-28 起要求上传的 iOS App 使用 iOS 26 SDK 或更新版本构建；这与 App 的最低运行系统 iOS 17 是两件事。接手人使用满足当时要求的正式版 Xcode，提交前再核对 [SDK 要求](https://developer.apple.com/news/?id=ueeok6yw)及 [后续要求](https://developer.apple.com/news/upcoming-requirements/)。

提审按以下顺序推进：

1. 所有者确认账号主体、Team、正式 Bundle ID、支持邮箱、销售地区、首发版本和免费额度策略；明确邀请机制在公开版本中的处理方式。
2. 完成生产服务和真机验收，确认发布版本的隐私文案、支持页和内容安全流程。字体许可随包保留，商店文案使用冷峻、浪漫、青春，不宣称作家背书。
3. 选择 `Sanju` scheme、Release Archive，配置唯一 Build 号，核对生产 URL、隐私清单、相机用途说明、图标和出口合规声明；验证 App 可从桌面独立运行并连接真实服务。
4. 获上传授权后上传 App Store Connect，先用 TestFlight 做真实设备测试，按 Apple 要求完成外部测试审核。测试发布流程见 [TestFlight 说明](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)。
5. 准备最终商店截图、名称/副标题/描述/关键词、分类、年龄分级、隐私问卷、支持与隐私 URL、版权信息和审核联系资料。仓库截图可作布局参考，商店截图应来自最终发布构建并准确展示功能。
6. 提供能覆盖审查周期的有效审核邀请码、操作步骤、额度规则、AI 处理和反馈说明，保持后端可用并处理额度耗尽问题。当前固定示例 Preview 不是正式包的审核凭证。Apple 要求完整可用的提交，测试阶段使用 TestFlight；参见 [审核指南 2.1 和 2.2](https://developer.apple.com/app-store/review/guidelines/)。
7. 获正式提审与发布授权后提交，保留 Apple 反馈、修复记录和最终发布信息。若仍处邀请测试阶段，先完成 TestFlight 验收，再按所有者确定的公开产品方案提审。

## 交付给所有者的验收结果

| 阶段 | 接手人需交付的记录 |
| --- | --- |
| 工程接通 | 源码 commit、Xcode/SDK 版本、实际 Team 与 Bundle ID、可复现的构建方式 |
| 后端上线 | 项目与域名归属、数据库迁移版本、服务配置项名称、健康与真实生成结果、额度/恢复/反馈/清理验收及回滚方法；不附明文密钥 |
| 真机通过 | 测试设备、系统、版本/Build、上述专项结果、已修复与仍存在的问题 |
| TestFlight | App Store Connect 应用记录、构建号、测试分组、测试反馈与解决情况 |
| 商店发布 | 提审资料、隐私与支持页面、审核往来、最终构建、发布时间和商店链接；未通过时明确阻塞原因及下一步 |

## 授权与敏感资料边界

本仓库提供源码、素材、许可证、测试和文档。模型密钥、邀请码、证书、描述文件、本机环境文件和构建缓存没有作为交接内容提交；通过所有者授权的渠道单独配置，不在聊天、Git、客户端或公开日志中暴露。Apple 密码和双重验证码不作为常规交接资料，优先使用邀请权限。

已有模型密钥曾获所有者授权继续使用，仍须按原有范围保管。云资源开通、费用、生产切换、TestFlight 上传与邀请、正式提审发布，以及后续 GitHub 推送，均按所有者的具体授权执行。本次授权范围是整理交接文档并推送到 `sanju2.0`，不包含开通资源或实际发布。
