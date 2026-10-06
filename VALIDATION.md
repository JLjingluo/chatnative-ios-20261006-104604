# 1.1.0 验证记录

日期：2026-10-06。

| 检查 | 结果 |
| --- | --- |
| 本地 Linux Swift 6.1.2 核心测试 | 12 项 XCTest 通过 |
| 项目结构与资源 | 74 个对象、18 个应用 Swift 文件、共享 scheme、plist 和资源通过检查 |
| Apple 平台核心测试 | Xcode 26.3 和 Xcode 27 预览 runner 均通过 |
| iPhone Release 编译 | iOS 26 SDK 和 iOS 27 预览 SDK 均通过 |
| iOS 26 / 27 模拟器与截图 | 两组共 18 张截图已生成并人工查看；普通键盘交互仍未验收 |
| 真实 iPhone 安装、上游 API、麦克风和 Keychain 使用 | 未执行；没有设备和 OpenAI 兼容服务配置 |

测试覆盖接口路径归一化、请求参数、系统提示词、图片 data URL、上下文边界、错误脱敏、序列化、SSE CRLF/多行/注释、Unicode、结束标记、尾部事件、空响应及取消。GitHub 令牌只用于仓库操作，不是 OpenAI 兼容 API 的凭据。

真实模拟器截图使用隔离的 DEBUG 样例，不会访问或修改用户聊天与 Keychain，Release 不包含样例代码。截图可以验证布局与渲染，但没有官方目标版本截图，不能证明官方界面的像素级一致性。

## 构建与下载

- [成功构建](https://github.com/JLjingluo/chatnative-ios-20261006-104604/actions/runs/37461378075)，应用源码提交 `8234c2ff3413d8176325e535dd8a86c6e375fca2`。
- [单独下载 IPA](https://github.com/JLjingluo/chatnative-ios-20261006-104604/releases/download/unsigned-5/ChatNative-unsigned.ipa)，版本 1.1.0，SDK `iphoneos26.2`，文件大小 4554706 字节。
- 匿名下载 HTTP 200；本地 ZIP 完整性、Mach-O arm64 / iOS 平台、无 LC_CODE_SIGNATURE / _CodeSignature / embedded.mobileprovision 全部通过。
- SHA-256：`9ba6acbf3ccc78efe13b34b942b80826168a6e2c5a25e5da2e3ba11bf36af798`，与 runner 校验报告一致。
- [两平台真实 UI 截图](UI_PREVIEWS.md)：首页、聊天、代码高亮、侧栏、模型、设置、语音和暗色均正常渲染；没有发现主要控件互相遮挡。
- 键盘模式触发了新模拟器的滑行输入首次使用提示；可确认焦点、多行输入、发送按钮与安全区域移动，但不能据此声称普通键盘输入/交互已验收。
- 18 张图是静态模拟器截图，不构成动画、触摸、VoiceOver、大字体、iPad 或实际麦克风功能验收。

## 已修正的模拟器问题

前两次 UI 构建的真机 Release 已成功，但 Debug 模拟器的 App 与依赖使用不同架构，导致 ChatGPTUI / Markdown 模块无法加载。已将 Debug 配置设为 `ONLY_ACTIVE_ARCH=YES`，截图脚本显式选择当前 runner 的架构。没有用真机构建成功代替截图验证。
