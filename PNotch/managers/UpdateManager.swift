//
//  UpdateManager.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import Observation
import Sparkle

/// Automatic updates through Sparkle.
///
/// Sparkle only starts when the build declares a feed and its public signing key
/// (`Configuration/Distribution.xcconfig`): a development build has neither and simply doesn't update.
@Observable
final class UpdateManager {
    @ObservationIgnored private let controller: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let isConfigured = !feedURL.isEmpty && !publicKey.isEmpty

        controller = isConfigured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
    }

    var isAvailable: Bool {
        controller != nil
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
