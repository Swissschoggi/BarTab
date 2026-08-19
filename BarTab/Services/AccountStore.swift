import Foundation
import CommonCrypto
import Security

final class AccountStore {

    private let keychain = KeychainService(
        service: "com.bartab.accounts"
    )

    private let recordKey = "records"

    struct AccountRecord: Codable {
        let userID: UUID
        let username: String
        let salt: Data
        let passwordHash: Data
        let iterations: Int
        let createdAt: Date
    }

    enum AccountError: LocalizedError {

        case usernameTaken
        case accountNotFound
        case invalidCredentials

        var errorDescription: String? {
            switch self {
            case .usernameTaken:
                return "That username is already taken."

            case .accountNotFound:
                return "No account found for that username."

            case .invalidCredentials:
                return "Invalid username or password."
            }
        }
    }

    private var records: [AccountRecord] {
        get {
            guard let data = keychain.read(account: recordKey),
                  let decoded = try? JSONDecoder().decode(
                      [AccountRecord].self,
                      from: data
                  ) else {
                return []
            }

            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(
                newValue
            ) else {
                return
            }

            keychain.write(data, account: recordKey)
        }
    }

    func signUp(
        username: String,
        password: String
    ) throws -> User {

        let trimmed = username.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            throw AccountError.invalidCredentials
        }

        var current = records

        guard !current.contains(where: {
            $0.username.lowercased() == trimmed.lowercased()
        }) else {
            throw AccountError.usernameTaken
        }

        let salt = randomData(count: 16)
        let iterations = 100_000
        let hash = deriveKey(
            password: password,
            salt: salt,
            iterations: iterations
        )

        let user = User(
            id: UUID(),
            username: trimmed,
            createdAt: Date()
        )

        current.append(
            AccountRecord(
                userID: user.id,
                username: trimmed,
                salt: salt,
                passwordHash: hash,
                iterations: iterations,
                createdAt: user.createdAt
            )
        )

        records = current

        return user
    }

    func signIn(
        username: String,
        password: String
    ) throws -> User {

        let trimmed = username.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard let record = records.first(where: {
            $0.username.lowercased() == trimmed.lowercased()
        }) else {
            throw AccountError.accountNotFound
        }

        let hash = deriveKey(
            password: password,
            salt: record.salt,
            iterations: record.iterations
        )

        guard hash == record.passwordHash else {
            throw AccountError.invalidCredentials
        }

        return User(
            id: record.userID,
            username: record.username,
            createdAt: record.createdAt
        )
    }

    private func deriveKey(
        password: String,
        salt: Data,
        iterations: Int
    ) -> Data {

        var derived = Data(count: 32)

        derived.withUnsafeMutableBytes {
            derivedBytes in

            password.withCString { passwordBytes in

                salt.withUnsafeBytes { saltBytes in

                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes,
                        password.utf8.count,
                        saltBytes
                            .bindMemory(to: UInt8.self)
                            .baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(
                            kCCPRFHmacAlgSHA256
                        ),
                        UInt32(iterations),
                        derivedBytes
                            .bindMemory(to: UInt8.self)
                            .baseAddress,
                        derived.count
                    )
                }
            }
        }

        return derived
    }

    private func randomData(count: Int) -> Data {

        var data = Data(count: count)

        _ = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(
                kSecRandomDefault,
                count,
                bytes.bindMemory(
                    to: UInt8.self
                ).baseAddress!
            )
        }

        return data
    }
}