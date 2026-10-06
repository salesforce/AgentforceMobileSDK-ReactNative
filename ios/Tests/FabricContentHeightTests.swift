import UIKit
import XCTest

private final class TestRCTRootComponentView: UIView {}

final class FabricContentHeightTests: XCTestCase {
    func testFindsMountedComponentHeightBeyondOnePointHost() {
        let surface = UIView(frame: CGRect(x: 0, y: 0, width: 334, height: 1))
        let root = UIView(frame: surface.bounds)
        let component = TestRCTRootComponentView(frame: CGRect(x: 0, y: 0, width: 334, height: 160))
        surface.addSubview(root)
        root.addSubview(component)

        XCTAssertEqual(FabricContentHeight.height(in: surface), 160)

        component.frame.size.height = 240
        XCTAssertEqual(FabricContentHeight.height(in: surface), 240)

        component.frame.size.height = 1
        XCTAssertEqual(FabricContentHeight.height(in: surface), 1)

        component.frame.size.height = 0
        XCTAssertEqual(FabricContentHeight.height(in: surface), 0)
    }

    func testReturnsNilBeforeFabricComponentMounts() {
        let surface = UIView(frame: CGRect(x: 0, y: 0, width: 334, height: 1))
        XCTAssertNil(FabricContentHeight.height(in: surface))
    }
}
