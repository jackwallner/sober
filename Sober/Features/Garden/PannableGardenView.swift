import SwiftUI

/// Hosts `GardenSceneView` in a world larger than the viewport so the garden
/// can be dragged and pinch-zoomed — you actually explore your growth instead
/// of squinting at a 300pt box.
struct PannableGardenView: View {
    let days: Int
    let vitality: Double
    let activeBonsaiStyleID: String
    let isPro: Bool
    var completedTreeStyles: [String] = []
    var onSwapBonsai: (() -> Void)? = nil

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 3.0

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1.0
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size
            // The world matches the viewport so the whole garden — every placed
            // asset — is framed and centered at base zoom. Panning only unlocks
            // once you pinch-zoom in (clampOffset returns .zero while it fits),
            // so you can't drag off into empty space.
            let worldW = viewport.width
            let worldH = viewport.height
            let liveScale = clampScale(scale * pinch)
            let liveOffset = clampOffset(
                CGSize(width: offset.width + drag.width,
                       height: offset.height + drag.height),
                scale: liveScale,
                world: CGSize(width: worldW, height: worldH),
                viewport: viewport
            )

            ZStack {
                GardenSceneView(
                    days: days,
                    vitality: vitality,
                    activeBonsaiStyleID: activeBonsaiStyleID,
                    isPro: isPro,
                    completedTreeStyles: completedTreeStyles,
                    onSwapBonsai: onSwapBonsai
                )
                .frame(width: worldW, height: worldH)
                .scaleEffect(liveScale)
                .offset(liveOffset)
            }
            .frame(width: viewport.width, height: viewport.height)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offset = clampOffset(
                            CGSize(width: offset.width + value.translation.width,
                                   height: offset.height + value.translation.height),
                            scale: scale,
                            world: CGSize(width: worldW, height: worldH),
                            viewport: viewport
                        )
                    }
                    .simultaneously(with:
                        MagnificationGesture()
                            .updating($pinch) { value, state, _ in state = value }
                            .onEnded { value in
                                scale = clampScale(scale * value)
                                offset = clampOffset(
                                    offset,
                                    scale: scale,
                                    world: CGSize(width: worldW, height: worldH),
                                    viewport: viewport
                                )
                            }
                    )
            )
            .overlay(alignment: .bottomTrailing) {
                if scale > minScale || offset != .zero {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            scale = minScale
                            offset = .zero
                        }
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                            .font(Theme.body())
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(12)
                    .transition(.opacity)
                }
            }
        }
    }

    private func clampScale(_ s: CGFloat) -> CGFloat {
        min(maxScale, max(minScale, s))
    }

    private func clampOffset(_ o: CGSize, scale: CGFloat, world: CGSize, viewport: CGSize) -> CGSize {
        let maxX = max(0, (world.width * scale - viewport.width) / 2)
        let maxY = max(0, (world.height * scale - viewport.height) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, o.width)),
            height: min(maxY, max(-maxY, o.height))
        )
    }
}
