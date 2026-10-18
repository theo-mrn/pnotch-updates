//
//  ProcessInfo+Testing.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

extension ProcessInfo {
    /// `true` when the app is launched as the host of the unit test bundle.
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
    }
}
