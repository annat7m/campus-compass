import SwiftUI
import SwiftData

struct SignUpView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss

    // Passed from SettingsView → ContentView
    @Binding var selectedTab: Int
    var session: UserSession
    @Binding var settingsPath: NavigationPath   // NEW

    // Form fields
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    @State private var userExists = false

    // Toast visibility
    @State private var showSuccessToast = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Input Fields
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            // Sign Up Button
            Button("Sign Up") {
                signUp()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)

        

            if userExists {
                Text("Username already exists")
                    .foregroundColor(.red)
                    .padding(.top, 5)
            }

            Spacer()
        }
        .padding()
        .overlay(
            Group {
                if showSuccessToast {
                    Text("Account Created!")
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

    // MARK: - Sign Up Logic
    private func signUp() {
        
        // 1. Check if username exists
        if getUser(username: username) != nil {
            userExists = true
            return
        }

        // 2. Create new profile
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
            return
        }
        
        // 3. Validate save
        if let savedUser = getUser(username: username) {
            print("✅ User saved:", savedUser.userName)

            // Store in session
            session.currentUser = savedUser
            userExists = false

            // Show toast
            showSuccessToast = true

            // Auto-dismiss toast + move to home tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccessToast = false
                settingsPath = NavigationPath()   // clears Settings view stack
                dismiss()                         // pops Login/Signup off the stack
                selectedTab = 0                   // go to Home tab

            }

        } else {
            print("❌ User was NOT saved!")
        }
    }

    // MARK: - Helper
    private func getUser(username: String) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userName == username }
        )
        return try? context.fetch(descriptor).first
    }
}
