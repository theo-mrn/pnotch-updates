//
//  Logger.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import os

extension Logger {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "com.pnotch.PNotch"

    nonisolated static let app = Logger(subsystem: subsystem, category: "app")
    nonisolated static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    nonisolated static let persistence = Logger(subsystem: subsystem, category: "persistence")
    nonisolated static let music = Logger(subsystem: subsystem, category: "music")
    nonisolated static let claudeCode = Logger(subsystem: subsystem, category: "claude-code")
}
