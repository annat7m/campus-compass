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
                if getUser(username: username) != nil {
                    userExists = true
                } else {
                    let newUser = UserProfile(
                        name: name,
                        userName: username,
                        password: password
                    )
                    context.insert(newUser)
                }
            }
        }
        .padding()
    }

    func getUser(username: String) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userName == username }
        )
        return try? context.fetch(descriptor).first
    }
}

