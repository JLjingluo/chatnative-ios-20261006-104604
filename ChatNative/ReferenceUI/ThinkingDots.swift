// Adapted from Alfian Losari's ChatGPTSwiftUI Shared/DotLoadingView.swift.
// Copyright (c) 2023 Alfian Losari. MIT license: ThirdParty/ChatGPTSwiftUI-LICENSE.txt.
// TimelineView replaces the upstream endlessly recurring timers and observes Reduce Motion.
import SwiftUI

struct ChatGPTThinkingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: reduceMotion)) { context in
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle().fill(.primary.opacity(reduceMotion || Int(context.date.timeIntervalSince1970 * 3) % 3 == index ? 0.8 : 0.22))
                        .frame(width: 6, height: 6)
                }
            }.frame(height: 22)
        }.accessibilityLabel("正在生成回复")
    }
}
