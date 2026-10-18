//
//  ProcessTree.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Darwin

/// Walks up the process tree, e.g. from a hook to the Claude Code that ran it and the terminal it runs in.
nonisolated enum ProcessTree {
    struct Entry: Equatable, Sendable {
        let pid: pid_t
        let name: String?
    }

    /// The process and its ancestors, closest first, launchd excluded.
    static func ancestry(of pid: pid_t, limit: Int = 32) -> [Entry] {
        var entries: [Entry] = []
        var current: pid_t? = pid
        while let pid = current, pid > 1, entries.count < limit {
            entries.append(Entry(pid: pid, name: name(of: pid)))
            current = parent(of: pid)
        }
        return entries
    }

    static func parent(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    static func name(of pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    // MARK: Claude Code

    /// What stands between Claude Code and the hook's request: the hook script, its shell, curl.
    static let hookIntermediaries: Set = ["curl", "sh", "bash", "zsh", "dash", "fish", "env", ClaudeCodeHooks.scriptName]

    /// Claude Code's process, from the ancestry of a hook's request: the first ancestor that isn't part of the hook.
    static func claudeCodeProcess(in ancestry: [Entry]) -> pid_t? {
        ancestry.first { entry in
            entry.name.map { !hookIntermediaries.contains($0) } ?? false
        }?.pid
    }
}
