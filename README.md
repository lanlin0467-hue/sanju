# 三句

把画面和心情写成三种味道，挑一句就用。项目包含 Next.js 网页/后端、原有 Capacitor iOS App，以及独立开发的 SwiftUI 原生版本。

## sanju2.0 进度

2026-10-20 起按用户提供的「三句 · 原生极简版」研发交付包接入新界面。主要客户端为 `native/Sanju.xcodeproj`：系统分组背景、深海青主题色、仅用于句子的宋体，包含创作、生成状态、结果、日期分组句库、收藏详情和旧句恢复。此前水彩版保存在 Git 历史及原素材中。完整源码、数据库迁移、测试、素材与许可证均在仓库；本机密钥、邀请码、签名文件、构建缓存和旧导出压缩包不上传。

先用 **Sanju Preview** 体验固定示例文案。真实 AI 邀请后端已实现，但云数据库开通、生产部署与线上验收仍待完成；2026-10-20 检查现有生产地址时，`/api/v1/health` 和 `/privacy` 均返回 404。本快照尚未上传 App Store Connect 或分发 TestFlight。签名、正式 Bundle ID 和测试审核资料需由发布团队配置。

接收开发者请先阅读 [SwiftUI 开发与部署说明](native/README.md)；`ios/App` 与 `mobile/` 保留的是旧 Capacitor 路线，不是这次主要交接的客户端。

## SwiftUI 原生版本

正式客户端在 `native/Sanju.xcodeproj`，先选择 **Sanju Preview** scheme 体验创作、生成结果和句库；需要断点调试时选择 **Sanju Demo**。需要 iOS 17+，不依赖网页导出或 Capacitor 同步。包含本机历史、收藏、旧句版本、搜索、复制和系统分享。

运行与接口联调、修改界面的位置见 [SwiftUI 开发说明](native/README.md)。生产任务和额度的 PostgreSQL 存储代码已实现，云数据库和正式服务部署仍待完成。

## 网页开发

```bash
npm ci
cp .env.example .env.local
# 在 .env.local 中设置自己的 MODEL_API_KEY
npm run dev
```

打开 http://localhost:3000。密钥只由服务端读取。用 `FAKE_MODEL=1 npm run dev` 可以用固定测试句子调试，不调用模型。

## 原有 Capacitor iPhone 和 iPad 版本

工程位于 `ios/App/App.xcodeproj`，使用 Swift Package Manager 管理原生依赖。需要 Node.js 22+、macOS 和 Xcode 26+，支持 iOS 15+。

```bash
npm ci
npm run ios:sync
npm run ios:open
```

在 Xcode 中选择 iPhone 模拟器并点击 Run。连接真机时，在 App → Signing & Capabilities 中选择自己的 Team，并使用自己账号可用的 Bundle Identifier；当前占位为 `com.sanju.app`。分发和 TestFlight 需要用所有者的开发者账号签名。

界面内置在 App 中。AI 生成仍需要网络，通过原生 HTTP 请求线上 `/api/generate`，不会把 Next.js 服务端或模型密钥装进手机。照片使用系统相册/相机选择器，句子支持原生剪贴板与系统分享。

App 默认调用项目已有的 `https://sanju-two.vercel.app`。更换后端时，在根目录 `.env.local` 设置公开站点根地址，然后重新同步、编译：

```dotenv
NEXT_PUBLIC_NATIVE_API_BASE_URL=https://your-api.example.com
```

该地址必须使用 HTTPS。网页仍然调用自身同源 API。`mobile/` 只导出页面；根目录 `npm run build` 继续构建带动态 API 的完整网站。

详细安装、打包、真机验收和当前限制见 [iOS 使用说明](docs/iOS使用说明.md)。

## 常用命令

| 命令 | 用途 |
| --- | --- |
| `npm run dev` | 本地网页和 API |
| `npm run build` / `npm start` | 网页生产构建 / 启动 |
| `npm run build:mobile` | 将共享界面静态导出至 `mobile/out` |
| `npm run ios:sync` | 构建界面并同步原生依赖、页面和配置 |
| `npm run ios:open` | 打开 Xcode 工程 |
| `npm run ios:run` | 同步并选择模拟器或设备运行 |
| `npm run ios:build` | 编译 Release 模拟器版本至 `ios/build`，无需开发者证书 |
| `npm test` / `npm run lint` | 自动检查 / 代码检查 |

上述 `npm ci` 和 `npm run ios:sync` 步骤只适用于旧 Capacitor 工程。SwiftUI 版本直接打开 `native/Sanju.xcodeproj`；其本地 Swift package、字体、图片和共享 schemes 已提交。旧 Capacitor 生成的网页资源和原生配置不提交；修改其共享界面后要再次同步，Xcode 的 Run 不会自动重建网页。
