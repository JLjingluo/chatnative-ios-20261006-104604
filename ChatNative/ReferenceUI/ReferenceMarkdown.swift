import SwiftUI
import UIKit
import ChatGPTUI
import Markdown

/// Uses the actual ChatGPTUI Markdown parser and attributed-content renderer.
struct ReferenceMarkdownContent: View {
    let text: String
    @State private var result: ChatGPTUI.ParserResult?
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Group {
            if let result { ChatGPTUI.AttributedView(results: [result]) }
            else { SwiftUI.Text(text).textSelection(.enabled) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: "\(text)|\(dynamicType)|\(scheme)") {
            var parser = ChatGPTUI.MarkdownAttributedStringParser()
            let string = parser.attributedString(from: Document(parsing: text))
            let attributed = (try? AttributedString(string, including: \.uiKit)) ?? AttributedString(text)
            result = ChatGPTUI.ParserResult(attributedString: attributed, isCodeBlock: false, codeBlockLanguage: nil)
        }
    }
}

struct ReferenceHighlightedCode: View {
    let code: String
    let language: String
    @State private var rendered: AttributedString?
    var body: some View {
        SwiftUI.Text(rendered ?? AttributedString(code))
            .font(.system(size: 13, design: .monospaced)).lineSpacing(5).textSelection(.enabled)
            .task(id: code + language) {
                var parser = ChatGPTUI.MarkdownAttributedStringParser()
                let string = NSMutableAttributedString(attributedString: parser.attributedString(from: Document(parsing: "```\(language)\n\(code)\n```")))
                string.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: NSRange(location: 0, length: string.length))
                rendered = (try? AttributedString(string, including: \.uiKit)) ?? AttributedString(code)
            }
    }
}
