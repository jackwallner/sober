import Foundation
import Observation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Sober

@Suite("Home day refresh", .serialized)
@MainActor
struct HomeDayRefreshTests {
    @Observable
    @MainActor
    fileprivate final class Probe {
        var phase = ScenePhase.active
        var now = DateHelpers.startOfDay(Date(timeIntervalSince1970: 1_756_000_000))
        var checkedIn = false
        var slip = false
        var missed = 0
        var week: [TendedDay] = []
        let service: CheckInService

        init(service: CheckInService) {
            self.service = service
        }

        func refresh() {
            checkedIn = service.hasCheckedIn(on: now)
            slip = service.loggedSlip(on: now)
            missed = service.daysSinceLastCheckIn(asOf: now)
            week = TendedWeek.days(
                endingOn: now,
                facts: service.facts(from: DateHelpers.daysAgo(6, from: now), to: now)
            )
        }
    }

    private struct Harness: View {
        let probe: Probe

        var body: some View {
            Color.clear
                .modifier(HomeDayRefresh(perform: probe.refresh))
                .environment(\.scenePhase, probe.phase)
        }
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(150))
    }

    @Test(arguments: [Notification.Name.NSCalendarDayChanged, UIApplication.significantTimeChangeNotification])
    func mountedHomeRefreshesAtMidnight(notification: Notification.Name) async throws {
        let container = try ModelContainer(for: DailyCheckIn.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let probe = Probe(service: CheckInService(context: container.mainContext))
        probe.service.checkIn(for: probe.now, wasSober: false)
        probe.refresh()
        #expect(probe.checkedIn && probe.slip)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: Harness(probe: probe))
        window.isHidden = false
        defer { window.isHidden = true }
        try await settle()

        probe.now = DateHelpers.daysAgo(-1, from: probe.now)
        NotificationCenter.default.post(name: notification, object: nil)
        try await settle()

        #expect(!probe.checkedIn)
        #expect(!probe.slip)
        #expect(probe.missed == 1)
        #expect(probe.week.last?.day == probe.now)
        #expect(probe.week.last?.mark == .blank)
        #expect(probe.week.dropLast().last?.mark == .slip)
    }

    @Test func mountedHomeRefreshesOnNextMorningResume() async throws {
        let container = try ModelContainer(for: DailyCheckIn.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let probe = Probe(service: CheckInService(context: container.mainContext))
        probe.service.checkIn(for: probe.now)
        probe.refresh()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: Harness(probe: probe))
        window.isHidden = false
        defer { window.isHidden = true }
        try await settle()

        probe.phase = .background
        try await settle()
        probe.now = DateHelpers.daysAgo(-3, from: probe.now)
        probe.phase = .active
        try await settle()

        #expect(!probe.checkedIn)
        #expect(probe.missed == 3)
        #expect(probe.week.last?.day == probe.now)
        #expect(probe.week.last?.mark == .blank)
    }
}
