//
//  ColorParserTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Testing
@testable import PNotch

struct ColorParserTests {
    @Test(arguments: [
        ("#8A8067", "#8A8067"),
        ("#8a8067", "#8A8067"),
        ("#FA0", "#FFAA00"),
        ("  #3A6FF2\n", "#3A6FF2"),
        ("0x3A6FF2", "#3A6FF2"),
        ("#3A6FF280", "#3A6FF280"),
        ("rgb(58, 111, 242)", "#3A6FF2"),
        ("rgb(58 111 242)", "#3A6FF2"),
        ("rgba(58, 111, 242, 0.5)", "#3A6FF280"),
        ("rgb(100% 0% 0% / 50%)", "#FF000080"),
        ("hsl(0, 100%, 50%)", "#FF0000"),
        ("hsl(120deg 100% 25%)", "#008000"),
        ("hsla(240, 100%, 50%, 1)", "#0000FF"),
    ])
    func parsesSupportedNotations(input: String, expectedHex: String) throws {
        let color = try #require(ColorParser.parse(input))
        #expect(color.hexString == expectedHex)
    }

    @Test(arguments: [
        "",
        "#",
        "#12",
        "#12345",
        "#GGGGGG",
        "0xFFF",
        "rgb(300, 0, 0)",
        "rgb(1, 2)",
        "hsl(0, 100, 50)",
        "red",
        "The color is #3A6FF2",
    ])
    func rejectsOtherText(input: String) {
        #expect(ColorParser.parse(input) == nil)
    }

    @Test func keepsTheCopiedNotation() throws {
        let color = try #require(ColorParser.parse(" rgb(58, 111, 242) "))
        #expect(color.rawValue == "rgb(58, 111, 242)")
        #expect(color.rgbString == "rgb(58, 111, 242)")
    }

    @Test func picksAReadableForeground() throws {
        #expect(try #require(ColorParser.parse("#FFFFFF")).prefersDarkForeground)
        #expect(try #require(ColorParser.parse("#F2E6C4")).prefersDarkForeground)
        #expect(try !#require(ColorParser.parse("#000000")).prefersDarkForeground)
        #expect(try !#require(ColorParser.parse("#3A3B6E")).prefersDarkForeground)
    }
}
