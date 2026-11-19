import XCTest

final class BridgeViewComponentDataTests: XCTestCase {
    func testNameExtractionSupportsBothSDKComponentShapes() {
        struct CurrentComponent { let definition = "copilot/richText" }
        struct NewComponent { let name: String? }

        XCTAssertNil(BridgeViewComponentData.name(of: CurrentComponent()))
        XCTAssertEqual(BridgeViewComponentData.name(of: NewComponent(name: "body")), "body")
        XCTAssertNil(BridgeViewComponentData.name(of: NewComponent(name: nil)))
    }

    func testNestedComponentProps() {
        let child = BridgeViewComponentData(
            definition: "copilot/richText",
            name: "body",
            properties: ["value": "Hello"],
            subComponents: []
        )
        let parent = BridgeViewComponentData(
            definition: "copilot/list",
            name: "result",
            properties: ["count": 1],
            subComponents: [child]
        )

        let props = parent.props
        XCTAssertEqual(props["definition"] as? String, "copilot/list")
        XCTAssertEqual(props["name"] as? String, "result")
        XCTAssertEqual((props["properties"] as? [String: Int])?["count"], 1)

        let children = props["subComponents"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 1)
        XCTAssertEqual(children?.first?["definition"] as? String, "copilot/richText")
        XCTAssertEqual(children?.first?["name"] as? String, "body")
        XCTAssertEqual((children?.first?["properties"] as? [String: String])?["value"], "Hello")
        XCTAssertNil(children?.first?["subComponents"])
    }

    func testOptionalFieldsAreOmitted() {
        let component = BridgeViewComponentData(
            definition: "copilot/markdown",
            name: nil,
            properties: [:],
            subComponents: []
        )

        XCTAssertNil(component.props["name"])
        XCTAssertNil(component.props["subComponents"])
        XCTAssertNotNil(component.props["properties"])
    }
}
