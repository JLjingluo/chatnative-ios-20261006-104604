# 生成未签名 IPA

[直接下载 ChatNative-unsigned.ipa](https://github.com/JLjingluo/chatnative-ios-20261006-104604/releases/download/unsigned-5/ChatNative-unsigned.ipa)。无需登录，无需解压。文件已匿名下载并完成独立校验。

工程提供 GitHub Actions 的 macOS 构建流程和本地 Mac 构建脚本。发布产物是单独的 IPA 文件；无需解压外层 artifact ZIP。

## GitHub Actions

1. 将本工程目录中的文件上传到自己的 GitHub 仓库根目录。根目录应直接包含 `ChatNative.xcodeproj`、`ChatNative/`、`scripts/` 和 `.github/`，不要只上传压缩包，也不要多套一层目录。
2. 主分支为 `main` 或 `master` 时，提交应用代码或工作流会自动触发构建。也可在仓库 **Actions → Build unsigned iOS IPA → Run workflow** 手动运行。
3. 流程在 `macos-15` runner 上明确选择 Xcode 26.3、运行核心测试，再使用 `xcodebuild` 编译 `iphoneos` 的 Release App。明确禁用代码签名，无需证书或 Apple 开发者账号。
4. 同时在 iOS 26 模拟器运行应用并生成 9 张截图；额外的 `xcode-27` runner 验证 iOS 27 并生成对应截图。两项均通过后，Release 附件提供单独的 `ChatNative-unsigned.ipa`、SHA-256 和截图；点击 IPA 即可下载。
5. 若构建失败，在日志或 `iOS-build-log` 下载产物中查看错误。Apple SDK 的首次构建已通过；未来若编译失败，不会上传一个假 IPA。

仓库 Actions 必须启用。此仓库已公开，使用标准 GitHub-hosted macOS runner；公开仓库的标准 runner 通常无需支付分钟费用。

工作流使用 GitHub 自动生成的运行令牌与 `contents: write` 权限，在当前仓库发布 Release 和单独的 IPA 文件；不把个人访问令牌写入源码。你无需把 GitHub token 放入源码、仓库变量或此工作流。已经在聊天中公开的令牌应撤销；如需远程代操作，请使用仓库链接与正式的 GitHub 授权连接。

## 在 Mac 上

安装完整 Xcode，选择其 Developer Directory 后运行：

```bash
bash scripts/build_unsigned_ipa.sh
```

输出：

```text
artifacts/ChatNative-unsigned.ipa
artifacts/ChatNative-unsigned.ipa.sha256
artifacts/xcodebuild.log
```

脚本检查 arm64 可执行文件、无代码签名和 ZIP 完整性，再将已编译的 `.app` 放入标准 `Payload/ChatNative.app` 路径。它不会用源码压缩包冒充 IPA。

## 安装限制

未签名不等于无需签名即可安装。普通 iOS 设备不能直接安装未签名 IPA；后续需通过适用于设备的签名或安装机制处理。此包不是 App Store 或 TestFlight 的发行包。
