import Foundation
import Synchronization

final class MetricBox: Sendable { let result = Mutex<MentorHTTPMetrics?>(nil) }
final class MetricsReceipt: Sendable {
 private let box: MetricBox
 let delegate: MentorHTTPMetricsDelegate
 init() {
  let box = MetricBox()
  self.box = box
  delegate = MentorHTTPMetricsDelegate { metrics in box.result.withLock { $0 = metrics } }
 }
 func wait() async throws -> MentorHTTPMetrics? {
  let deadline = ContinuousClock.now.advanced(by: .seconds(5))
  while ContinuousClock.now < deadline {
   if let snapshot = box.result.withLock({ $0 }) { return snapshot }
   try await Task.sleep(for: .milliseconds(50))
  }
  return nil
 }
}
struct Result: Codable {
 let route: String
 let sawBody: Bool
 let explicitCancel: Bool
 let metrics: MentorHTTPMetrics?
}
@main struct NativeMetricsProbe {
 static func main() async throws {
  let port = CommandLine.arguments[1]
  let config = URLSessionConfiguration.ephemeral
  config.timeoutIntervalForRequest = 10
  config.timeoutIntervalForResource = 12
  let session = URLSession(configuration: config)
  defer { session.invalidateAndCancel() }
  var results: [Result] = []
  for route in ["success", "redirect", "cancel"] {
   let receipt = MetricsReceipt()
   let (bytes, response) = try await session.bytes(for: URLRequest(url: URL(string: "http://127.0.0.1:" + port + "/" + route)!), delegate: receipt.delegate)
   precondition((response as? HTTPURLResponse)?.statusCode == 200)
   var sawBody = false
   for try await line in bytes.lines {
    if line.hasPrefix("data: synthetic") { sawBody = true }
    if route == "cancel" && sawBody { bytes.task.cancel(); break }
   }
   results.append(Result(route: route, sawBody: sawBody, explicitCancel: route == "cancel", metrics: try await receipt.wait()))
  }
  let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  print(String(decoding: try encoder.encode(results), as: UTF8.self))
 }
}
