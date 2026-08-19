import Foundation
import CryptoKit
import Security

enum AppleIDTokenValidator {

    enum ValidationError: LocalizedError {

        case invalidToken
        case unsupportedAlgorithm
        case invalidIssuer
        case invalidAudience
        case expiredToken
        case nonceMismatch
        case keyNotFound
        case signatureVerificationFailed
        case networkFailure(String)

        var errorDescription: String? {
            switch self {
            case .invalidToken:
                return "The Apple identity token could not be read."

            case .unsupportedAlgorithm:
                return "The Apple identity token uses an unsupported algorithm."

            case .invalidIssuer:
                return "The Apple identity token issuer is invalid."

            case .invalidAudience:
                return "The Apple identity token audience is invalid."

            case .expiredToken:
                return "The Apple identity token has expired."

            case .nonceMismatch:
                return "The Apple identity token nonce could not be verified."

            case .keyNotFound:
                return "Apple's signing key could not be found."

            case .signatureVerificationFailed:
                return "The Apple identity token signature could not be verified."

            case .networkFailure(let message):
                return "Could not reach Apple's servers: \(message)"
            }
        }
    }

    struct JWTHeader: Decodable {
        let alg: String
        let kid: String
    }

    struct JWTPayload: Decodable {
        let iss: String
        let aud: String
        let exp: Double
        let nonce: String
    }

    private struct JWKSResponse: Decodable {
        let keys: [JWK]
    }

    private struct JWK: Decodable {
        let kty: String
        let kid: String
        let alg: String
        let n: String
        let e: String
    }

    private struct TokenParts {
        let header: String
        let payload: String
        let signature: String
    }

