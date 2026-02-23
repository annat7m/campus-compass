//
//  LoginView.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 11/22/25.
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss

    @Binding var selectedTab: Int
    var session: UserSession
    @Binding var settingsPath: NavigationPath   // NEW

    @State private var username = ""
    @State private var password = ""
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessToast = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Log In")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Username field
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
            
            // Password field
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            // Log In button
            Button("Sign In") {
                login()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
            
            // Error message
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
            
            Spacer()
            
        }
        .padding()
        .overlay(
            Group {
                if showSuccessToast {
                    Text("Welcome back!")
                        .padding()
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: showSuccessToast)
                }
            }
        )
    }
    
    // MARK: - Login Logic
    private func login() {
        
        guard let user = getUser(username: username) else {
            showError = true
            errorMessage = "Username not found"
            return
        }
        
        if user.password != password {
            showError = true
            errorMessage = "Incorrect password"
            return
        }
        
        // Credentials are valid
        showError = false
        session.currentUser = user
        
        // ⭐ ADD TEST FAVORITES HERE ⭐
            if user.favorites.isEmpty {
                user.favorites.append(contentsOf: [
                    "Strain Science Center",
                    "Library",
                    "Taylor Auditorium"
                ])
                
                // Don't forget to save changes!
                do {
                    try context.save()
                } catch {
                    print("❌ Save failed:", error)
                    return
                }
                
            }
            
        // Show success toast
        showSuccessToast = true
        
        // Navigate after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSuccessToast = false
            settingsPath = NavigationPath()
            dismiss() // pops Login/Signup off the stack
            selectedTab = 0   // Switch to Home tab
        }
    }
    
    // MARK: - Fetch user
    private func getUser(username: String) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userName == username }
        )
        return try? context.fetch(descriptor).first
    }
}

