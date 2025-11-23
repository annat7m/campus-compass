import SwiftUI
import SwiftData

struct SignUpView: View {
    @Environment(\.modelContext) private var context
    
    // Binding so we can switch tabs (passed from SettingsView → ContentView)
    @Binding var selectedTab: Int
    
    // Form state
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    @State private var userExists = false
    
    // Toast + navigation state
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

            // "Already have an account?"
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
        
        // 1. Check if username already exists
        if getUser(username: username) != nil {
            userExists = true
            return
        }
        
        // 2. Insert new user
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
        
        // 3. Validate save
        if getUser(username: username) != nil {
            print("✅ User saved:", username)
            userExists = false
            
            // Show toast
            showSuccessToast = true
            
            // Hide toast + switch to Home tab after 3s
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccessToast = false
                selectedTab = 0   // ← Go to HOME tab
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
