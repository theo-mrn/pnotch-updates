//
//  NowPlayingController.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import os

/// Reads and drives the system "Now Playing" (Music, Spotify, browsers, podcasts…) through MediaRemoteAdapter.
///
/// Since macOS 15.4 only Apple-entitled processes may read MediaRemote, so the adapter framework is loaded
/// into `/usr/bin/perl`, which is. A long-running `stream` process reports changes as JSON lines;
/// commands spawn short-lived processes. See `Vendor/MediaRemoteAdapter/README.md`.
final class NowPlayingController: MediaControllerProtocol {
    var onPlaybackChange: ((PlaybackState?) -> Void)?

    private let adapter: MediaRemoteAdapterLauncher?
    private var streamProcess: Process?
    /// Command processes are kept alive until they exit.
    private var runningCommands: [ObjectIdentifier: Process] = [:]
    private var readTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var restartDelay: Duration = .seconds(1)
    private var isRunning = false

    init(adapter: MediaRemoteAdapterLauncher? = .bundled) {
        self.adapter = adapter
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        launchStream()
    }

    func stop() {
        isRunning = false
        restartTask?.cancel()
        refreshTask?.cancel()
        readTask?.cancel()
        streamProcess?.terminate()
        streamProcess = nil
    }

    func send(_ command: MediaCommand) {
        runCommand(["send", String(command.rawValue)])
        refreshAfterCommand()
    }

    func seek(to position: TimeInterval) {
        runCommand(["seek", String(Int64(max(position, 0) * 1_000_000))])
        refreshAfterCommand()
    }

    /// MediaRemote doesn't notify every change to the stream (a pause, a seek…), so the state is read
    /// again shortly after each command: once the player has reacted, and once more for slow ones.
    private func refreshAfterCommand() {
        guard let adapter else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            for delay in [Duration.milliseconds(300), .seconds(1)] {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled,
                      let output = await adapter.output(of: ["get", "--micros"]),
                      case let .update(playback) = NowPlayingStreamParser.parseSnapshot(output)
                else { continue }
                self?.publish(playback)
            }
        }
    }

    private func runCommand(_ arguments: [String]) {
        guard let adapter else { return }

        let process = adapter.makeProcess(arguments)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let identifier = ObjectIdentifier(process)
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.runningCommands[identifier] = nil
            }
        }

        do {
            try process.run()
            runningCommands[identifier] = process
        } catch {
            Logger.music.error("Failed to run \(arguments.first ?? "", privacy: .public): \(error.localizedDescription)")
        }
    }

    // MARK: Stream

    private func launchStream() {
        guard let adapter else {
            Logger.music.error("MediaRemoteAdapter is missing from the app bundle")
            return
        }

        let process = adapter.makeProcess(["stream", "--no-diff", "--micros", "--debounce=50"])
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor in
                self?.streamDidExit(status: status)
            }
        }

        do {
            try process.run()
        } catch {
            Logger.music.error("Failed to launch the now playing stream: \(error.localizedDescription)")
            scheduleRestart()
            return
        }
        streamProcess = process

        // JSON decoding and base64 artwork happen off the main actor; only results hop back.
        let handle = output.fileHandleForReading
        readTask = Task.detached(priority: .utility) { [weak self] in
            do {
                for try await line in handle.bytes.lines {
                    guard case let .update(playback) = NowPlayingStreamParser.parse(line) else { continue }
                    await self?.publish(playback)
                }
            } catch {
                Logger.music.error("Now playing stream failed: \(error.localizedDescription)")
            }
        }
    }

    private func publish(_ playback: PlaybackState?) {
        restartDelay = .seconds(1)
        onPlaybackChange?(playback)
    }

    private func streamDidExit(status: Int32) {
        streamProcess = nil
        guard isRunning else { return }
        Logger.music.notice("Now playing stream exited with status \(status), restarting")
        scheduleRestart()
    }

    /// Relaunches the stream with an increasing delay, so a broken adapter doesn't spin.
    private func scheduleRestart() {
        restartTask?.cancel()
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, .seconds(30))
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, isRunning else { return }
            launchStream()
        }
    }
}

// MARK: - MediaRemoteAdapterLauncher

/// Locates the adapter script and framework embedded in the app, and starts `perl` with them.
nonisolated struct MediaRemoteAdapterLauncher: Sendable {
    let scriptURL: URL
    let frameworkURL: URL

    static var bundled: MediaRemoteAdapterLauncher? {
        guard let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let frameworks = Bundle.main.privateFrameworksURL
        else { return nil }
        return MediaRemoteAdapterLauncher(
            scriptURL: script,
            frameworkURL: frameworks.appending(path: "MediaRemoteAdapter.framework", directoryHint: .isDirectory)
        )
    }

    /// Runs a short adapter command off the main actor and returns what it printed.
    func output(of arguments: [String]) async -> String? {
        let process = makeProcess(arguments)
        return await Task.detached(priority: .userInitiated) {
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                return nil
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)
        }.value
    }

    func makeProcess(_ arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path(percentEncoded: false), frameworkURL.path(percentEncoded: false)] + arguments
        return process
    }

}
