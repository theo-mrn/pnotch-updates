//
//  JSONValue.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// A JSON document that keeps its keys in order and its numbers as written.
///
/// Used to edit files the user owns, like `~/.claude/settings.json`, without reshuffling them:
/// Foundation's serializer sorts keys, rewrites `0.1` as `0.10000000000000001` and spaces colons differently.
nonisolated enum JSONValue: Equatable, Sendable {
    case object([Member])
    case array([JSONValue])
    case string(String)
    /// The number's literal, exactly as it appeared.
    case number(String)
    case bool(Bool)
    case null

    struct Member: Equatable, Sendable {
        var key: String
        var value: JSONValue
    }

    struct ParseError: Error, Equatable {
        /// Byte offset where parsing failed.
        let offset: Int
    }

    // MARK: Access

    subscript(key: String) -> JSONValue? {
        guard case let .object(members) = self else { return nil }
        return members.last { $0.key == key }?.value
    }

    var stringValue: String? {
        guard case let .string(string) = self else { return nil }
        return string
    }

    var arrayValue: [JSONValue]? {
        guard case let .array(elements) = self else { return nil }
        return elements
    }

    var boolValue: Bool? {
        guard case let .bool(bool) = self else { return nil }
        return bool
    }

    /// Sets `key`, keeping its position when it already exists, appending it otherwise.
    /// Does nothing on values that aren't objects.
    mutating func set(_ key: String, to value: JSONValue?) {
        guard case var .object(members) = self else { return }
        if let value {
            if let index = members.firstIndex(where: { $0.key == key }) {
                members[index].value = value
            } else {
                members.append(Member(key: key, value: value))
            }
        } else {
            members.removeAll { $0.key == key }
        }
        self = .object(members)
    }

    // MARK: Parsing

    init(parsing data: Data) throws {
        var parser = Parser(bytes: [UInt8](data))
        parser.skipWhitespace()
        let value = try parser.parseValue(depth: 0)
        parser.skipWhitespace()
        guard parser.isAtEnd else { throw ParseError(offset: parser.index) }
        self = value
    }

    init(parsing text: String) throws {
        try self.init(parsing: Data(text.utf8))
    }

    // MARK: Serialization

    /// Two-space indented text, formatted like JavaScript's `JSON.stringify(value, null, 2)`,
    /// which is how Claude Code writes its settings.
    func formatted() -> String {
        var output = ""
        write(to: &output, indent: "")
        return output
    }

    private func write(to output: inout String, indent: String) {
        switch self {
        case let .object(members):
            guard !members.isEmpty else {
                output += "{}"
                return
            }
            let inner = indent + "  "
            output += "{\n"
            for (index, member) in members.enumerated() {
                output += inner
                Self.writeString(member.key, to: &output)
                output += ": "
                member.value.write(to: &output, indent: inner)
                output += index < members.count - 1 ? ",\n" : "\n"
            }
            output += indent + "}"
        case let .array(elements):
            guard !elements.isEmpty else {
                output += "[]"
                return
            }
            let inner = indent + "  "
            output += "[\n"
            for (index, element) in elements.enumerated() {
                output += inner
                element.write(to: &output, indent: inner)
                output += index < elements.count - 1 ? ",\n" : "\n"
            }
            output += indent + "]"
        case let .string(string):
            Self.writeString(string, to: &output)
        case let .number(literal):
            output += literal
        case let .bool(bool):
            output += bool ? "true" : "false"
        case .null:
            output += "null"
        }
    }

    private static func writeString(_ string: String, to output: inout String) {
        output += "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            case "\u{08}": output += "\\b"
            case "\u{0C}": output += "\\f"
            case _ where scalar.value < 0x20:
                output += "\\u" + String(format: "%04x", scalar.value)
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
    }
}

// MARK: - Parser

