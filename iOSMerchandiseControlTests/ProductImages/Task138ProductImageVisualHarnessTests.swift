#if DEBUG
import SwiftUI
import UIKit
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task138ProductImageVisualHarnessTests: XCTestCase {
    func testSixRequiredVisualStatesRenderAsPhoneSnapshots() throws {
        let expectedStates: [Task138ProductImageVisualState] = [
            .list,
            .detailThumbnail,
            .detailMain,
            .editorPicker,
            .offlineCache,
            .errorFallback
        ]
        XCTAssertEqual(Task138ProductImageVisualState.allCases.count, 6)
        XCTAssertEqual(Set(expectedStates), Set(Task138ProductImageVisualState.allCases))

        for state in expectedStates {
            let size = CGSize(width: 390, height: 844)
            let content = Task138ProductImageVisualHarness(state: state)
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(.light)
            let controller = UIHostingController(rootView: content)
            controller.overrideUserInterfaceStyle = .light
            controller.loadViewIfNeeded()
            controller.view.frame = CGRect(origin: .zero, size: size)
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))

            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let png = try XCTUnwrap(image.pngData())
            XCTAssertGreaterThan(png.count, 20_000, "Snapshot \(state.rawValue) appears empty.")

            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = "TASK-138-iOS-\(state.rawValue).png"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testVisualLaunchEnvironmentAcceptsOnlySixStableValues() {
        for state in Task138ProductImageVisualState.allCases {
            XCTAssertEqual(
                Task138ProductImageVisualState(environmentValue: "  \(state.rawValue.uppercased())  "),
                state
            )
        }
        XCTAssertNil(Task138ProductImageVisualState(environmentValue: nil))
        XCTAssertNil(Task138ProductImageVisualState(environmentValue: ""))
        XCTAssertNil(Task138ProductImageVisualState(environmentValue: "unknown"))
    }
}
#endif
