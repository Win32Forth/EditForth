//
//  EditForthMain.swift
//  EditForth
//
//  One executable, two processes. The editor is the normal launch.
//  `--companion` is the headless kernel on edit.sock.
//  `--agent` is a headless eval that prints to stdout and exits.
//

import Foundation
import SwiftUI

@main
nonisolated enum EditForthMain {
    static func main() {
        if AgentChannel.isRequested {
            AgentChannel.runAndExit()
        }
        if CompanionChannel.isRequested {
            CompanionChannel.run()
            return
        }
        SixtyFourEditApp.main()
    }
}