    static func randomNonceString(
        length: Int = 32
    ) -> String {

        let charset =
            Array(
                "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZ"
                + "abcdefghijklmnopqrstuvwxyz-._"
            )

        var result = ""
        var remaining = length

        while remaining > 0 {

            var random = [UInt8](repeating: 0, count: 16)

            _ = SecRandomCopyBytes(
                kSecRandomDefault,
                random.count,
                &random
            )

            for byte in random where remaining > 0 {

                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {

        let digest = SHA256.hash(
            data: Data(input.utf8)
        )

        return digest.map {
            String(format: "%02x", $0)
        }.joined()
    }

    static func validate(
        _ token: Data,
        nonce rawNonce: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        guard let parts = split(token) else {
            completion(.failure(ValidationError.invalidToken))
            return
        }

        guard let header = decodeHeader(parts.header),
              header.alg == "RS256" else {
            completion(
                .failure(ValidationError.unsupportedAlgorithm)
            )
            return
        }

        guard let payload = decodePayload(parts.payload) else {
            completion(.failure(ValidationError.invalidToken))
            return
        }

        guard payload.iss == "https://appleid.apple.com" else {
            completion(.failure(ValidationError.invalidIssuer))
            return
        }

        guard payload.aud == Bundle.main.bundleIdentifier else {
            completion(.failure(ValidationError.invalidAudience))
            return
        }

        guard payload.exp > Date().timeIntervalSince1970 else {
            completion(.failure(ValidationError.expiredToken))
            return
        }

        guard payload.nonce == sha256(rawNonce) else {
            completion(.failure(ValidationError.nonceMismatch))
            return
        }

        fetchSigningKeys { result in

            switch result {

            case .success(let keys):

                guard let key = keys.first(where: {
                    $0.kid == header.kid
                }) else {
                    completion(
                        .failure(ValidationError.keyNotFound)
                    )
                    return
                }

                guard let publicKey = try? key.secKey() else {
                    completion(
                        .failure(ValidationError.keyNotFound)
                    )
                    return
                }

                guard let signature = base64URLDecode(
                    parts.signature
                ) else {
                    completion(
                        .failure(ValidationError.invalidToken)
                    )
                    return
                }

                let message = Data(
                    (parts.header + "." + parts.payload).utf8
                )

                var error: Unmanaged<CFError>?

                let valid = SecKeyVerifySignature(
                    publicKey,
                    .rsaSignatureMessagePKCS1v15SHA256,
                    message as CFData,
                    signature as CFData,
                    &error
                )

                if valid {
                    completion(.success(()))
                } else {
                    completion(
                        .failure(
                            ValidationError
                                .signatureVerificationFailed
                        )
                    )
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func split(
        _ token: Data
    ) -> TokenParts? {

        guard let string = String(
            data: token,
            encoding: .utf8
        ) else {
            return nil
        }

        let parts = string.components(
            separatedBy: "."
        )

        guard parts.count == 3 else {
            return nil
        }

        return TokenParts(
            header: parts[0],
            payload: parts[1],
            signature: parts[2]
        )
    }

    private static func decodeHeader(
        _ segment: String
    ) -> JWTHeader? {

        guard let data = base64URLDecode(segment) else {
            return nil
        }

        return try? JSONDecoder().decode(
            JWTHeader.self,
            from: data
        )
    }

    private static func decodePayload(
        _ segment: String
    ) -> JWTPayload? {

        guard let data = base64URLDecode(segment) else {
            return nil
        }

        return try? JSONDecoder().decode(
            JWTPayload.self,
            from: data
        )
    }

    private static func fetchSigningKeys(
        completion: @escaping (Result<[JWK], Error>) -> Void
    ) {

        guard let url = URL(
            string: "https://appleid.apple.com/auth/keys"
        ) else {
            completion(
                .failure(
                    ValidationError.networkFailure(
                        "invalid URL"
                    )
                )
            )
            return
        }

        let task = URLSession.shared.dataTask(
            with: url
        ) { data, _, error in

            if let error = error {
                completion(
                    .failure(
                        ValidationError.networkFailure(
                            error.localizedDescription
                        )
                    )
                )
                return
            }

            guard let data = data,
                  let response = try? JSONDecoder().decode(
                      JWKSResponse.self,
                      from: data
                  ) else {
                completion(
                    .failure(
                        ValidationError.networkFailure(
                            "invalid response"
                        )
                    )
                )
                return
            }

            completion(.success(response.keys))
        }

        task.resume()
    }

    private static func base64URLDecode(
        _ string: String
    ) -> Data? {

        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        if base64.count % 4 != 0 {
            base64.append(
                String(
                    repeating: "=",
                    count: 4 - base64.count % 4
                )
            )
        }

        return Data(base64Encoded: base64)
    }
}

private extension AppleIDTokenValidator.JWK {

    func secKey() throws -> SecKey {

        guard let modulus = Data(
                base64URLEncoded: n
            ),
            let exponent = Data(
                base64URLEncoded: e
            ) else {
            throw AppleIDTokenValidator
                .ValidationError
                .keyNotFound
        }

        let der = DER.rsaPublicKey(
            modulus: modulus,
            exponent: exponent
        )

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: modulus.count * 8
        ]

        var error: Unmanaged<CFError>?

        guard let key = SecKeyCreateWithData(
            der as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            throw AppleIDTokenValidator
                .ValidationError
                .keyNotFound
        }

        return key
    }
}

private extension Data {

    init?(base64URLEncoded: String) {

        var base64 = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        if base64.count % 4 != 0 {
            base64.append(
                String(
                    repeating: "=",
                    count: 4 - base64.count % 4
                )
            )
        }

        self.init(base64Encoded: base64)
    }
}

private enum DER {

    static func length(_ value: Int) -> Data {

        if value < 0x80 {
            return Data([UInt8(value)])
        }

        var bytes: [UInt8] = []
        var v = value

        while v > 0 {
            bytes.insert(UInt8(v & 0xFF), at: 0)
            v >>= 8
        }

        return Data(
            [UInt8(0x80 | bytes.count)]
        ) + Data(bytes)
    }

    static func tag(
        _ byte: UInt8,
        content: Data
    ) -> Data {

        Data([byte])
            + length(content.count)
            + content
    }

    static func integer(_ data: Data) -> Data {

        var bytes = Data(data)

        if let first = bytes.first,
           first & 0x80 != 0 {
            bytes.insert(0x00, at: 0)
        }

        return tag(0x02, content: bytes)
    }

    static func rsaPublicKey(
        modulus: Data,
        exponent: Data
    ) -> Data {

        let sequence = integer(modulus)
            + integer(exponent)

        return tag(0x30, content: sequence)
    }
}