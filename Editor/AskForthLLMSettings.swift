//
//  AskForthLLMSettings.swift
//  EditForth
//
//  Named Ask Forth model profiles (Ollama + OpenAI-compatible). Each profile
//  stores provider / model / base URL; OpenAI-compatible API keys are Keychain
//  items per profile id. Legacy single-provider keys migrate once.
//

import Foundation
import Security

enum AskForthLLMProvider: String, Codable, CaseIterable, Identifiable {
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
            return "HTTP chat completions (OpenAI-compatible). Needs a Base URL and usually an API key (Keychain per profile, or XAI_API_KEY in the environment for SpaceXAI)."
        }
    }
}

/// One saved Ask Forth endpoint + model. API keys are not stored in this struct.
struct AskForthModelProfile: Equatable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var provider: AskForthLLMProvider
    var model: String
    /// OpenAI-compatible root only; ignored for Ollama. Empty → SpaceXAI default.
    var baseURL: String
    /// Sampling temperature sent on each chat request (0 = deterministic … ~2 = wild).
    var temperature: Double

    init(
        id: UUID = UUID(),
        name: String,
        provider: AskForthLLMProvider,
        model: String,
        baseURL: String = "",
        temperature: Double = AskForthLLMSettings.defaultTemperature
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
        self.temperature = AskForthLLMSettings.clampTemperature(temperature)
    }

    var resolvedBaseURLString: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return AskForthLLMSettings.defaultOpenAIBaseURL }
        return trimmed
    }

    var resolvedBaseURL: URL {
        URL(string: resolvedBaseURLString) ?? URL(string: AskForthLLMSettings.defaultOpenAIBaseURL)!
    }

    var caption: String {
        let temp = String(format: "T%.2f", temperature)
        switch provider {
        case .ollama:
            return "\(provider.shortLabel) · \(model) · \(temp)"
        case .openAICompatible:
            return "\(provider.shortLabel) · \(resolvedBaseURLString) · \(temp)"
        }
    }
}

extension AskForthModelProfile: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, provider, model, baseURL, temperature
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        provider = try c.decode(AskForthLLMProvider.self, forKey: .provider)
        model = try c.decode(String.self, forKey: .model)
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        let rawTemp = try c.decodeIfPresent(Double.self, forKey: .temperature)
            ?? AskForthLLMSettings.defaultTemperature
        temperature = AskForthLLMSettings.clampTemperature(rawTemp)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(provider, forKey: .provider)
        try c.encode(model, forKey: .model)
        try c.encode(baseURL, forKey: .baseURL)
        try c.encode(temperature, forKey: .temperature)
    }
}

enum AskForthLLMSettings {
    // MARK: - Keys

    static let profilesKey = "aiAssistantModelProfiles"
    static let activeProfileIDKey = "aiAssistantActiveProfileID"

    /// Legacy single-slot keys (migration only).
    static let providerKey = "aiAssistantProvider"
    static let ollamaModelKey = "aiAssistantModel"
    static let openAIModelKey = "aiAssistantOpenAIModel"
    static let openAIBaseURLKey = "aiAssistantOpenAIBaseURL"
    private static let legacyKeychainAccount = "openaiCompatibleAPIKey"

    nonisolated static let defaultOllamaModel = "gemma4:e4b"
    nonisolated static let defaultOpenAIModel = "grok-4.7"
    /// Coding-friendly default (Ollama/OpenAI often default ~0.7–0.8 when unset).
    static let defaultTemperature: Double = 0.3
    static let temperatureRange: ClosedRange<Double> = 0...2

    static func clampTemperature(_ value: Double) -> Double {
        min(max(value, temperatureRange.lowerBound), temperatureRange.upperBound)
    }

    /// Readable from `@Sendable` / nonisolated client defaults.
    nonisolated static let defaultOpenAIBaseURL = "https://api.x.ai/v1"

    nonisolated private static let keychainService = "com.Win32Forth.EditForth.AskForth"

    private static let cannedOllamaName = "Ollama gemma4:e4b"
    private static let cannedSpaceXAIName = "SpaceXAI grok-4.7"
    private static let cannedLocalMLXName = "Local mlx :1234"

