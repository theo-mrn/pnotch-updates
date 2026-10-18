//
//  ClaudeCodeHookServer.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Darwin
import Foundation
import os

/// Receives Claude Code's hook events: a tiny HTTP server on a Unix socket in PNotch's Application Support
/// folder, readable and writable by the user only. The hook script posts each event with `curl --unix-socket`.
///
/// Events are answered right away. Permission requests are held open: the hook waits for the answer given
/// in the notch, sent with `reply(to:with:)`, or for none, which lets Claude Code ask in the terminal.
///
/// Everything happens on a private queue; deliveries are handed over as they complete.
nonisolated final class ClaudeCodeHookServer: @unchecked Sendable {
    struct Delivery: Sendable {
        let body: Data
        /// Header names are lowercased.
        let headers: [String: String]
        /// The process that posted the event and its ancestors: curl, the hook's shell, Claude Code, its terminal…
        /// Read on arrival, while curl still runs.
        let ancestry: [ProcessTree.Entry]
        /// Set for a permission request, which waits for `reply(to:with:)`.
        let replyID: ReplyID?
    }

    struct ReplyID: Hashable, Sendable {
        let rawValue: UInt64
    }

    enum ServerError: Error {
        case pathTooLong
        case socket(Int32)
    }

    static let eventsPath = "/claude-code/events"
    static let permissionPath = "/claude-code/permission"

    static var defaultSocketURL: URL {
        URL.applicationSupportDirectory
            .appending(path: Bundle.main.bundleIdentifier ?? "com.pnotch.PNotch", directoryHint: .isDirectory)
            .appending(path: "claude-code.sock")
    }

    /// Prompts can carry long pasted text; anything bigger is refused.
    static let maximumRequestLength = 8 * 1024 * 1024
    /// A client that stays silent longer is dropped.
    static let requestTimeout: DispatchTimeInterval = .seconds(5)
    /// How long a permission request waits for an answer from the notch. The hook's curl gives up a little later.
    static let replyTimeout: DispatchTimeInterval = .seconds(580)

    private let socketURL: URL
    private let onDelivery: @Sendable (Delivery) -> Void
    private let onAbandon: @Sendable (ReplyID) -> Void
    private let queue = DispatchQueue(label: "com.pnotch.claude-code-hooks")
    private var listener: DispatchSourceRead?
    private var connections: [UInt64: Connection] = [:]
    private var nextConnectionID: UInt64 = 0

    /// - Parameter onAbandon: A held permission request ended without an answer from the notch:
    ///   answered in the terminal, Claude Code interrupted, or waiting too long.
    init(
        socketURL: URL = defaultSocketURL,
        onDelivery: @escaping @Sendable (Delivery) -> Void,
        onAbandon: @escaping @Sendable (ReplyID) -> Void = { _ in }
    ) {
        self.socketURL = socketURL
        self.onDelivery = onDelivery
        self.onAbandon = onAbandon
    }

    deinit {
        listener?.cancel()
    }

    func start() throws {
        try queue.sync {
            guard listener == nil else { return }
            let descriptor = try makeListeningSocket()
            let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
            source.setEventHandler { [weak self] in
                self?.acceptConnections(on: descriptor)
            }
            source.setCancelHandler {
                close(descriptor)
            }
            source.resume()
            listener = source
        }
    }

    func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
            for connection in connections.values {
                connection.source.cancel()
            }
            connections.removeAll()
            unlink(socketURL.path(percentEncoded: false))
        }
    }

    /// Answers a held permission request: Claude Code's decision as JSON, or `nil` to let it ask in the terminal.
    func reply(to id: ReplyID, with body: Data?) {
        queue.async { [weak self] in
            guard let self, connections[id.rawValue]?.isWaitingForReply == true else { return }
            if let body {
                finish(id.rawValue, status: "200 OK", body: body)
            } else {
                finish(id.rawValue, status: "204 No Content")
            }
        }
    }

    // MARK: Listening

    private func makeListeningSocket() throws -> Int32 {
        let path = socketURL.path(percentEncoded: false)
        var address = sockaddr_un()
        let pathBytes = Array(path.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw ServerError.pathTooLong }

        try FileManager.default.createDirectory(at: socketURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // A socket left behind by a previous run would make bind fail.
        unlink(path)

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw ServerError.socket(errno) }

        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: pathBytes)
        }
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, chmod(path, 0o600) == 0, listen(descriptor, 16) == 0 else {
            let error = errno
            close(descriptor)
            throw ServerError.socket(error)
        }
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        return descriptor
    }

    private func acceptConnections(on listeningDescriptor: Int32) {
        while true {
            let descriptor = accept(listeningDescriptor, nil, nil)
            guard descriptor >= 0 else { return }
            _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
            var noSigPipe: Int32 = 1
            setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            nextConnectionID += 1
            track(Connection(id: nextConnectionID, descriptor: descriptor, ancestry: peerAncestry(of: descriptor), queue: queue))
        }
    }

    private func peerAncestry(of descriptor: Int32) -> [ProcessTree.Entry] {
        var pid: pid_t = 0
        var length = socklen_t(MemoryLayout<pid_t>.size)
        guard getsockopt(descriptor, SOL_LOCAL, LOCAL_PEERPID, &pid, &length) == 0, pid > 0 else { return [] }
        return ProcessTree.ancestry(of: pid)
    }

    // MARK: Connections

    /// Only touched on the server's queue.
    private final class Connection: @unchecked Sendable {
        let id: UInt64
        let descriptor: Int32
        let ancestry: [ProcessTree.Entry]
        let source: DispatchSourceRead
        var buffer = Data()
        /// A permission request, held until the notch answers.
        var isWaitingForReply = false

        init(id: UInt64, descriptor: Int32, ancestry: [ProcessTree.Entry], queue: DispatchQueue) {
            self.id = id
            self.descriptor = descriptor
            self.ancestry = ancestry
            source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
            source.setCancelHandler {
                close(descriptor)
            }
        }
    }

    private func track(_ connection: Connection) {
        let id = connection.id
        connections[id] = connection
        connection.source.setEventHandler { [weak self] in
            self?.read(from: id)
        }
        connection.source.resume()
        queue.asyncAfter(deadline: .now() + Self.requestTimeout) { [weak self] in
            guard let self, let connection = connections[id], !connection.isWaitingForReply else { return }
            finish(id, status: "408 Request Timeout")
        }
    }

    private func read(from id: UInt64) {
        guard let connection = connections[id] else { return }
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        var reachedEnd = false
        while true {
            let count = Darwin.read(connection.descriptor, &chunk, chunk.count)
            if count > 0 {
                connection.buffer.append(contentsOf: chunk[0 ..< count])
            } else if count == 0 {
                reachedEnd = true
                break
            } else {
                if errno != EAGAIN, errno != EWOULDBLOCK {
                    reachedEnd = true
                }
                break
            }
        }

        if connection.isWaitingForReply {
            // The hook went away while waiting: Claude Code got its answer some other way.
            if reachedEnd {
                finish(id, status: nil)
                onAbandon(ReplyID(rawValue: id))
            }
            return
        }

        guard connection.buffer.count <= Self.maximumRequestLength else {
            finish(id, status: "413 Content Too Large")
            return
        }
        switch HTTPRequest.parse(connection.buffer) {
        case let .complete(request):
            guard request.method == "POST" else {
                finish(id, status: "404 Not Found")
                return
            }
            switch request.path {
            case Self.eventsPath:
                finish(id, status: "204 No Content")
                onDelivery(Delivery(body: request.body, headers: request.headers, ancestry: connection.ancestry, replyID: nil))
            case Self.permissionPath:
                hold(connection)
                onDelivery(Delivery(
                    body: request.body,
                    headers: request.headers,
                    ancestry: connection.ancestry,
                    replyID: ReplyID(rawValue: id)
                ))
            default:
                finish(id, status: "404 Not Found")
            }
        case .invalid:
            finish(id, status: "400 Bad Request")
        case .incomplete:
            if reachedEnd {
                finish(id, status: nil)
            }
        }
    }

    /// Keeps a permission request open for the notch's answer, up to `replyTimeout`.
    private func hold(_ connection: Connection) {
        let id = connection.id
        connection.isWaitingForReply = true
        queue.asyncAfter(deadline: .now() + Self.replyTimeout) { [weak self] in
            guard let self, connections[id]?.isWaitingForReply == true else { return }
            finish(id, status: "204 No Content")
            onAbandon(ReplyID(rawValue: id))
        }
    }

    /// Answers, if the client is still there, and closes the connection.
    private func finish(_ id: UInt64, status: String?, body: Data = Data()) {
        guard let connection = connections.removeValue(forKey: id) else { return }
        if let status {
            var response = Data("HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\n".utf8)
            if !body.isEmpty {
                response += Data("Content-Type: application/json\r\n".utf8)
            }
            response += Data("Connection: close\r\n\r\n".utf8) + body
            _ = response.withUnsafeBytes { write(connection.descriptor, $0.baseAddress, $0.count) }
        }
        connection.source.cancel()
    }
}

