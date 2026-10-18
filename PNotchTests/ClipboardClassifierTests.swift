//
//  ClipboardClassifierTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import AppKit
import Testing
@testable import PNotch

struct ClipboardClassifierTests {
    @Test func recognisesColors() {
        #expect(ClipboardClassifier.content(forText: "#3A6FF2", rtf: nil).kind == .color)
    }

    @Test(arguments: [
        "https://teenage.engineering/products/op-1",
        "http://localhost:8080/health",
        " https://example.com/path?query=1#anchor \n",
    ])
    func recognisesLinks(text: String) {
        #expect(ClipboardClassifier.content(forText: text, rtf: nil).kind == .link)
    }

    @Test(arguments: [
        "Read https://example.com tonight",
        "ftp://example.com/file",
        "https://",
        "mailto:maya@fernpoint.studio",
    ])
    func rejectsNonWebURLs(text: String) {
        #expect(ClipboardClassifier.webURL(from: text) == nil)
    }

    @Test(arguments: [
        """
        :root {
          --accent: #3A6FF2;
          --radius: 14px;
        }
        """,
        """
        func greet(_ name: String) -> String {
            return "Hello, \\(name)"
        }
        """,
        """
        const total = items.reduce((sum, item) => sum + item.price, 0);
        console.log(total);
        """,
        "SELECT id, name FROM users WHERE active = 1;",
        "git commit -m \"Add clipboard notch\"",
        "npm install --save-dev typescript",
    ])
    func recognisesCode(text: String) {
        #expect(ClipboardClassifier.content(forText: text, rtf: nil).kind == .code)
    }

    @Test(arguments: [
        "Thanks Maya — the revised brief works. Let's lock the palette on Friday.",
        "Meeting moved to 3pm. Bring the printed proofs!",
        "groceries: milk, eggs, bread",
        "git is a distributed version control system. It tracks changes.",
        "Hello",
    ])
    func keepsProseAsText(text: String) {
        #expect(ClipboardClassifier.content(forText: text, rtf: nil).kind == .text)
    }

    @Test func plainRTFIsText() throws {
        let rtf = try rtfData(NSAttributedString(string: "Just one style", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
        #expect(ClipboardClassifier.content(forText: "Just one style", rtf: rtf).kind == .text)
    }

    @Test func formattedRTFIsRichText() throws {
        let attributed = NSMutableAttributedString(string: "Client ", attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        attributed.append(NSAttributedString(string: "Lindqvist", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
        let rtf = try rtfData(attributed)
        #expect(ClipboardClassifier.content(forText: attributed.string, rtf: rtf).kind == .richText)
    }

    private func rtfData(_ string: NSAttributedString) throws -> Data {
        try string.data(
            from: NSRange(location: 0, length: string.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}
