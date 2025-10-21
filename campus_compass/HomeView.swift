//
//  HomeView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI

//struct HomeView: View {
//    var body: some View {
//        VStack(spacing: 12) {
//                    Image(systemName: "globe")
//                        .imageScale(.large)
//                    Text("Hello, world!")
//                        .font(.headline)
//                    Text("This is Home")
//                        .foregroundStyle(.secondary)
//                }
//                .padding()
//    }
//}

struct SearchBarView: View {
    
    @State private var searchText: String = ""
    var body: some View {
        TextField("Search...", text: .constant(""))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding()
    }
}
struct QuickActView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Title
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            // Action Buttons
            VStack(spacing: 12) {
                ActionButton(title: "View Campus Map", systemImage: "mappin.and.ellipse", action: {
                    print("View Campus Map tapped")
                })
                ActionButton(title: "Find Parking", systemImage: "mappin.and.ellipse", action: {
                    print("View Campus Map tapped")
                })
                ActionButton(title: "Find Dining Options", systemImage: "mappin.and.ellipse", action: {
                    print("View Campus Map tapped")
                })
            }
            .padding(.horizontal)
            
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .padding()
    }
}

// MARK: - Custom Button Component
import SwiftUI

/// A reusable button component for your app's menu-style lists.
struct ActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
                Text(title)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}


struct TitleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack{
                Text("Campus Compass")
                    .fontWeight(.bold)
                
                Spacer() // pushes the next item to the right edge

                            // Right side: profile icon button
                            Button(action: {
                                print("Profile tapped!") // replace with navigation or sheet later
                            }) {
                                Image(systemName: "person.circle.fill") // SF Symbol
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }
                        }
                        

            Divider()
            
            Spacer().frame(height: 30)
            
            Text("Campus Compass").font(.largeTitle,) .frame(maxWidth: .infinity, alignment: .center)
            Text("Navigate Pacific University with ease").frame(maxWidth: .infinity, alignment: .center).foregroundColor(.gray)
            SearchBarView()
            
            QuickActView()
            
        }
        .padding()
        Spacer()
    }
}





#Preview {
//    HomeView()
    TitleView()
    
}







