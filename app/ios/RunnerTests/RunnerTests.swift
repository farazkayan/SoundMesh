import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

    func testFrameDecoderDecodesShortPayload() {
        let decoder = FrameDecoder()
        let frame = makeFrame("PING")
        let messages = decoder.append(frame)
        XCTAssertEqual(messages, ["PING"])
    }

    func testFrameDecoderDecodesLongerPayload() {
        let decoder = FrameDecoder()
        let frame = makeFrame("HELLO")
        let messages = decoder.append(frame)
        XCTAssertEqual(messages, ["HELLO"])
    }

    func testFrameDecoderDecodesWhenHeaderAndPayloadAreSplitAcrossReads() {
        let decoder = FrameDecoder()
        let frame = makeFrame("PING")
        var messages: [String] = []

        messages += decoder.append(frame.subdata(in: 0..<2))
        messages += decoder.append(frame.subdata(in: 2..<6))
        messages += decoder.append(frame.subdata(in: 6..<8))

        XCTAssertEqual(messages, ["PING"])
    }

    func testFrameDecoderDecodesLongerPayloadWhenReadCrossesHeaderBoundary() {
        let decoder = FrameDecoder()
        let frame = makeFrame("HELLO")
        var messages: [String] = []

        messages += decoder.append(frame.subdata(in: 0..<1))
        messages += decoder.append(frame.subdata(in: 1..<6))
        messages += decoder.append(frame.subdata(in: 6..<9))

        XCTAssertEqual(messages, ["HELLO"])
    }

    func testFrameDecoderResetsStateBetweenConsecutiveFrames() {
        let decoder = FrameDecoder()
        let frames = makeFrame("PING") + makeFrame("HELLO")
        let messages = decoder.append(frames)
        XCTAssertEqual(messages, ["PING", "HELLO"])
    }

    func testFrameDecoderResetsAfterInvalidLengthAndReadsNextFrame() {
        let decoder = FrameDecoder()
        let invalidHeader = Data([0, 0, 0, 0])
        let validFrame = makeFrame("PING")
        let messages = decoder.append(invalidHeader + validFrame)
        XCTAssertEqual(messages, ["PING"])
    }

    private func makeFrame(_ payload: String) -> Data {
        let payloadData = payload.data(using: .utf8)!
        var frame = Data()
        var length = UInt32(payloadData.count).bigEndian
        frame.append(Data(bytes: &length, count: 4))
        frame.append(payloadData)
        return frame
    }

    func testExample() {
        // If you add code to the Runner application, consider adding tests here.
        // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
    }

}
