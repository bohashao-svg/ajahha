import Foundation
import CryptoKit

// MARK: - Storage Service
final class StorageService {

    static let shared = StorageService()
    private init() { loadTasks() }

    // Storage key for encryption
    private let storagePassphrase = "rh_local_storage_v1"
    private lazy var storageKey: SymmetricKey = CryptoUtils.deriveKey(from: storagePassphrase)

    // MARK: - API Key (Keychain)
    private let apiKeyKeychainKey = "com.runninghub.apikey"

    var apiKey: String? {
        get { KeychainHelper.load(forKey: apiKeyKeychainKey) }
        set {
            if let v = newValue, !v.isEmpty {
                KeychainHelper.save(v, forKey: apiKeyKeychainKey)
            } else {
                KeychainHelper.delete(forKey: apiKeyKeychainKey)
            }
        }
    }

    var hasAPIKey: Bool { !(apiKey?.isEmpty ?? true) }

    // MARK: - Settings (UserDefaults)
    private let defaults = UserDefaults.standard

    var isPlusDefault: Bool {
        get { defaults.object(forKey: "plusDefault") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "plusDefault") }
    }

    // MARK: - Tasks (Encrypted UserDefaults)
    private let tasksKey = "rh_tasks_encrypted"
    private(set) var tasks: [RHTask] = []

    private func loadTasks() {
        guard let data = defaults.data(forKey: tasksKey) else { return }
        do {
            tasks = try CryptoUtils.decryptCodable(data, key: storageKey, as: [RHTask].self)
        } catch {
            tasks = []
        }
    }

    private func persistTasks() {
        do {
            let encrypted = try CryptoUtils.encryptCodable(tasks, key: storageKey)
            defaults.set(encrypted, forKey: tasksKey)
        } catch {}
    }

    func upsertTask(_ task: RHTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        } else {
            tasks.insert(task, at: 0)
        }
        persistTasks()
    }

    func deleteTask(id: String) {
        tasks.removeAll { $0.id == id }
        persistTasks()
    }

    func clearAllTasks() {
        tasks = []
        defaults.removeObject(forKey: tasksKey)
    }

    func clearAll() {
        clearAllTasks()
        apiKey = nil
    }
}
