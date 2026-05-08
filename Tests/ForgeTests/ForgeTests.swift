import XCTest
@testable import Forge

final class ForgeTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(ForgeVersion.value.isEmpty)
    }

    @MainActor
    func testTickComputesTokensPerSecond() async throws {
        let forge = Forge.shared
        forge.reset()
        forge.beginGeneration()
        for _ in 0..<10 {
            forge.tick()
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        forge.endGeneration()
        XCTAssertGreaterThan(forge.autoTokensPerSecond, 0)
        XCTAssertEqual(forge.generatedTokens, 10)
    }

    func testSnapshotIsAssignable() {
        var snap = ForgeSnapshot.empty
        snap.modelName = "Test-Model"
        snap.contextWindow = 4096
        XCTAssertEqual(snap.modelName, "Test-Model")
        XCTAssertEqual(snap.contextWindow, 4096)
    }
}
