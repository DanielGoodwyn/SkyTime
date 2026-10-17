import Foundation
import Combine
import AuthenticationServices
import UIKit

public struct SkyUser: Codable, Identifiable {
    public var id: String { uid }
    public let uid: String
    public let email: String
    public let displayName: String?
    public let idToken: String?
    public let refreshToken: String?
    
    public init(uid: String, email: String, displayName: String? = nil, idToken: String? = nil, refreshToken: String? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.idToken = idToken
        self.refreshToken = refreshToken
    }
}

public struct FirebaseConfig {
    // Shared Firebase project settings (can be overridden via Firebase console or config file)
    public static var apiKey: String = "AIzaSyCzUEuK46_qHYzxSS07GAprhtupTYsBNbs"
    public static var projectId: String = "goodwyn-babynames" // Defaults to Daniel Goodwyn Firebase project, dynamically updated if custom project ID provided
    public static var authDomain: String = "goodwyn-babynames.firebaseapp.com"
}

public class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        let window = windowScene?.windows.first(where: { $0.isKeyWindow })
            ?? windowScene?.windows.first
        return window ?? ASPresentationAnchor()
    }
}

@MainActor
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()
    
    @Published public var currentUser: SkyUser? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil
    
    private let userDefaultsKey = "skytime_cached_user"
    private let authPresentationContext = WebAuthPresentationContext()
    
    public init() {
        loadCachedUser()
    }
    
    private func loadCachedUser() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(SkyUser.self, from: data) {
            self.currentUser = user
        }
    }
    
    public func saveUser(_ user: SkyUser?) {
        self.currentUser = user
        if let user = user, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }
    
    public func signOut() {
        saveUser(nil)
        errorMessage = nil
        successMessage = "Signed out successfully."
    }
    
    // MARK: - Consolidated Begin (Sign In / Sign Up)
    public func begin(email rawEmail: String, password: String) async {
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, email.contains("@") else {
            self.errorMessage = "Please enter a valid email address."
            return
        }
        guard !password.isEmpty else {
            self.errorMessage = "Please enter a password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        
        // Step 1: Attempt to Sign In
        do {
            let user = try await executeSignIn(email: email, password: password)
            self.saveUser(user)
            self.successMessage = "Welcome back, \(user.email)!"
            return
        } catch let err as NSError {
            let msg = err.localizedDescription
            
            // If user doesn't exist or enumeration protected -> try Sign Up
            if msg.contains("EMAIL_NOT_FOUND") || msg.contains("INVALID_LOGIN_CREDENTIALS") || msg.contains("INVALID_CREDENTIAL") {
                do {
                    let newUser = try await executeSignUp(email: email, password: password)
                    self.saveUser(newUser)
                    self.successMessage = "Account created! Welcome, \(newUser.email)!"
                    return
                } catch let signUpErr as NSError {
                    let signUpMsg = signUpErr.localizedDescription
                    if signUpMsg.contains("EMAIL_EXISTS") {
                        self.errorMessage = "Incorrect password. If you forgot your password, tap 'Forgot Password'."
                    } else if signUpMsg.contains("WEAK_PASSWORD") {
                        self.errorMessage = "Password should be at least 6 characters."
                    } else {
                        self.errorMessage = signUpMsg
                    }
                    return
                }
            } else if msg.contains("INVALID_PASSWORD") || msg.contains("WRONG_PASSWORD") {
                self.errorMessage = "Incorrect password. If you forgot your password, tap 'Forgot Password'."
            } else {
                self.errorMessage = msg
            }
        }
    }
    
    // MARK: - Forgot Password
    public func sendPasswordReset(email rawEmail: String) async {
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, email.contains("@") else {
            self.errorMessage = "Please enter your email address to reset your password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(FirebaseConfig.apiKey)") else {
            self.errorMessage = "Invalid auth endpoint."
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "requestType": "PASSWORD_RESET",
            "email": email
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            
            if let error = json["error"] as? [String: Any],
               let msg = error["message"] as? String {
                self.errorMessage = formatFirebaseError(msg)
            } else {
                self.successMessage = "Password reset email sent to \(email). Check your inbox."
            }
        } catch {
            self.errorMessage = "Network error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Begin with Google
    public func beginWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        // OAuth via ASWebAuthenticationSession pointing to SkyTime Auth Bridge
        let scheme = "skytime-auth"
        guard let authURL = URL(string: "https://danielgoodwyn.com/SkyTime/auth-ios.html") else {
            self.errorMessage = "Invalid Google Auth configuration."
            return
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        self.errorMessage = error.localizedDescription
                    }
                    continuation.resume()
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume()
                    return
                }
                
                // Parse returned tokens or user info from skytime-auth://
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    continuation.resume()
                    return
                }
                let queryItems = components.queryItems ?? []
                let getParam = { (name: String) -> String? in queryItems.first(where: { $0.name == name })?.value }
                
                guard let uid = getParam("uid"), !uid.isEmpty else {
                    if let err = getParam("error") {
                        self.errorMessage = err
                    }
                    continuation.resume()
                    return
                }
                
                let email = getParam("email") ?? "danielgoodwyn@gmail.com"
                let displayName = getParam("displayName") ?? email.components(separatedBy: "@").first
                let idToken = getParam("idToken")
                let refreshToken = getParam("refreshToken")
                
                let user = SkyUser(uid: uid, email: email, displayName: displayName, idToken: idToken, refreshToken: refreshToken)
                self.saveUser(user)
                self.successMessage = "Signed in with Google as \(email)!"
                continuation.resume()
            }
            session.presentationContextProvider = self.authPresentationContext
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
    
    // MARK: - Private REST calls
    private func executeSignIn(email: String, password: String) async throws -> SkyUser {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(FirebaseConfig.apiKey)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        
        if let error = json["error"] as? [String: Any], let msg = error["message"] as? String {
            throw NSError(domain: "FirebaseAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        
        guard let uid = json["localId"] as? String else {
            throw NSError(domain: "FirebaseAuth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Authentication failed."])
        }
        let idToken = json["idToken"] as? String
        let refreshToken = json["refreshToken"] as? String
        let displayName = json["displayName"] as? String
        
        return SkyUser(uid: uid, email: email, displayName: displayName, idToken: idToken, refreshToken: refreshToken)
    }
    
    private func executeSignUp(email: String, password: String) async throws -> SkyUser {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(FirebaseConfig.apiKey)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        
        if let error = json["error"] as? [String: Any], let msg = error["message"] as? String {
            throw NSError(domain: "FirebaseAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        
        guard let uid = json["localId"] as? String else {
            throw NSError(domain: "FirebaseAuth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Account creation failed."])
        }
        let idToken = json["idToken"] as? String
        let refreshToken = json["refreshToken"] as? String
        
        return SkyUser(uid: uid, email: email, displayName: email.components(separatedBy: "@").first, idToken: idToken, refreshToken: refreshToken)
    }
    
    private func formatFirebaseError(_ code: String) -> String {
        switch code {
        case "EMAIL_NOT_FOUND":
            return "No account found with this email."
        case "INVALID_PASSWORD":
            return "Incorrect password."
        case "USER_DISABLED":
            return "This user account has been disabled."
        case "EMAIL_EXISTS":
            return "An account with this email already exists."
        case "OPERATION_NOT_ALLOWED":
            return "Email/password accounts are not enabled."
        case "TOO_MANY_ATTEMPTS_TRY_LATER":
            return "Too many attempts. Please try again later."
        default:
            return code.replacingOccurrences(of: "_", with: " ").lowercased().capitalized
        }
    }
}
