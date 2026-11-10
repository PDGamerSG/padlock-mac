// Assertion adapter for running ConfigurationTests without the XCTest framework.
// It executes the same test methods against the unchanged application sources.
import Foundation

var assertionsRun = 0
var testsRun = 0
var failures = 0

class XCTestCase {
    func setUpWithError() throws {}
    func tearDown() {}
}

func fail(_ message: String, file: StaticString, line: UInt) {
    failures += 1
    print("FAIL \(file):\(line): \(message)")
}
func XCTAssertTrue(_ condition: @autoclosure () -> Bool, _ message: String = "",
                   file: StaticString = #filePath, line: UInt = #line) {
    assertionsRun += 1
    if !condition() { fail("Expected true. \(message)", file: file, line: line) }
}
func XCTAssertFalse(_ condition: @autoclosure () -> Bool, _ message: String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(!condition(), message, file: file, line: line)
}
func XCTAssertEqual<T: Equatable>(_ actual: @autoclosure () -> T, _ expected: @autoclosure () -> T,
                                  _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    assertionsRun += 1
    let a = actual(), e = expected()
    if a != e { fail("\(a) != \(e). \(message)", file: file, line: line) }
}
func XCTAssertNil<T>(_ value: @autoclosure () -> T?, _ message: String = "",
                      file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(value() == nil, message, file: file, line: line)
}
func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, _ message: String = "",
                         file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(value() != nil, message, file: file, line: line)
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T,
                             file: StaticString = #filePath, line: UInt = #line) {
    assertionsRun += 1
    do { _ = try expression(); fail("Expected an error", file: file, line: line) } catch {}
}
func XCTUnwrap<T>(_ value: @autoclosure () throws -> T?, file: StaticString = #filePath,
                  line: UInt = #line) throws -> T {
    assertionsRun += 1
    guard let unwrapped = try value() else {
        fail("Unexpected nil", file: file, line: line)
        throw NSError(domain: "PadlockTest", code: 1)
    }
    return unwrapped
}
func run<T: XCTestCase>(_ name: String, instance: T, body: (T) throws -> Void) {
    testsRun += 1
    let before = failures
    do { try instance.setUpWithError(); try body(instance) }
    catch { fail("\(name): \(error)", file: #filePath, line: #line) }
    instance.tearDown()
    print("\(before == failures ? "PASS" : "FAIL") \(name)")
}
