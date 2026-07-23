import SwiftUI
import UIKit

// Rendered as a plain overlay inside ConversationView, not a system
// sheet or `.fullScreenCover` — a system cover removes/obscures what's
// behind it, which would leave the blur below with nothing real to
// blur. Staying in the same view tree is what lets the background
// actually show (softened) glimpses of the real conversation instead
// of a flat color. `onClose` replaces `@Environment(\.dismiss)` since
// this view is no longer presented modally.
struct LightboxView: View {
    let image: UIImage
    let onClose: () -> Void

    // Shared with the slider in Settings via the same @AppStorage key —
    // no plumbing needed, UserDefaults keeps the two in sync.
    @AppStorage("lightboxBackgroundBlur") private var backgroundBlur: Double = 0.55

    @GestureState private var pinchDelta: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @GestureState private var dragDelta: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private var isZoomed: Bool { committedScale > 1.01 }
    private var displayScale: CGFloat { committedScale * pinchDelta }
    private var displayOffset: CGSize {
        guard isZoomed else { return .zero }
        return CGSize(
            width: committedOffset.width + dragDelta.width,
            height: committedOffset.height + dragDelta.height
        )
    }

    var body: some View {
        ZStack {
            background
                .onTapGesture { if !isZoomed { onClose() } }

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
                .scaleEffect(displayScale)
                .offset(displayOffset)
                .gesture(magnification)
                .simultaneousGesture(drag)
                .onTapGesture(count: 2) { toggleZoom() }
                .onTapGesture { if !isZoomed { onClose() } }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 4)
                    .padding()
            }
        }
    }

    // A fixed system Material as the base blur, plus a variable-opacity
    // black layer on top — the slider in Settings drives that second
    // layer, from mostly see-through at 0 up to essentially solid at 1.
    // `Material` itself only ships a handful of fixed steps (ultraThin
    // … ultraThick), so this is what turns that into an actually
    // continuous "how much do you want to see behind it" control.
    private var background: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color.black.opacity(backgroundBlur * 0.85)
        }
        .ignoresSafeArea()
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .updating($pinchDelta) { value, state, _ in state = value }
            .onEnded { value in
                let newScale = committedScale * value
                committedScale = min(max(newScale, 1), 5)
                if committedScale <= 1 { committedOffset = .zero }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .updating($dragDelta) { value, state, _ in state = value.translation }
            .onEnded { value in
                guard isZoomed else { return }
                committedOffset.width += value.translation.width
                committedOffset.height += value.translation.height
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if isZoomed {
                committedScale = 1
                committedOffset = .zero
            } else {
                committedScale = 2.5
            }
        }
    }
}
