@testable import FluidVoice_Debug
import Foundation
import XCTest

final class AudioEngineRetirementDrainTests: XCTestCase {
    func testReleaseAndWaitCompletesAfterOffMainDeinit() async throws {
        let drain = AudioEngineRetirementDrain(label: "test.audio-engine-retirement.single")
        let recorder = DeinitRecorder()
        var probe: DeinitProbe? = DeinitProbe(id: 1, recorder: recorder)
        let token = AudioEngineRetirementToken(try XCTUnwrap(probe))
        probe = nil

        await drain.releaseAndWait(token)

        XCTAssertEqual(recorder.ids, [1])
        XCTAssertEqual(recorder.mainThreadFlags, [false])
    }

    func testAwaitedReleaseRunsAfterPreviouslyScheduledRelease() async throws {
        let drain = AudioEngineRetirementDrain(label: "test.audio-engine-retirement.serial")
        let recorder = DeinitRecorder()
        var first: DeinitProbe? = DeinitProbe(id: 1, recorder: recorder)
        var second: DeinitProbe? = DeinitProbe(id: 2, recorder: recorder)
        let firstToken = AudioEngineRetirementToken(try XCTUnwrap(first))
        let secondToken = AudioEngineRetirementToken(try XCTUnwrap(second))
        first = nil
        second = nil

        drain.schedule(firstToken)
        await drain.releaseAndWait(secondToken)

        XCTAssertEqual(recorder.ids, [1, 2])
        XCTAssertEqual(recorder.mainThreadFlags, [false, false])
    }
}

private final class DeinitProbe {
    private let id: Int
    private let recorder: DeinitRecorder

    init(id: Int, recorder: DeinitRecorder) {
        self.id = id
        self.recorder = recorder
    }

    deinit {
        self.recorder.record(id: self.id, wasMainThread: Thread.isMainThread)
    }
}

private final class DeinitRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedIDs: [Int] = []
    private var recordedMainThreadFlags: [Bool] = []

    var ids: [Int] {
        self.lock.withLock { self.recordedIDs }
    }

    var mainThreadFlags: [Bool] {
        self.lock.withLock { self.recordedMainThreadFlags }
    }

    func record(id: Int, wasMainThread: Bool) {
        self.lock.withLock {
            self.recordedIDs.append(id)
            self.recordedMainThreadFlags.append(wasMainThread)
        }
    }
}