nonisolated private struct Parser {
    /// Deeper documents are rejected rather than risking the stack.
    static let maximumDepth = 256

    let bytes: [UInt8]
    var index = 0

    var isAtEnd: Bool {
        index >= bytes.count
    }

    private var current: UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private var error: JSONValue.ParseError {
        JSONValue.ParseError(offset: index)
    }

    mutating func skipWhitespace() {
        while let byte = current, byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
            index += 1
        }
    }

    mutating func parseValue(depth: Int) throws -> JSONValue {
        guard depth < Self.maximumDepth, let byte = current else { throw error }
        switch byte {
        case UInt8(ascii: "{"): return try parseObject(depth: depth)
        case UInt8(ascii: "["): return try parseArray(depth: depth)
        case UInt8(ascii: "\""): return try .string(parseString())
        case UInt8(ascii: "t"): return try parseLiteral("true", .bool(true))
        case UInt8(ascii: "f"): return try parseLiteral("false", .bool(false))
        case UInt8(ascii: "n"): return try parseLiteral("null", .null)
        default: return try parseNumber()
        }
    }

    private mutating func parseObject(depth: Int) throws -> JSONValue {
        index += 1
        var members: [JSONValue.Member] = []
        skipWhitespace()
        if current == UInt8(ascii: "}") {
            index += 1
            return .object(members)
        }
        while true {
            skipWhitespace()
            guard current == UInt8(ascii: "\"") else { throw error }
            let key = try parseString()
            skipWhitespace()
            guard current == UInt8(ascii: ":") else { throw error }
            index += 1
            skipWhitespace()
            let value = try parseValue(depth: depth + 1)
            members.append(JSONValue.Member(key: key, value: value))
            skipWhitespace()
            switch current {
            case UInt8(ascii: ","):
                index += 1
            case UInt8(ascii: "}"):
                index += 1
                return .object(members)
            default:
                throw error
            }
        }
    }

    private mutating func parseArray(depth: Int) throws -> JSONValue {
        index += 1
        var elements: [JSONValue] = []
        skipWhitespace()
        if current == UInt8(ascii: "]") {
            index += 1
            return .array(elements)
        }
        while true {
            skipWhitespace()
            elements.append(try parseValue(depth: depth + 1))
            skipWhitespace()
            switch current {
            case UInt8(ascii: ","):
                index += 1
            case UInt8(ascii: "]"):
                index += 1
                return .array(elements)
            default:
                throw error
            }
        }
    }

    private mutating func parseString() throws -> String {
        index += 1
        var utf8: [UInt8] = []
        while let byte = current {
            index += 1
            switch byte {
            case UInt8(ascii: "\""):
                return String(decoding: utf8, as: UTF8.self)
            case UInt8(ascii: "\\"):
                try parseEscape(into: &utf8)
            case ..<0x20:
                // Control characters must be escaped in JSON strings.
                index -= 1
                throw error
            default:
                utf8.append(byte)
            }
        }
        throw error
    }

    private mutating func parseEscape(into utf8: inout [UInt8]) throws {
        guard let byte = current else { throw error }
        index += 1
        switch byte {
        case UInt8(ascii: "\""): utf8.append(UInt8(ascii: "\""))
        case UInt8(ascii: "\\"): utf8.append(UInt8(ascii: "\\"))
        case UInt8(ascii: "/"): utf8.append(UInt8(ascii: "/"))
        case UInt8(ascii: "b"): utf8.append(0x08)
        case UInt8(ascii: "f"): utf8.append(0x0C)
        case UInt8(ascii: "n"): utf8.append(0x0A)
        case UInt8(ascii: "r"): utf8.append(0x0D)
        case UInt8(ascii: "t"): utf8.append(0x09)
        case UInt8(ascii: "u"):
            var scalar = try parseHexQuad()
            // A UTF-16 surrogate pair spells one character outside the Basic Multilingual Plane.
            if (0xD800 ... 0xDBFF).contains(scalar), bytes.count >= index + 6,
               bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") {
                let saved = index
                index += 2
                let low = try parseHexQuad()
                if (0xDC00 ... 0xDFFF).contains(low) {
                    scalar = 0x10000 + ((scalar - 0xD800) << 10) + (low - 0xDC00)
                } else {
                    index = saved
                }
            }
            let character = Unicode.Scalar(scalar) ?? "\u{FFFD}"
            utf8.append(contentsOf: Array(String(character).utf8))
        default:
            index -= 1
            throw error
        }
    }

    private mutating func parseHexQuad() throws -> UInt32 {
        guard bytes.count >= index + 4 else { throw error }
        var value: UInt32 = 0
        for _ in 0 ..< 4 {
            guard let digit = Self.hexValue(bytes[index]) else { throw error }
            value = value << 4 | digit
            index += 1
        }
        return value
    }

    private static func hexValue(_ byte: UInt8) -> UInt32? {
        switch byte {
        case UInt8(ascii: "0") ... UInt8(ascii: "9"): UInt32(byte - UInt8(ascii: "0"))
        case UInt8(ascii: "a") ... UInt8(ascii: "f"): UInt32(byte - UInt8(ascii: "a") + 10)
        case UInt8(ascii: "A") ... UInt8(ascii: "F"): UInt32(byte - UInt8(ascii: "A") + 10)
        default: nil
        }
    }

    private mutating func parseNumber() throws -> JSONValue {
        let start = index
        if current == UInt8(ascii: "-") {
            index += 1
        }
        if current == UInt8(ascii: "0") {
            index += 1
        } else {
            guard skipDigits() > 0 else { throw error }
        }
        if current == UInt8(ascii: ".") {
            index += 1
            guard skipDigits() > 0 else { throw error }
        }
        if current == UInt8(ascii: "e") || current == UInt8(ascii: "E") {
            index += 1
            if current == UInt8(ascii: "+") || current == UInt8(ascii: "-") {
                index += 1
            }
            guard skipDigits() > 0 else { throw error }
        }
        return .number(String(decoding: bytes[start ..< index], as: UTF8.self))
    }

    private mutating func skipDigits() -> Int {
        let start = index
        while let byte = current, byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
            index += 1
        }
        return index - start
    }

    private mutating func parseLiteral(_ literal: String, _ value: JSONValue) throws -> JSONValue {
        let expected = Array(literal.utf8)
        guard bytes.count >= index + expected.count, Array(bytes[index ..< index + expected.count]) == expected else {
            throw error
        }
        index += expected.count
        return value
    }
}
