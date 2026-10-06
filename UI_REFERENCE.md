# UI 参考与 Liquid Glass 改造记录

上一版 1.0.0 是独立编写的近似界面，没有引入 ChatGPTUI，没有 Liquid Glass，并且使用 Xcode 16.4 / iOS 18.5 SDK。用户指出的差距属实。

本次使用以下两个明确参考：

- [alfianlosari/ChatGPTUI](https://github.com/alfianlosari/ChatGPTUI)，固定到提交 `6092433201dc6a0787240b9252914fc2fe64456b`。
- [alfianlosari/ChatGPTSwiftUI](https://github.com/alfianlosari/ChatGPTSwiftUI)，核对提交 `bda026e3c931235a1dbbaf560e5ac7ffd178bc5b` 的 ContentView、MessageRowView、CodeBlockView 和 DotLoadingView。

这两个项目本身是较早的聊天应用/组件，不包含当前 ChatGPT iOS 的所有页面，也不包含 iOS 26 的玻璃控件。它们可作为代码底座和交互参考，不能充当最新官方界面的完整截图规范。

## 实际复用

- Xcode 工程通过 Swift Package Manager 引入真正的 ChatGPTUI 包。
- 助手正文使用 `ChatGPTUI.MarkdownAttributedStringParser` 和 `ChatGPTUI.AttributedView`，替代上一版按行手写的简化 Markdown 渲染。
- 代码块复用该解析器的 Highlighter 语法高亮，并采用现代深色代码卡片与复制操作。
- 流式列表沿用两个项目的 ScrollViewReader、LazyVStack、输入焦点、停止与重试结构，同时保留已有兼容 API、持久化和分支功能。
- 三点加载控件改编自 ChatGPTSwiftUI 的 DotLoadingView，替换为可暂停的 TimelineView，修正原始递归计时器的生命周期问题。
- MIT 许可已放入 ThirdParty/，同时随 App 打包，可在「设置 → 开源许可」查看。

## 原生 Liquid Glass

采用 Apple [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) 中的真实 API：

- `glassEffect(.regular, in:)`：顶部菜单/新聊天、模型选择、输入栏、附件入口、语音控件。
- `.regular.interactive()`：按钮的系统触摸响应。
- `GlassEffectContainer`：统一管理同一区域的多个玻璃控件。
- `glassEffectID` 与 Namespace：输入栏发送/停止/语音动作和语音控件切换时的形状过渡。
- iOS 26+ 自动启用。旧系统使用 material/实色回退；「降低透明度」时使用实色且保留对比度。
- 聊天正文和消息气泡使用普通内容表面，玻璃仅用于操作层，避免把整段文字放在难以阅读的透明表面上。

## 布局改造

- 去掉上一版自制花形标记和双行输入栏，改为简洁标题、单行多行可展开输入栏、独立附件按钮。
- 侧栏改为真正的推入式抽屉，搜索、顶部动作和底部个人设置入口使用玻璃控件。
- 模型面板调整为可滚动选择列表、能力标记、选中状态与管理入口。
- 设置采用系统 NavigationStack 和分组列表，由新 SDK 的系统导航/工具栏提供玻璃样式。
- 语音页改为动态蓝白球体、可切换的玻璃控件和对话文字面板；功能仍是听写/确认发送/系统朗读，不伪装成实时语音 API。

## 验收依据

CI 明确选择 Xcode 26，而不是依赖 runner 默认的旧 Xcode。同时使用 `xcode-27` 公共预览 runner 做额外兼容性检查。

每个平台以真实模拟器运行隔离的 Debug 样例，生成首页、聊天、代码、侧栏、模型、设置、语音、暗色和键盘状态共 9 张截图。样例代码仅存在于 DEBUG，不进入 Release IPA，也不读取或写入实际聊天/Keychain 数据。

最终验收结果和真实截图链接必须以成功的构建为准。编译、截图生成和人工截图检查不能证明官方客户端像素级一致；目前用户未提供特定官方版本的完整截图。未验证的平台不会被标记为已经通过。
