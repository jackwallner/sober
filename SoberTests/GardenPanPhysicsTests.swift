import CoreGraphics
import Testing
@testable import Sober

@Suite("Garden pan physics")
struct GardenPanPhysicsTests {
    @Test func insideTheEdgesTheGardenFollowsTheFinger() {
        #expect(GardenPanPhysics.rubberBand(40, limit: 100, dimension: 300) == 40)
        #expect(GardenPanPhysics.rubberBand(-100, limit: 100, dimension: 300) == -100)
    }

    @Test func pastAnEdgeItMovesLessAndNeverReachesTheViewport() {
        let small = GardenPanPhysics.rubberBand(150, limit: 100, dimension: 300) - 100
        let large = GardenPanPhysics.rubberBand(1100, limit: 100, dimension: 300) - 100
        #expect(small > 0 && small < 50)
        #expect(large > small && large < 300)
        #expect(GardenPanPhysics.rubberBand(-150, limit: 100, dimension: 300) == -GardenPanPhysics.rubberBand(150, limit: 100, dimension: 300))
    }

    @Test func atBaseZoomThereIsNothingToPanTo() {
        let limits = GardenPanPhysics.limits(scale: 1, world: CGSize(width: 300, height: 300), viewport: CGSize(width: 300, height: 300))
        #expect(limits == .zero)
        #expect(GardenPanPhysics.limits(scale: 2, world: CGSize(width: 300, height: 200), viewport: CGSize(width: 300, height: 200)) == CGSize(width: 150, height: 100))
    }

    @Test func aFlickCoastsAboutHalfItsSpeedAndStopsAtTheEdge() {
        #expect(abs(GardenPanPhysics.projection(velocity: 1000) - 499) < 0.01)
        #expect(GardenPanPhysics.target(from: 0, velocity: 100, limit: 150) > 49)
        #expect(GardenPanPhysics.target(from: 0, velocity: 5000, limit: 150) == 150)
        #expect(GardenPanPhysics.target(from: 0, velocity: -5000, limit: 150) == -150)
        #expect(GardenPanPhysics.target(from: 20, velocity: 0, limit: 150) == 20)
    }

    @Test func pinchPastTheLimitsResistsAndStaysNearThem() {
        #expect(GardenPanPhysics.rubberBandScale(2, min: 1, max: 3) == 2)
        let over = GardenPanPhysics.rubberBandScale(6, min: 1, max: 3)
        let under = GardenPanPhysics.rubberBandScale(0.5, min: 1, max: 3)
        #expect(over > 3 && over < 4)
        #expect(under < 1 && under > 0.75)
    }
}
