import XCTest
@testable import Forge

final class ForgeTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(Forge.version.isEmpty)
    }
}