// MARK: - HTTPRequest

/// The little of HTTP/1.1 the hook needs: a request line, headers and a body of known length.
nonisolated struct HTTPRequest: Equatable, Sendable {
    enum ParseResult: Equatable, Sendable {
        case incomplete
        case invalid
        case complete(HTTPRequest)
    }

    static let maximumHeaderLength = 16 * 1024

    let method: String
    let path: String
    /// Names are lowercased.
    let headers: [String: String]
    let body: Data

    static func parse(_ data: Data) -> ParseResult {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerEnd = data.range(of: separator) else {
            return data.count > maximumHeaderLength ? .invalid : .incomplete
        }
        guard headerEnd.lowerBound <= maximumHeaderLength,
              let head = String(data: data[data.startIndex ..< headerEnd.lowerBound], encoding: .utf8) else { return .invalid }

        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/1.") else { return .invalid }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { return .invalid }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        // Chunked bodies aren't needed: curl sends what it read from the hook's input with its length.
        guard headers["transfer-encoding"] == nil else { return .invalid }

        let length: Int
        if let value = headers["content-length"] {
            guard let parsed = Int(value), parsed >= 0 else { return .invalid }
            length = parsed
        } else {
            length = 0
        }
        let bodyStart = headerEnd.upperBound
        guard data.endIndex - bodyStart >= length else { return .incomplete }

        return .complete(HTTPRequest(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: Data(data[bodyStart ..< bodyStart + length])
        ))
    }
}
