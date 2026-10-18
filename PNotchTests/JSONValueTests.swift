//
//  JSONValueTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import Testing
@testable import PNotch

struct JSONValueTests {
    /// Settings as Claude Code writes them, with `JSON.stringify(settings, null, 2)`.
    private let claudeSettings = """
    {
      "model": "opus",
      "permissions": {
        "allow": [
          "Bash(npm test)",
          "Read(~/Developer/**)"
        ],
        "deny": [],
        "additionalDirectories": {}
      },
      "cleanupPeriodDays": 30,
      "temperature": 0.1,
      "budget": -1.5e3,
      "statusLine": null,
      "includeCoAuthoredBy": false,
      "env": {
        "GREETING": "Ça va ? \\"oui\\"\\n\\\\o/ 🎉"
      }
    }
    """

    @Test func roundTripsClaudeCodeSettingsExactly() throws {
        let value = try JSONValue(parsing: claudeSettings)
        #expect(value.formatted() == claudeSettings)
    }

    @Test func keepsKeysInOrderAndNumbersAsWritten() throws {
        let value = try JSONValue(parsing: claudeSettings)
        guard case let .object(members) = value else {
            Issue.record("Not an object")
            return
        }
        #expect(members.map(\.key) == [
            "model", "permissions", "cleanupPeriodDays", "temperature", "budget", "statusLine", "includeCoAuthoredBy", "env",
        ])
        #expect(value["temperature"] == .number("0.1"))
        #expect(value["budget"] == .number("-1.5e3"))
        #expect(value["env"]?["GREETING"]?.stringValue == "Ça va ? \"oui\"\n\\o/ 🎉")
    }

    @Test func decodesEscapes() throws {
        let value = try JSONValue(parsing: #"["\u00e9\u001b", "\ud83d\ude00", "\/", "\ud800x"]"#)
        #expect(value.arrayValue?.compactMap(\.stringValue) == ["é\u{1B}", "😀", "/", "\u{FFFD}x"])
        // Written back like JavaScript does: only what must be escaped is.
        #expect(value.formatted() == "[\n  \"é\\u001b\",\n  \"😀\",\n  \"/\",\n  \"\u{FFFD}x\"\n]")
    }

    @Test(arguments: [
        "", "{", "[1,]", "{\"a\" 1}", "{a: 1}", "01", "1.", "-", "\"tab\there\"", "tru", "[1] [2]", "\"\\x\"",
    ])
    func rejectsInvalidDocuments(_ text: String) {
        #expect(throws: JSONValue.ParseError.self) {
            try JSONValue(parsing: text)
        }
    }

    @Test func rejectsAbsurdNesting() {
        let deep = String(repeating: "[", count: 10000) + String(repeating: "]", count: 10000)
        #expect(throws: JSONValue.ParseError.self) {
            try JSONValue(parsing: deep)
        }
    }

    @Test func setsKeysInPlace() throws {
        var value = try JSONValue(parsing: #"{"a": 1, "b": 2}"#)
        value.set("a", to: .bool(true))
        value.set("c", to: .null)
        value.set("b", to: nil)
        #expect(value.formatted() == "{\n  \"a\": true,\n  \"c\": null\n}")
    }
}
