//
//  SignInView.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 11/12/25.
//
import SwiftUI
import SwiftData

struct SignUpView: View {
    @Environment(\.modelContext) private var context
    
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    @State private var userExists = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)

                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                Button("Sign Up") {
                    print("Sign Up tapped")
                    signUp()
                }
                .buttonStyle(.borderedProminent)
                
                // 👉 Already have an account?
                HStack {
                    Text("Already have an account?")
                    
                    NavigationLink(destination: LoginView()) {
                        Text("Log In")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 10)
                
                if userExists {
                    Text("Username already exists")
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
    }

    private func signUp() {
        if getUser(username: username) != nil {
            userExists = true
            return
        }

        let newUser = UserProfile(
            name: name,
            userName: username,
            password: password
        )
        
        context.insert(newUser)
        
        do {
            try context.save()
        } catch {
            print("❌ Save failed:", error)
        }
        
        // validate
        if let savedUser = getUser(username: username) {
            print("✅ User saved:", savedUser.userName)
        } else {
            print("❌ User was NOT saved!")
        }

    }

    private func getUser(username: String) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userName == username }
        )
        return try? context.fetch(descriptor).first
    }
}
