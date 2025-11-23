import SwiftUI
import SwiftData

struct SignUpView: View {
    @Environment(\.modelContext) private var context
    
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    @State private var userExists = false
    
    @State private var showSuccessToast = false
    @State private var navigateToHome = false

    var body: some View {
        NavigationStack {

            // Navigation trigger
            NavigationLink(destination: HomeView(),
                           isActive: $navigateToHome) {
                EmptyView()
            }

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
                    signUp()
                }
                .buttonStyle(.borderedProminent)
                
                HStack {
                    Text("Already have an account?")
                    NavigationLink(destination: LoginView()) {
                        Text("Log In")
                            .fontWeight(.semibold)
                    }
                }

                if userExists {
                    Text("Username already exists")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .overlay(
                Group {
                    if showSuccessToast {
                        Text("Account Created!")
                            .padding()
                            .background(.green.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: showSuccessToast)
                    }
                }
            )
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

            showSuccessToast = true

            // hide toast + navigate after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccessToast = false
                navigateToHome = true
            }

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