    private static var defaultQwenMLXPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                ".lmstudio/models/lmstudio-community/Qwen2.5-Coder-7B-Instruct-MLX-4bit",
                isDirectory: true
            )
            .path
    }

    // MARK: - Profiles store

    /// Load profiles, running one-shot migration/seed when the list is empty.
    @discardableResult
    static func ensureProfiles() -> [AskForthModelProfile] {
        var list = loadProfilesRaw()
        if list.isEmpty {
            list = migrateAndSeedProfiles()
            saveProfiles(list)
        } else {
            let before = list
            list = ensureCannedProfiles(in: list)
            if list != before {
                saveProfiles(list)
            }
        }
        if activeProfileID == nil || !list.contains(where: { $0.id == activeProfileID }) {
            activeProfileID = list.first?.id
        }
        return list
    }

    static func loadProfiles() -> [AskForthModelProfile] {
        ensureProfiles()
    }

    static func saveProfiles(_ profiles: [AskForthModelProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesKey)
    }

    static var activeProfileID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: activeProfileIDKey) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: activeProfileIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activeProfileIDKey)
            }
        }
    }

    static var activeProfile: AskForthModelProfile {
        let list = ensureProfiles()
        if let id = activeProfileID, let hit = list.first(where: { $0.id == id }) {
            return hit
        }
        return list[0]
    }

    static func selectProfile(id: UUID) {
        let list = ensureProfiles()
        guard list.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
    }

    static func upsertProfile(_ profile: AskForthModelProfile) {
        var list = ensureProfiles()
        if let idx = list.firstIndex(where: { $0.id == profile.id }) {
            list[idx] = profile
        } else {
            list.append(profile)
        }
        saveProfiles(list)
    }

    /// Returns false if this is the last profile (must keep at least one).
    @discardableResult
    static func deleteProfile(id: UUID) -> Bool {
        var list = ensureProfiles()
        guard list.count > 1 else { return false }
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return false }
        let removed = list.remove(at: idx)
        saveProfiles(list)
        try? deleteAPIKey(for: removed.id)
        if activeProfileID == id {
            activeProfileID = list.first?.id
        }
        return true
    }

    // MARK: - Legacy wrappers (active profile)

    static var provider: AskForthLLMProvider {
        get { activeProfile.provider }
        set {
            var p = activeProfile
            p.provider = newValue
            upsertProfile(p)
        }
    }

    static var activeModel: String {
        get {
            let m = activeProfile.model.trimmingCharacters(in: .whitespacesAndNewlines)
            if !m.isEmpty { return m }
            return activeProfile.provider == .ollama ? defaultOllamaModel : defaultOpenAIModel
        }
        set {
            var p = activeProfile
            p.model = newValue
            upsertProfile(p)
        }
    }

    static var openAIBaseURLString: String {
        get { activeProfile.resolvedBaseURLString }
        set {
            var p = activeProfile
            p.baseURL = newValue
            upsertProfile(p)
        }
    }

    static var openAIBaseURL: URL { activeProfile.resolvedBaseURL }

    static var ollamaModel: String {
        get {
            let list = ensureProfiles()
            if let hit = list.first(where: { $0.provider == .ollama }) {
                let m = hit.model.trimmingCharacters(in: .whitespacesAndNewlines)
                return m.isEmpty ? defaultOllamaModel : m
            }
            return defaultOllamaModel
        }
        set {
            var list = ensureProfiles()
            if let idx = list.firstIndex(where: { $0.provider == .ollama && $0.id == activeProfileID }) {
                list[idx].model = newValue
            } else if let idx = list.firstIndex(where: { $0.provider == .ollama }) {
                list[idx].model = newValue
            }
            saveProfiles(list)
        }
    }

    static var openAIModel: String {
        get {
            let list = ensureProfiles()
            if let hit = list.first(where: { $0.provider == .openAICompatible && $0.id == activeProfileID })
                ?? list.first(where: { $0.provider == .openAICompatible }) {
                let m = hit.model.trimmingCharacters(in: .whitespacesAndNewlines)
                return m.isEmpty ? defaultOpenAIModel : m
            }
            return defaultOpenAIModel
        }
        set {
            var list = ensureProfiles()
            if let idx = list.firstIndex(where: { $0.provider == .openAICompatible && $0.id == activeProfileID }) {
                list[idx].model = newValue
            } else if let idx = list.firstIndex(where: { $0.provider == .openAICompatible }) {
                list[idx].model = newValue
            }
            saveProfiles(list)
        }
    }

    // MARK: - Client

    static func makeClient() -> LLMClient {
        let profile = activeProfile
        let temperature = clampTemperature(profile.temperature)
        switch profile.provider {
        case .ollama:
            return OllamaClient(temperature: temperature)
        case .openAICompatible:
            let profileID = profile.id
            return OpenAICompatibleClient(
                baseURL: profile.resolvedBaseURL,
                apiKeyProvider: { resolveAPIKey(for: profileID) },
                temperature: temperature
            )
        }
    }

    // MARK: - Keychain (per profile)

    nonisolated private static func keychainAccount(for profileID: UUID) -> String {
        "profile.\(profileID.uuidString)"
    }

    /// Keychain for `profileID`, else (SpaceXAI convenience) `XAI_API_KEY` from the environment.
    nonisolated static func resolveAPIKey(for profileID: UUID) -> String? {
        if let key = loadAPIKeyFromKeychain(account: keychainAccount(for: profileID)), !key.isEmpty {
            return key
        }
        let env = ProcessInfo.processInfo.environment["XAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty { return env }
        return nil
    }

    /// Active profile key (or env).
    nonisolated static func resolveAPIKey() -> String? {
        // Avoid MainActor hop: read active id from UserDefaults directly.
        if let raw = UserDefaults.standard.string(forKey: "aiAssistantActiveProfileID"),
           let id = UUID(uuidString: raw) {
            return resolveAPIKey(for: id)
        }
        let env = ProcessInfo.processInfo.environment["XAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty { return env }
        return nil
    }

    nonisolated static func hasAPIKey(for profileID: UUID) -> Bool {
        resolveAPIKey(for: profileID) != nil
    }

    nonisolated static var hasAPIKey: Bool {
        if let raw = UserDefaults.standard.string(forKey: "aiAssistantActiveProfileID"),
           let id = UUID(uuidString: raw) {
            return hasAPIKey(for: id)
        }
        let env = ProcessInfo.processInfo.environment["XAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return env?.isEmpty == false
    }

    nonisolated static func hasKeychainAPIKey(for profileID: UUID) -> Bool {
        if let key = loadAPIKeyFromKeychain(account: keychainAccount(for: profileID)), !key.isEmpty {
            return true
        }
        return false
    }

    nonisolated static var hasKeychainAPIKey: Bool {
        if let raw = UserDefaults.standard.string(forKey: "aiAssistantActiveProfileID"),
           let id = UUID(uuidString: raw) {
            return hasKeychainAPIKey(for: id)
        }
        return false
    }

    static func saveAPIKey(_ key: String, for profileID: UUID) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = keychainAccount(for: profileID)
        if trimmed.isEmpty {
            try deleteAPIKey(for: profileID)
            return
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
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

    /// Save against the active profile.
    static func saveAPIKey(_ key: String) throws {
        try saveAPIKey(key, for: activeProfile.id)
    }

    static func deleteAPIKey(for profileID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount(for: profileID)
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AskForthKeychainError.saveFailed(status)
        }
    }

    static func deleteAPIKey() throws {
        try deleteAPIKey(for: activeProfile.id)
    }

    nonisolated private static func loadAPIKeyFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
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

    // MARK: - Migration / seed

    private static func loadProfilesRaw() -> [AskForthModelProfile] {
        guard let data = UserDefaults.standard.data(forKey: profilesKey),
              let list = try? JSONDecoder().decode([AskForthModelProfile].self, from: data) else {
            return []
        }
        return list
    }

    private static func legacyOllamaModel() -> String {
        let s = UserDefaults.standard.string(forKey: ollamaModelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? defaultOllamaModel : s
    }

    private static func legacyOpenAIModel() -> String {
        let s = UserDefaults.standard.string(forKey: openAIModelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? defaultOpenAIModel : s
    }

    private static func legacyOpenAIBaseURL() -> String {
        let s = UserDefaults.standard.string(forKey: openAIBaseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? defaultOpenAIBaseURL : s
    }

    private static func legacyProvider() -> AskForthLLMProvider {
        let raw = UserDefaults.standard.string(forKey: providerKey) ?? ""
        return AskForthLLMProvider(rawValue: raw) ?? .ollama
    }

    private static func migrateAndSeedProfiles() -> [AskForthModelProfile] {
        let ollamaModel = legacyOllamaModel()
        let openModel = legacyOpenAIModel()
        let openURL = legacyOpenAIBaseURL()

        let ollama = AskForthModelProfile(
            name: ollamaModel == defaultOllamaModel ? cannedOllamaName : "Ollama \(ollamaModel)",
            provider: .ollama,
            model: ollamaModel
        )
        let openAI = AskForthModelProfile(
            name: openNameFor(model: openModel, baseURL: openURL),
            provider: .openAICompatible,
            model: openModel,
            baseURL: openURL
        )

        // Move legacy single Keychain key onto the migrated OpenAI profile.
        if let legacy = loadAPIKeyFromKeychain(account: legacyKeychainAccount), !legacy.isEmpty {
            try? saveAPIKey(legacy, for: openAI.id)
        }

        var list = [ollama, openAI]
        list = ensureCannedProfiles(in: list)

        // Prefer matching the legacy active provider.
        switch legacyProvider() {
        case .ollama:
            if let id = list.first(where: { $0.provider == .ollama })?.id {
                activeProfileID = id
            }
        case .openAICompatible:
            // Prefer the migrated OpenAI profile (same URL/model) over a canned twin.
            activeProfileID = openAI.id
        }

        return list
    }

    private static func openNameFor(model: String, baseURL: String) -> String {
        let url = baseURL.lowercased()
        if url.contains("api.x.ai") || model.hasPrefix("grok") {
            return model == defaultOpenAIModel ? cannedSpaceXAIName : "SpaceXAI \(model)"
        }
        if url.contains("127.0.0.1:1234") || url.contains("localhost:1234") {
            return cannedLocalMLXName
        }
        return "OpenAI \(model)"
    }

    /// Add missing canned starters without duplicating equivalent profiles.
    private static func ensureCannedProfiles(in profiles: [AskForthModelProfile]) -> [AskForthModelProfile] {
        var list = profiles

        if !list.contains(where: { $0.provider == .ollama && $0.model == defaultOllamaModel }) {
            list.append(AskForthModelProfile(
                name: cannedOllamaName,
                provider: .ollama,
                model: defaultOllamaModel
            ))
        }

        if !list.contains(where: {
            $0.provider == .openAICompatible
                && $0.model == defaultOpenAIModel
                && $0.resolvedBaseURLString.contains("api.x.ai")
        }) {
            list.append(AskForthModelProfile(
                name: cannedSpaceXAIName,
                provider: .openAICompatible,
                model: defaultOpenAIModel,
                baseURL: defaultOpenAIBaseURL
            ))
        }

        let localURL = "http://127.0.0.1:1234/v1"
        if !list.contains(where: {
            $0.provider == .openAICompatible
                && ($0.baseURL.contains("127.0.0.1:1234") || $0.baseURL.contains("localhost:1234"))
        }) {
            let path = defaultQwenMLXPath
            let modelPath = FileManager.default.fileExists(atPath: path)
                ? path
                : path // still seed the expected path so the user can edit if missing
            let local = AskForthModelProfile(
                name: cannedLocalMLXName,
                provider: .openAICompatible,
                model: modelPath,
                baseURL: localURL
            )
            list.append(local)
            if !hasKeychainAPIKey(for: local.id) {
                try? saveAPIKey("local", for: local.id)
            }
        }

        return list
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
