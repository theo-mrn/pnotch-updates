//
//  PasteAndTabsTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Testing
@testable import PNotch

struct PasteActivationTests {
    @Test func pastesWhenAllowed() {
        #expect(ClipboardStateViewModel.activation(copyOnly: false, pasteDirectly: true, isTrusted: true) == .paste)
    }

    @Test func optionOnlyCopies() {
        #expect(ClipboardStateViewModel.activation(copyOnly: true, pasteDirectly: true, isTrusted: true) == .copy)
    }

    @Test func directPasteCanBeTurnedOff() {
        #expect(ClipboardStateViewModel.activation(copyOnly: false, pasteDirectly: false, isTrusted: true) == .copy)
    }

    @Test func missingPermissionFallsBackToCopying() {
        #expect(ClipboardStateViewModel.activation(copyOnly: false, pasteDirectly: true, isTrusted: false) == .copyAndRequestPermission)
    }

    @Test func findsTheKeyTypingV() {
        // Whatever the layout (QWERTY, AZERTY, Dvorak…), some key types "v".
        #expect(KeyboardLayout.keyCode(for: "v") != nil)
    }
}

struct NotchTabsConfigurationTests {
    @Test func normalizesTheStoredOrder() {
        let configuration = NotchTabsConfiguration(order: [.system, .system], hidden: [])
        #expect(configuration.order == [.system, .music, .clipboard, .companion, .claudeCode])
    }

    @Test func neverHidesEveryTab() {
        var configuration = NotchTabsConfiguration(order: NotchPage.allCases, hidden: [.music, .clipboard, .companion, .claudeCode])
        configuration.setVisible(.system, false)

        #expect(configuration.visiblePages == [.system])
        let allHidden = NotchTabsConfiguration(order: NotchPage.allCases, hidden: Set(NotchPage.allCases))
        #expect(allHidden.visiblePages.count == NotchPage.allCases.count)
    }

    @Test func movesTabs() {
        var configuration = NotchTabsConfiguration(order: [.music, .clipboard, .system], hidden: [])
        configuration.move(.system, by: -1)
        #expect(configuration.order == [.music, .system, .clipboard, .companion, .claudeCode])

        configuration.move(.music, by: -5)
        #expect(configuration.order == [.music, .system, .clipboard, .companion, .claudeCode])

        configuration.move(.music, by: 9)
        #expect(configuration.order == [.system, .clipboard, .companion, .claudeCode, .music])
    }

    struct OpeningCase: Sendable, CustomTestStringConvertible {
        let startPage: NotchPage?
        let lastPage: NotchPage
        let hidden: Set<NotchPage>
        let expected: NotchPage

        var testDescription: String {
            "start \(String(describing: startPage)), last \(lastPage), hidden \(hidden.map(\.rawValue).sorted())"
        }
    }

    @Test(arguments: [
        OpeningCase(startPage: .system, lastPage: .music, hidden: [], expected: .system),
        OpeningCase(startPage: nil, lastPage: .clipboard, hidden: [], expected: .clipboard),
        OpeningCase(startPage: .system, lastPage: .clipboard, hidden: [.system], expected: .clipboard),
        OpeningCase(startPage: nil, lastPage: .music, hidden: [.music], expected: .clipboard),
    ])
    func picksThePageToOpen(_ testCase: OpeningCase) {
        let configuration = NotchTabsConfiguration(order: [.music, .clipboard, .system], hidden: testCase.hidden)
        #expect(configuration.pageToOpen(startPage: testCase.startPage, lastPage: testCase.lastPage) == testCase.expected)
    }
}
