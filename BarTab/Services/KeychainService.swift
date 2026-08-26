import Foundation
import Security

final class KeychainService {

    private let service: String

    init(service: String) {
        self.service = service
    }

    func read(account: String) -> Data? {

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &item
        )

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return data
    }

    @discardableResult
    func write(
        _ data: Data,
        account: String
    ) -> Bool {

        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemCopyMatching(
            base as CFDictionary,
            nil
        )

        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(
                base as CFDictionary,
                attributes as CFDictionary
            )
            return updateStatus == errSecSuccess
        } else {
            var add = base
            add[kSecValueData] = data
            add[kSecAttrAccessible] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
    }

    func delete(account: String) {

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ]

        SecItemDelete(query as CFDictionary)
    }
}