//
//  KeyboardLayout.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Carbon.HIToolbox
import CoreGraphics

/// Maps characters to the physical keys of the current keyboard layout (QWERTY, AZERTY, Dvorak…).
enum KeyboardLayout {
    /// The key typing `character` without modifiers, e.g. the key to send for ⌘V.
    static func keyCode(for character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        let target = String(character).lowercased()

        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }

            for keyCode in UInt16(0) ..< 128 {
                var deadKeyState: UInt32 = 0
                var characters = [UniChar](repeating: 0, count: 4)
                var length = 0
                let status = UCKeyTranslate(
                    layout,
                    keyCode,
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    characters.count,
                    &length,
                    &characters
                )
                if status == noErr, length > 0, String(utf16CodeUnits: characters, count: length).lowercased() == target {
                    return CGKeyCode(keyCode)
                }
            }
            return nil
        }
    }
}
