# 验证记录

日期：2026-10-06。环境：Debian 13 / Linux，Swift 6.1.2，Swift Package 5.9 语言配置。

| 检查 | 实际结果 |
| --- | --- |
| `swift test` | 12 项 XCTest 测试通过，0 失败 |
| API 核心编译 | Models.swift、OpenAIClient.swift 的可移植部分通过 Swift 编译 |
| 全部 App Swift 文件的 `swiftc -frontend -parse` | 通过语法解析 |
| Xcode 工程结构 | 58 个对象引用正确，源码均已列入工程 |
| 共享 scheme / Info.plist / 隐私清单 / 资源 | XML、plist、JSON 与图标路径检查通过 |
| iOS SDK 编译、SwiftUI 类型检查 | GitHub Actions macOS runner 上 iPhone Release 构建通过 |
| iOS 模拟器 / 真机 / 截图对比 | 未执行 |
| 真实 API 请求、Keychain 和麦克风授权 | 未执行：无用户提供的服务配置或 iOS 设备 |

测试覆盖接口路径归一化、地址与凭据验证、请求参数、系统提示词、图片 data URL、图片能力声明、上下文边界、错误脱敏、数据序列化、SSE CRLF/多行/注释、Unicode 字节消费、结束标记、未终止的最后事件、空响应及取消。

Linux Swift Package 测试输出末尾的 “Testing Library: 0 tests” 指 Swift Testing 框架没有测试；本工程使用 XCTest，其 12 项测试在前面的 XCTest 结果中实际执行并全部通过。

工程结构检查依赖仅用于开发校验，可安装后运行：

```bash
python3 -m pip install openstep-parser
python3 scripts/validate_project.py
```

iOS 构建和真机验收命令在 README 中。协议测试不能证明所有兼容服务均可使用，也不能替代真实 iOS 编译。未宣称官方客户端像素级一致或已上架。

## 未签名 IPA 构建流程补充

新增 macOS GitHub Actions 工作流与打包脚本。工作流 YAML 结构检查、Bash 语法检查通过；Linux 环境执行脚本时按预期拒绝构建。工作流已在远程仓库运行成功，产出未签名 IPA。下载入口：https://github.com/JLjingluo/chatnative-ios-20261006-104604/actions/runs/37451975683/artifacts/11406444487。

## 远程 iOS 构建实测

- 构建记录：https://github.com/JLjingluo/chatnative-ios-20261006-104604/actions/runs/37451975683
- 编译源码提交：`b6455d2cc73665f8018f00a3b5ee3b00f9d401a6`
- macOS Apple 平台核心测试：通过。
- iPhone Release 编译与打包：通过。
- 脚本已检查 arm64 可执行文件、无应用代码签名、IPA ZIP 完整性。
- GitHub artifact 已保存 IPA 和 SHA-256 校验文件。
- 当前环境代理拒绝 GitHub 产物存储地址，所以未在本地重新下载和独立解析 Mach-O。
- 未进行真机运行、真实上游 API 调用或截图对齐验收。
