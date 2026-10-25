import Foundation
import CoreFoundation
import XCTest
import GRDB

private enum ActualExportValue {
    static func exportValue(_ value: DatabaseValue) -> Any {
        // Preserve SQLite storage, rather than testing coercions in order:
        // Bool accepts every integer/real, and String accepts UTF-8 blobs.
        // SQLite booleans remain their stored 0/1 integers in this raw export.
        switch value.storage {
        case .null: return NSNull()
        case .int64(let number): return number
        case .double(let number): return number
        case .string(let text): return text
        case .blob(let data): return data.base64EncodedString()
        }
    }
}
final class ExportValueProbeTests: XCTestCase {
    func testActualExportConversionPreservesIntegerRealTextBlobAndNull() throws {
        let payload: [String: Any] = [
            "count": ActualExportValue.exportValue(Int64(12).databaseValue),
            "zero": ActualExportValue.exportValue(Int64(0).databaseValue),
            "real": ActualExportValue.exportValue(Double(1.25).databaseValue),
            "text": ActualExportValue.exportValue("body".databaseValue),
            "blob": ActualExportValue.exportValue(Data("body".utf8).databaseValue),
            "null": ActualExportValue.exportValue(DatabaseValue.null)
        ]
        let encoded = try JSONSerialization.data(withJSONObject: payload)
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let count = try XCTUnwrap(result["count"] as? NSNumber)
        XCTAssertNotEqual(CFGetTypeID(count), CFBooleanGetTypeID())
        XCTAssertEqual(count.int64Value, 12)
        let zero = try XCTUnwrap(result["zero"] as? NSNumber)
        XCTAssertNotEqual(CFGetTypeID(zero), CFBooleanGetTypeID())
        XCTAssertEqual(zero.int64Value, 0)
        XCTAssertEqual((result["real"] as? NSNumber)?.doubleValue, 1.25)
        XCTAssertEqual(result["text"] as? String, "body")
        XCTAssertEqual(result["blob"] as? String, Data("body".utf8).base64EncodedString())
        XCTAssertTrue(result["null"] is NSNull)
    }
}
