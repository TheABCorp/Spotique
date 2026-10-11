import SwiftUI

extension Font {
    /// Price or rate emphasis — large title weight.
    static let priceEmphasis: Font = .title.bold()

    /// Secondary price text (e.g. "/hr").
    static let priceUnit: Font = .subheadline
}

extension View {
    /// Apply the standard body text style with brand charcoal color.
    func bodyStyle() -> some View {
        foregroundStyle(Color.onSurface)
            .font(.body)
    }

    /// Apply the secondary/caption text style.
    func captionStyle() -> some View {
        foregroundStyle(Color.onSurface.opacity(0.7))
            .font(.caption)
    }
}
