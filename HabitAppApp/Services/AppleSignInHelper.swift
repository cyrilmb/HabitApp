//
//  AppleSignInHelper.swift
//  HabitTracker
//
//  Handles Sign in with Apple authentication flow
//

import AuthenticationServices
import CryptoKit
import Foundation

class AppleSignInHelper: NSObject {
    private var continuation: CheckedContinuation<(idToken: String, nonce: String), Error>?
    private var currentNonce: String?

    func signIn() async throws -> (idToken: String, nonce: String) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let nonce = Self.randomNonceString()
            currentNonce = nonce
            let hashedNonce = Self.sha256(nonce)

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            fatalError("Unable to generate random nonce")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInHelper: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            continuation?.resume(throwing: AppleSignInError.invalidCredential)
            continuation = nil
            return
        }

        continuation?.resume(returning: (idToken: idToken, nonce: nonce))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

enum AppleSignInError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Unable to retrieve Apple ID credentials."
        }
    }
}
