import Foundation
import Synchronization

struct Metrics: Codable, Sendable {
 let total: Int
 let network: Int
 let cache: Int
 let unknown: Int
 let redirects: Int
}
final class ProbeDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
 let result = Mutex<Metrics?>(nil)
 func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
  let snapshot = Metrics(total: metrics.transactionMetrics.count,
   network: metrics.transactionMetrics.filter { $0.resourceFetchType == .networkLoad }.count,
   cache: metrics.transactionMetrics.filter { $0.resourceFetchType == .localCache }.count,
   unknown: metrics.transactionMetrics.filter { $0.resourceFetchType == .unknown }.count,
   redirects: metrics.redirectCount)
  result.withLock { $0 = snapshot }
 }
 func wait() async throws -> Metrics? {
  let deadline = ContinuousClock.now.advanced(by: .seconds(5))
  while ContinuousClock.now < deadline {
   if let snapshot = result.withLock({ $0 }) { return snapshot }
   try await Task.sleep(for: .milliseconds(50))
  }
  return nil
 }
}
struct Result: Codable {
 let route: String
 let sawBody: Bool
 let explicitCancel: Bool
 let metrics: Metrics?
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
   let delegate = ProbeDelegate()
   let (bytes, response) = try await session.bytes(for: URLRequest(url: URL(string: "http://127.0.0.1:" + port + "/" + route)!), delegate: delegate)
   precondition((response as? HTTPURLResponse)?.statusCode == 200)
   var sawBody = false
   for try await line in bytes.lines {
    if line.hasPrefix("data: synthetic") { sawBody = true }
    if route == "cancel" && sawBody { bytes.task.cancel(); break }
   }
   results.append(Result(route: route, sawBody: sawBody, explicitCancel: route == "cancel", metrics: try await delegate.wait()))
  }
  let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  print(String(decoding: try encoder.encode(results), as: UTF8.self))
 }
}
