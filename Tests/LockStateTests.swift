import Foundation
import Testing

struct LockStateTests {

    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func appIsLockedUntilUnlocked() {
        var state = LockState()
        #expect(state.needsUnlock("app", grace: 60, now: start))
        state.didUnlock("app")
        #expect(!state.needsUnlock("app", grace: 60, now: start))
    }

    @Test func staysUnlockedWhileInFocus() {
        var state = LockState()
        state.didUnlock("app")
        // No didLeave: hours later it's still the app you're using.
        #expect(!state.needsUnlock("app", grace: 0, now: start.addingTimeInterval(3600)))
    }

    @Test func relocksOnceAwayLongerThanGrace() {
        var state = LockState()
        state.didUnlock("app")
        state.didLeave("app", at: start)
        #expect(!state.needsUnlock("app", grace: 60, now: start.addingTimeInterval(59)))
        #expect(state.needsUnlock("app", grace: 60, now: start.addingTimeInterval(61)))
        // Once expired it stays locked, even within a fresh window.
        #expect(state.needsUnlock("app", grace: 60, now: start.addingTimeInterval(62)))
    }

    @Test func zeroGraceRelocksOnAnySwitch() {
        var state = LockState()
        state.didUnlock("app")
        state.didLeave("app", at: start)
        #expect(state.needsUnlock("app", grace: 0, now: start.addingTimeInterval(0.5)))
    }

    @Test func returningResetsTheGraceTimer() {
        var state = LockState()
        state.didUnlock("app")
        state.didLeave("app", at: start)
        #expect(!state.needsUnlock("app", grace: 60, now: start.addingTimeInterval(30)))
        state.didReturn("app")
        state.didLeave("app", at: start.addingTimeInterval(100))
        #expect(!state.needsUnlock("app", grace: 60, now: start.addingTimeInterval(150)))
    }

    @Test func nilGraceLastsUntilQuit() {
        var state = LockState()
        state.didUnlock("app")
        state.didLeave("app", at: start)
        #expect(!state.needsUnlock("app", grace: nil, now: start.addingTimeInterval(86_400)))
        state.forget("app")
        #expect(state.needsUnlock("app", grace: nil, now: start))
    }

    @Test func leavingWhileLockedStartsNoTimer() {
        var state = LockState()
        state.didLeave("app", at: start)
        state.didUnlock("app")
        #expect(!state.needsUnlock("app", grace: 60, now: start.addingTimeInterval(3600)))
    }

    @Test func relockAllForgetsEveryUnlock() {
        var state = LockState()
        state.didUnlock("a")
        state.didUnlock("b")
        state.relockAll()
        #expect(state.needsUnlock("a", grace: nil, now: start))
        #expect(state.needsUnlock("b", grace: nil, now: start))
    }
}
