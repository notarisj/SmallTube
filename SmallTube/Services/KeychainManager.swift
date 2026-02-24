import Foundation
import Security

/// A simple utility to store, retrieve, and delete strings in the Keychain
enum KeychainManager {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Accessible when the device is unlocked
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // Item exists, update it
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if status != errSecSuccess {
                print("Error updating keychain item: \(status)")
            }
        } else {
            // Item does not exist, insert it
            var newQuery = query
            newQuery.merge(attributes) { (_, new) in new }
            status = SecItemAdd(newQuery as CFDictionary, nil)
            if status != errSecSuccess {
                print("Error saving keychain item: \(status)")
            }
        }
    }
    
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
