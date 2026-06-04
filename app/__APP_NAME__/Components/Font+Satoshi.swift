import SwiftUI

// Satoshi is the default app font. Use these helpers for all text styling.
// To override in a specific view, apply .font(...) directly on that view.

extension Font {
    // MARK: - Satoshi text-style scale (mirrors Apple's Dynamic Type sizes)

    static var satoshiLargeTitle: Font { .custom("Satoshi Variable", size: 34, relativeTo: .largeTitle) }
    static var satoshiTitle: Font { .custom("Satoshi Variable", size: 28, relativeTo: .title) }
    static var satoshiTitle2: Font { .custom("Satoshi Variable", size: 22, relativeTo: .title2) }
    static var satoshiTitle3: Font { .custom("Satoshi Variable", size: 20, relativeTo: .title3) }
    static var satoshiHeadline: Font { .custom("Satoshi Variable", size: 17, relativeTo: .headline) }
    static var satoshiBody: Font { .custom("Satoshi Variable", size: 17, relativeTo: .body) }
    static var satoshiCallout: Font { .custom("Satoshi Variable", size: 16, relativeTo: .callout) }
    static var satoshiSubheadline: Font { .custom("Satoshi Variable", size: 15, relativeTo: .subheadline) }
    static var satoshiFootnote: Font { .custom("Satoshi Variable", size: 13, relativeTo: .footnote) }
    static var satoshiCaption: Font { .custom("Satoshi Variable", size: 12, relativeTo: .caption) }
    static var satoshiCaption2: Font { .custom("Satoshi Variable", size: 11, relativeTo: .caption2) }

    // MARK: - Convenience factory for arbitrary sizes (Dynamic Type scaling preserved)

    static func satoshi(size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom("Satoshi Variable", size: size, relativeTo: style)
    }
}
