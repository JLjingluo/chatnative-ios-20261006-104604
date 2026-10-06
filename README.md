# ChatNative · 原生 iOS OpenAI 兼容客户端

## IPA 直链下载

[直接下载 ChatNative-unsigned.ipa](https://github.com/JLjingluo/chatnative-ios-20261006-104604/releases/download/unsigned-5/ChatNative-unsigned.ipa)。无需 GitHub 登录，无需解压。源码仓库已按要求公开；发布文件已匿名下载并通过 SHA-256、ZIP 完整性、iOS arm64 和无代码签名检查。

SwiftUI、iOS 17+，集成 ChatGPTUI / swift-markdown；iOS 26+ 使用原生 Liquid Glass。提供完整 Xcode 工程，以 ChatGPT iOS 常见交互为参考：黑白界面、右侧用户气泡、左侧助手内容、底部圆角输入栏、抽屉式历史记录、模型面板、分组设置和语音页面。应用名与图标为独立设计。

已在 Xcode 26.3 与 Xcode 27 预览 runner 上通过核心测试、真机构建和模拟器启动，并人工查看两组共 18 张截图。[查看真实 UI 截图](UI_PREVIEWS.md)。顶部动作、输入栏、侧栏和语音控件使用系统原生 Liquid Glass，正文通过真正的 ChatGPTUI 包渲染；具体复用见 [UI_REFERENCE.md](UI_REFERENCE.md)。

**仍未验证官方客户端像素级 1:1。** 没有指定官方版本的参考截图，也未在真实 iPhone 或真实上游 API 上测试。键盘截图显示新模拟器的系统首次使用提示，仅确认输入栏随键盘区域移动，未完成普通键盘按键交互验收。

## 在 iPhone 上运行

1. 将此目录复制到 Mac，用 **Xcode 26.3 或更新版本**打开 `ChatNative.xcodeproj`。不要把 `Package.swift` 当成 iOS 应用入口，它仅用于核心测试。
2. 选择 `ChatNative` scheme。模拟器可直接尝试构建；真机运行在 Target → Signing & Capabilities 中选择你的 Apple Developer Team，并更换 Bundle Identifier。
3. 选择 iOS 17+ 的设备，按 ⌘R。首次使用语音时授权麦克风和语音识别。
4. 在侧栏底部打开「个人设置」→「API 与模型」，填写 HTTPS API 根地址和令牌。例如：

   ```text
   https://api.openai.com/v1
   https://your-litellm.example.com/v1
   https://your-new-api.example.com/v1
   ```

5. 点击「测试连接并获取模型」，或手动添加服务商提供的模型 ID。返回聊天页，点击顶部标题选择模型，再发送消息。

程序追加 `/chat/completions` 和 `/models`。也接受包含 `/chat/completions` 的完整地址并归一化。默认模型只是初始配置，并不保证你的账户可以使用。`/models` 的成功只说明模型列表请求成功，仍需用消息测试实际聊天。

## 已实现的功能

- 原生聊天页、建议提示、输入框、键盘交互、左边缘打开侧栏、深浅色模式。
- OpenAI Chat Completions 流式响应，SSE 注释、CRLF、Unicode、`[DONE]`、末尾无换行及普通 JSON 回复。
- 停止生成、错误提示、重试。生成任务绑定会话和消息 ID，切换历史时不会写入其他会话；新建聊天会停止当前生成。
- 本地历史记录、按时间分组、标题及消息搜索、重命名、删除、全部清除、JSON 导出。
- 用户消息编辑后重新生成、从任意消息创建分支。
- 通过 ChatGPTUI 渲染 Markdown 段落、标题、列表、引用、行内格式与代码块；代码复制、消息复制、系统分享及系统朗读。
- 从照片库选择最多 4 张图片，压缩至最长边 1600px，以 `image_url` data URL 发送。需在模型配置中声明图片支持。
- 可配置接口、Keychain 令牌、模型 ID/显示名/图片能力、系统提示词、最近消息数量、temperature 开关、外观、触感、语音语言。
- 语音页及输入框听写：iOS Speech 识别 → 用户确认发送 → OpenAI 兼容文字接口 → AVSpeechSynthesizer 朗读。可停止聆听和朗读。
- 记录原子写入、iOS 文件保护。未完成的回复保留并标记，后续请求不携带这些助手回复；无法解码的原始记录会尝试备份。

## 范围与兼容性

- **语音是分轮听写与系统朗读，不是 OpenAI Realtime、音频上传或官方高级语音模式。** 需要人工点击发送；不提供双向全双工语音、打断检测或官方音色。
- 不包含 ChatGPT 官方账户登录、订阅、官方模型权限、联网搜索、工具执行、文件解析、项目空间、跨设备同步和多模型并行比较。这些需要额外后端协议或产品逻辑，OpenAI 兼容聊天接口不会自动提供。
- Markdown 表格和数学公式尚未实现；代码块使用 ChatGPTUI 的 Highlighter 语法高亮并支持复制。
- 兼容层要求文字 `choices[].delta.content` 或非流式 `choices[].message.content`。只返回推理字段、工具调用或多模态 content 数组的服务不在此版本支持范围内。
- 参数与图片能力以服务商为准。默认不发送 temperature，以兼容限制参数的模型；模型列表不自动推断图片能力。
- 公网地址仅允许 HTTPS；本机开发地址接受 localhost / 127.0.0.1。iPhone 上的 localhost 指 iPhone 自己，连接 Mac 上的网关请使用可达 HTTPS 地址。
- 上下文按消息数量截断，不计算 token 或自动压缩。图片会随历史上下文重复发送，可能影响用量。
- 退到后台会停止生成与语音，避免把进程持续运行当作 iOS 已保证的能力。

## 数据与部署

令牌只写入本机 Keychain，不硬编码、不进入设置 JSON、不进入聊天导出。会话与图片保存在 Application Support 的 `ChatNative/conversations.json`。导出的 JSON 包含消息和图片，分享后副本由接收应用管理。

请求时，会向用户选择的 API 服务发送系统提示词、模型 ID、所选上下文及图片。系统听写可能由 Apple 服务器处理；这取决于设备、语言和系统能力。项目无遥测 SDK。PrivacyInfo 清单声明本机 UserDefaults 使用，不替代上线时对实际上游服务和数据使用填写的 App Store 隐私资料。

自用可填写自己的 API Key。如果对外提供网关服务，应用填写网关用户令牌，供应商主密钥放在你自己的服务端。此工程不会替你部署 LiteLLM 或 New API，也未接入任何真实密钥。

## 验证

在安装 Swift 5.9+ 的机器上：

```bash
swift test
```

可移植测试使用应用相同的 `Models.swift` 和 `OpenAIClient.swift`。Linux 没有 URLSession.AsyncBytes，原生 `bytes(for:)` 运输层只在 Apple 平台编译；SSE 字节消费、请求构造及错误解析仍使用相同实现参与测试。

在 Mac 上验证 iOS 构建与测试：

```bash
xcodebuild -list -project ChatNative.xcodeproj
xcodebuild -project ChatNative.xcodeproj -scheme ChatNative \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
# 查看可用模拟器后，将名字替换成你的设备名称
xcodebuild -project ChatNative.xcodeproj -scheme ChatNative \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

本次实际执行结果见 `VALIDATION.md`。真机建议验收：流式中文/代码、停止与重试、切换会话、后台恢复、拒绝麦克风权限、图片模型和文字模型、401/429/网络错误，以及 VoiceOver、大字体和横屏 iPad。

## 目录

```text
ChatNative.xcodeproj/        完整工程及共享 scheme
ChatNative/ChatNativeApp.swift
ChatNative/Core/            数据、请求/SSE、Keychain、会话状态、语音
ChatNative/Views/           聊天、输入栏、消息、侧栏、模型、设置、语音
ChatNative/Resources/       Info.plist、隐私清单、图标与颜色
ChatNativeTests/            核心协议测试
Package.swift               可移植核心测试入口
scripts/generate_project.py 工程配置生成器，新增文件后可重新执行
```

## 继续对齐官方截图

需要指定 ChatGPT iOS 的版本、目标 iPhone、系统字体/语言/显示缩放，以及聊天页、键盘展开、侧栏、模型面板、设置与语音页的参考截图。现有颜色、边距和字号集中在 SwiftUI 视图中，可按这些截图逐页调整；在取得截图并运行 iOS 渲染前，不应宣称 1:1 已完成。

## 未签名 IPA 构建

参见 [BUILD_IPA.md](BUILD_IPA.md)。工作流成功执行，Release 提供[单独的未签名 IPA](https://github.com/JLjingluo/chatnative-ios-20261006-104604/releases/download/unsigned-5/ChatNative-unsigned.ipa)，无需解压外层 ZIP。
