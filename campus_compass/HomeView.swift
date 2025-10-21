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

struct Title: View {
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
            
        }
        .padding()
        Spacer()
    }
}





#Preview {
//    HomeView()
    Title()
    
}







