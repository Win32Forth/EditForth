//
//  EditForthConsoleBanner.swift
//  EditForth
//
//  Startup line for the embedded/floating console. Version comes from the
//  app bundle (MARKETING_VERSION). Stamp the date/time when finishing a
//  version change set — same practice as Forth/App/ConsoleView.swift.
//

import Foundation

enum EditForthConsoleBanner {
    /// Update when finishing a version (with MARKETING_VERSION / docs).
    static let stamp = "Oct 6, 2026 3:36 PM"

    /// e.g. `=== EditForth 2.0.1 === Oct 6, 2026 3:36 PM ===\n`
    static var text: String {
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "2.0.1"
        return "=== EditForth \(ver) === \(stamp) ===\n"
    }
}
