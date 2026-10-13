//
//  AskForthLLMSettings.swift
//  EditForth
//
//  Provider choice for Ask Forth: local Ollama vs OpenAI-compatible HTTP
//  (SpaceXAI / xAI by default). API key stored in Keychain.
//

import Foundation
import Security

enum AskForthLLMProvider: String, CaseIterable, Identifiable {
    case ollama
    case openAICompatible

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .ollama: return "Ollama (local)"
        case .openAICompatible: return "OpenAI-compatible"
        }
    }

    var shortLabel: String {
        switch self {
        case .ollama: return "Ollama"
        case .openAICompatible: return "OpenAI-compat"
        }
    }

    var help: String {
        switch self {
        case .ollama:
            return "Local Ollama at 127.0.0.1:11434. No API key. Default for offline Ask Forth."
        case .openAICompatible:
            return "HTTP chat completions (OpenAI-compatible). Default base URL is SpaceXAI / xAI (api.x.ai/v1). Needs an API key in Keychain (or XAI_API_KEY in the environment)."
        }
    }
}

enum AskForthLLMSettings {
    static let providerKey = "aiAssistantProvider"
    static let ollamaModelKey = "aiAssistantModel"
    static let openAIModelKey = "aiAssistantOpenAIModel"
    static let openAIBaseURLKey = "aiAssistantOpenAIBaseURL"

    static let defaultOllamaModel = "gemma4:e4b"
    static let defaultOpenAIModel = "grok-4.7"
    static let defaultOpenAIBaseURL = "https://api.x.ai/v1"

    private static let keychainService = "com.Win32Forth.EditForth.AskForth"
    private static let keychainAccount = "openaiCompatibleAPIKey"

    static var provider: AskForthLLMProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: providerKey) ?? ""
            return AskForthLLMProvider(rawValue: raw) ?? .ollama
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
        }
    }

    static var ollamaModel: String {
        get {
            let s = UserDefaults.standard.string(forKey: ollamaModelKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return s.isEmpty ? defaultOllamaModel : s
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ollamaModelKey)
        }
    }

    static var openAIModel: String {
        get {
            let s = UserDefaults.standard.string(forKey: openAIModelKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return s.isEmpty ? defaultOpenAIModel : s
        }
        set {
            UserDefaults.standard.set(newValue, forKey: openAIModelKey)
        }
    }

    static var openAIBaseURLString: String {
        get {
            let s = UserDefaults.standard.string(forKey: openAIBaseURLKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return s.isEmpty ? defaultOpenAIBaseURL : s
        }
        set {
            UserDefaults.standard.set(newValue, forKey: openAIBaseURLKey)
        }
    }

    static var openAIBaseURL: URL {
        URL(string: openAIBaseURLString) ?? URL(string: defaultOpenAIBaseURL)!
    }

    /// Model string for the active provider.
    static var activeModel: String {
        get {
            switch provider {
            case .ollama: return ollamaModel
            case .openAICompatible: return openAIModel
            }
        }
        set {
            switch provider {
            case .ollama: ollamaModel = newValue
            case .openAICompatible: openAIModel = newValue
            }
        }
    }

    static func makeClient() -> LLMClient {
        switch provider {
        case .ollama:
            return OllamaClient()
        case .openAICompatible:
            return OpenAICompatibleClient(
                baseURL: openAIBaseURL,
                apiKeyProvider: { resolveAPIKey() }
            )
        }
    }

    /// Keychain value, else `XAI_API_KEY` from the process environment.
    static func resolveAPIKey() -> String? {
        if let key = loadAPIKeyFromKeychain(), !key.isEmpty {
            return key
        }
        let env = ProcessInfo.processInfo.environment["XAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty { return env }
        return nil
    }

    static var hasAPIKey: Bool {
        resolveAPIKey() != nil
    }

    /// True when Keychain holds a key (env-only does not count as “saved”).
    static var hasKeychainAPIKey: Bool {
        if let key = loadAPIKeyFromKeychain(), !key.isEmpty { return true }
        return false
    }

    static func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try deleteAPIKey()
            return
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AskForthKeychainError.saveFailed(status)
        }
    }

    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AskForthKeychainError.saveFailed(status)
        }
    }

    private static func loadAPIKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum AskForthKeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Could not save API key in Keychain (status \(status))."
        }
    }
}
