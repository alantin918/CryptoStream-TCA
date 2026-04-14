import Foundation
import Dependencies

/// A type representing a stream of raw WebSocket messages
public typealias WebSocketStream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>

/// The WebSocket Dependency Client.
/// Clean Architecture: Interface for the Domain/Reducer to consume without coupling to `URLSession`.
public struct WebSocketClient: Sendable {
    public var connect: @Sendable (_ url: URL) async throws -> WebSocketStream
    public var disconnect: @Sendable () async -> Void
    
    public init(
        connect: @escaping @Sendable (URL) async throws -> WebSocketStream,
        disconnect: @escaping @Sendable () async -> Void
    ) {
        self.connect = connect
        self.disconnect = disconnect
    }
}

extension WebSocketClient: DependencyKey {
    public static let liveValue: WebSocketClient = {
        // We use an underlying actor to manage the socket task state thread-safely
        actor WebSocketManager {
            private var task: URLSessionWebSocketTask?
            
            func connect(to url: URL) -> WebSocketStream {
                // Prevent multiple active connections on the same client
                self.task?.cancel(with: .normalClosure, reason: nil)
                
                let session = URLSession(configuration: .default)
                let task = session.webSocketTask(with: url)
                self.task = task
                task.resume()
                
                return AsyncThrowingStream { continuation in
                    let unmanagedTask = task
                    
                    // Task inherits Sendable checks and cleanly interfaces with URLSession's un-sendable completion
                    Task {
                        var isCancelled = false
                        while !isCancelled {
                            do {
                                let message = try await unmanagedTask.receive()
                                continuation.yield(message)
                            } catch {
                                continuation.finish(throwing: error)
                                isCancelled = true
                            }
                        }
                    }
                    
                    continuation.onTermination = { [weak task] _ in
                        task?.cancel(with: .normalClosure, reason: nil)
                    }
                }
            }
            
            func disconnect() {
                task?.cancel(with: .normalClosure, reason: nil)
                task = nil
            }
        }
        
        let manager = WebSocketManager()
        
        return WebSocketClient(
            connect: { url in
                return await manager.connect(to: url)
            },
            disconnect: {
                await manager.disconnect()
            }
        )
    }()
    
    // Preview & Test values can be provided here...
}

extension DependencyValues {
    public var webSocketClient: WebSocketClient {
        get { self[WebSocketClient.self] }
        set { self[WebSocketClient.self] = newValue }
    }
}
