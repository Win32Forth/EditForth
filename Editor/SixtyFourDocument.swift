//
//  SixtyFourDocument.swift
//  64Edit
//
//  Created by Tom Zimmer on 9/29/26.
//

import SwiftUI
import UniformTypeIdentifiers


extension UTType {
    static var forthSource: UTType {
        UTType(exportedAs: "com.win32forth.forth-source")
    }
}

struct ForthDocument: FileDocument {
    var text: String

    static var readableContentTypes: [UTType] = [
        .forthSource,
        .text,            // public.text
        .plainText,       // public.plain-text
        .utf8PlainText
    ]
    static var writableContentTypes: [UTType] = [
        .forthSource,
        .plainText,
        .utf8PlainText
    ]
    
    init(text: String = "") { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
