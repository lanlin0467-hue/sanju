# 三句 iOS 使用说明

封装日期：2026-10-19。

## 工程和功能

- App 名称：三句。
- Bundle Identifier：`com.sanju.app`，为开发占位；正式分发前改为所有者账号下的唯一标识，并同步修改 `capacitor.config.ts`。
- Xcode 工程：`ios/App/App.xcodeproj`。
- 原生容器：Capacitor 8，Swift Package Manager。
- 系统要求：iOS 15+；开发需要 macOS、Node.js 22+ 和 Xcode 26+。
- 支持 iPhone、iPad；浅色界面，带安全区域适配、相册/相机、剪贴板和系统分享。
- 页面资源内置；生成与换句仍需要线上 AI 后端。离线可打开界面，不能离线生成。

## 从源码运行

在项目根目录执行：

```bash
npm ci
npm run ios:sync
npm run ios:open
```

首次 Xcode 打开时会解析 Swift Package。选择 iPhone 或 iPad 模拟器，点击 Run。也可执行 `npm run ios:build`，编译完成的模拟器 App 位于 `ios/build/Build/Products/Release-iphonesimulator/App.app`。

运行脚本和共享 Xcode scheme 默认使用已验证的 Release 配置。模拟器使用本地临时签名，无需 Apple 开发者证书。本机 Debug 版本可以编译，但直接从命令行启动时停留在动态库加载阶段；需要调试时可在 Xcode 的 Edit Scheme 中切换 Debug 并连接调试器，本次未验证该交互。

## 安装到自己的 iPhone

1. 在 Xcode → Settings → Accounts 登录自己的 Apple 账号。
2. 用 USB 连接 iPhone，并按手机提示信任电脑；按系统要求开启开发者模式。
3. 选择 App target → Signing & Capabilities，启用 Automatically manage signing，选择自己的 Team。
4. 将 Bundle Identifier 改为自己账号可用的值，并在 `capacitor.config.ts` 同步记录。
5. 将运行设备选为自己的 iPhone，点击 Run；按系统提示完成开发者信任。

交付的模拟器 `.app` 仅用于模拟器，不能直接拖到 iPhone 安装。真机安装和分发包必须经过对应账号签名。本次未替所有者登录、创建证书、上传或提交审核。

## 调整后端

默认后端为项目记录中的 `https://sanju-two.vercel.app`。根目录 `.env.local` 可添加：

```dotenv
NEXT_PUBLIC_NATIVE_API_BASE_URL=https://your-api.example.com
```

重新运行 `npm run ios:sync`，再在 Xcode 编译。只接受 HTTPS 根地址，不带路径、凭据或查询参数。此配置是公开地址，会出现在客户端资源中；不能填密钥。`MODEL_API_KEY` 只在服务端设置。

原生端使用 CapacitorHttp 发送请求，绕开浏览器跨域限制，不需要给现有 API 增加通配 CORS。iOS 的 URLSession 默认 Cookie 存储用于现有 `sanju_vid` Cookie；原有 Cookie 只是匿名访客标识，不是可靠的登录或费用控制。网页继续使用同源 fetch。

## 构建结构

| 文件/目录 | 用途 |
| --- | --- |
| `capacitor.config.ts` | App 名称、标识、资源路径和 iOS 容器配置 |
| `mobile/app/` | 只包含静态界面，复用 `src/components/HomeForm.tsx` |
| `mobile/next.config.ts` | Next.js 静态导出及公开 API 地址 |
| `scripts/build-mobile.mjs` | 读取根目录环境变量，校验地址、复制图标并构建页面 |
| `src/lib/clientApi.ts` | 网页同源请求 / App 原生请求；错误及等待超时处理 |
| `src/lib/native.ts` | 原生选图、复制、分享，保留网页兼容路径 |
| `ios/App/App/Info.plist` | 中文名称、相机/相册用途、浅色模式配置 |
| `ios/App/App/Assets.xcassets` | App 图标 |

App 页面中只包含客户端依赖；`src/app/api/`、模型服务端代码和环境变量文件不会作为页面资源复制到原生工程。`mobile/out`、`ios/build` 和复制后的原生 `public` 都是可重建文件，已加入忽略规则。

## 真机验收

- 从相册选择 HEIC/JPEG，及相机拍照：检查方向、预览与压缩后的大小。
- 拒绝相机权限、取消选图，再次操作应能继续使用。
- 文字生成与图片生成各一次，单句换句、复制、分享及取消分享。
- 检查刘海屏、底部手势区域、键盘弹出、iPad 分享浮窗和横屏。
- 弱网、断网及后端超时会显示错误，恢复网络后可以重试。

模拟器无法替代真机相机与权限验收。

## 发布前仍需完成

本次交付为 iOS 封装工程。TestFlight / App Store 发布还需所有者开发者账号、签名、App Store Connect 应用记录，以及正式隐私政策、截图等商店资料。使用 Xcode 的 Product → Archive，再在 Organizer 分发。

后端仍沿用原项目限制：每个服务进程每日最多 4 次请求、每访客每分钟 3 次。生成和换句共享额度，重启清零，多实例不共享。该配置适合现有小规模体验；公开运营前须按实际预算完善共享限流。

图片会交给 OpenRouter 与下游模型服务商处理。页面已补充第三方处理说明，但正式隐私政策、AI 数据处理披露、服务商账号及正式域名仍需由所有者落实。已有网页的图片换句未保留原照片上下文等问题没有在本次封装中重写。

参考官方文档：[Capacitor iOS](https://capacitorjs.com/docs/ios)、[原生 HTTP](https://capacitorjs.com/docs/apis/http)、[Swift Package Manager](https://capacitorjs.com/docs/ios/spm)。

## 本次验证记录

- 自动检查：12 项通过，覆盖字数、限流、网页/原生请求分流及错误响应。
- ESLint、TypeScript、完整 Next.js 网页构建、App 静态页面构建通过。
- iOS Debug 与 Release 模拟器构建通过；Release 真机目标未签名归档通过。
- iPhone 18 Pro / iOS 27 模拟器中确认首页完整显示，图标、中文文字和安全区域正常。
- 线上 `/api/generate` 的无效请求返回预期 400 JSON；未进行收费模型生成验收。
- 扫描 App 页面资源，未发现根目录配置的模型密钥或服务端源码被复制进去。
- 真机相机、相册权限、生成、复制和分享交互仍需按上面的清单验收。
