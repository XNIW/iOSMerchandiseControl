#if DEBUG
import SwiftUI
import UIKit
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task138ProductImageVisualHarnessTests: XCTestCase {
    func testCameraFallbackRasterizationKeepsMainActorResponsiveAndProducesBoundedJPEG() async throws {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 4_000,
            height: 3_000,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.15, green: 0.45, blue: 0.75, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4_000, height: 3_000))
        let image = UIImage(cgImage: try XCTUnwrap(context.makeImage()))

        let heartbeat = expectation(description: "MainActor heartbeat while camera fallback runs")
        let processing = Task { @MainActor in
            try await ProductImageCameraPicker.Coordinator.writeBoundedCameraFallback(from: image)
        }
        DispatchQueue.main.async {
            heartbeat.fulfill()
        }
        await fulfillment(of: [heartbeat], timeout: 0.5)

        let fileURL = try await processing.value
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let data = try Data(contentsOf: fileURL)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let width = try XCTUnwrap((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue)
        let height = try XCTUnwrap((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue)
        XCTAssertLessThanOrEqual(max(width, height), ProductImageProcessor.mainMaximumSide)
        XCTAssertLessThanOrEqual(data.count, ProductImageProcessor.mainMaximumBytes)
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(data))
    }

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
            XCTAssertEqual(controller.view.bounds.size, size)
            XCTAssertFalse(controller.view.hasAmbiguousLayout)

            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            XCTAssertEqual(image.size, size)
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

    func testVisualHarnessPinsContentAndHeaderToViewportWidth() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("iOSMerchandiseControl/ProductImages/Task138ProductImageVisualHarness.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(#".containerRelativeFrame(.horizontal, alignment: .leading)"#))
        XCTAssertTrue(source.contains(#".contentMargins(20, for: .scrollContent)"#))
        XCTAssertTrue(source.contains(#".fixedSize(horizontal: false, vertical: true)"#))
        XCTAssertTrue(source.contains(#".frame(maxWidth: .infinity, alignment: .leading)"#))
    }
}
#endif
