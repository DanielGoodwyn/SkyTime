import SwiftUI

public struct AuthView: View {
    @ObservedObject var authManager = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var email: String = "danielgoodwyn@gmail.com"
    @State private var password: String = ""
    @State private var isForgotPasswordMode: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with celestial logo
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 24/255, green: 54/255, blue: 122/255),
                                                Color(red: 184/255, green: 80/255, blue: 120/255),
                                                Color(red: 242/255, green: 140/255, blue: 64/255)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 72, height: 72)
                                    .shadow(color: Color(red: 242/255, green: 140/255, blue: 64/255).opacity(0.4), radius: 12)
                                
                                Image(systemName: "sun.and.horizon.fill")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Begin SkyTime")
                                .font(.system(size: 26, weight: .medium, design: .default))
                                .foregroundColor(.white)
                            
                            Text("Sign in or start a new account with your email")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 16)
                        
                        // Logged in state
                        if let user = authManager.currentUser {
                            VStack(spacing: 16) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color(red: 0.3, green: 0.85, blue: 0.5))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Signed in")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(user.email)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                
                                Button(action: {
                                    authManager.signOut()
                                }) {
                                    Text("Sign Out")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.red.opacity(0.9))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.12))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 24)
                        } else {
                            // Auth Input Card
                            VStack(spacing: 18) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Email")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.75))
                                    
                                    TextField("Enter your email", text: $email)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .padding(14)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(10)
                                        .foregroundColor(.white)
                                }
                                
                                if !isForgotPasswordMode {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Password")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.75))
                                        
                                        SecureField("Enter your password", text: $password)
                                            .padding(14)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(10)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                // Status / Error feedback
                                if let error = authManager.errorMessage {
                                    Text(error)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }
                                
                                if let success = authManager.successMessage {
                                    Text(success)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(red: 0.35, green: 0.9, blue: 0.55))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }
                                
                                // Primary Action: Begin or Reset
                                if isForgotPasswordMode {
                                    Button(action: {
                                        Task {
                                            await authManager.sendPasswordReset(email: email)
                                        }
                                    }) {
                                        HStack {
                                            if authManager.isLoading {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .padding(.trailing, 6)
                                            }
                                            Text("Send Password Reset Email")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            LinearGradient(
                                                colors: [Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.4, green: 0.3, blue: 0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    .disabled(authManager.isLoading)
                                    
                                    Button(action: {
                                        isForgotPasswordMode = false
                                        authManager.errorMessage = nil
                                        authManager.successMessage = nil
                                    }) {
                                        Text("Back to Begin")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(.top, 4)
                                } else {
                                    Button(action: {
                                        Task {
                                            await authManager.begin(email: email, password: password)
                                            if authManager.currentUser != nil {
                                                dismiss()
                                            }
                                        }
                                    }) {
                                        HStack {
                                            if authManager.isLoading {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .padding(.trailing, 6)
                                            }
                                            Text("Begin")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 24/255, green: 54/255, blue: 122/255),
                                                    Color(red: 184/255, green: 80/255, blue: 120/255),
                                                    Color(red: 242/255, green: 140/255, blue: 64/255)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .shadow(color: Color(red: 242/255, green: 140/255, blue: 64/255).opacity(0.35), radius: 8, y: 3)
                                    }
                                    .disabled(authManager.isLoading)
                                    
                                    // Forgot password link
                                    Button(action: {
                                        isForgotPasswordMode = true
                                        authManager.errorMessage = nil
                                        authManager.successMessage = nil
                                    }) {
                                        Text("Forgot your password?")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.65))
                                    }
                                    .padding(.top, 2)
                                    
                                    // Divider
                                    HStack {
                                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                                        Text("or")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.45))
                                            .padding(.horizontal, 8)
                                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                                    }
                                    .padding(.vertical, 6)
                                    
                                    // Begin with Google
                                    Button(action: {
                                        Task {
                                            await authManager.beginWithGoogle()
                                            if authManager.currentUser != nil {
                                                dismiss()
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "g.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                            Text("Begin with Google")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .disabled(authManager.isLoading)
                                }
                            }
                            .padding(20)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
