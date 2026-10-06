# 生成未签名 IPA

工程已经提供 GitHub Actions 的 macOS 构建流程和本地 Mac 构建脚本。**目前没有产出的 IPA：当前 Linux 环境不能运行 Xcode，工作流也尚未在 GitHub 仓库执行。**

## GitHub Actions

1. 将本工程目录中的文件上传到自己的 GitHub 仓库根目录。根目录应直接包含 `ChatNative.xcodeproj`、`ChatNative/`、`scripts/` 和 `.github/`，不要只上传压缩包，也不要多套一层目录。
2. 主分支为 `main` 或 `master` 时，提交应用代码或工作流会自动触发构建。也可在仓库 **Actions → Build unsigned iOS IPA → Run workflow** 手动运行。
3. 流程在 `macos-15` runner 上运行核心测试，再使用 `xcodebuild` 编译 `iphoneos` 的 Release App。明确禁用代码签名，无需证书或 Apple 开发者账号。
4. 构建成功后，在运行页的 **Artifacts** 下载 `ChatNative-unsigned-IPA`。GitHub 下载的是 artifact ZIP，解压后取得真正的 `ChatNative-unsigned.ipa` 和 SHA-256 文件。
5. 若构建失败，在日志或 `iOS-build-log` 下载产物中查看错误。首次 Apple SDK 构建尚未验证，可能仍需要修复编译问题；失败时不会上传一个假 IPA。

仓库 Actions 必须启用，账号须有 macOS runner 的可用额度。私有仓库的运行时间是否收费取决于 GitHub 账号套餐和额度。

工作流只有仓库读取权限，不上传密钥，不提交修改，不发布 Release。你无需把 GitHub token 放入源码、仓库变量或此工作流。已经在聊天中公开的令牌应撤销；如需远程代操作，请使用仓库链接与正式的 GitHub 授权连接。

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
