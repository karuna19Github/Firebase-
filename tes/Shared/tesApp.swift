//
//  tesApp.swift
//  Shared
//
//  Created by Karuna on 2022/6/28.
//

import SwiftUI
import Firebase

@main
struct tesApp: App {
    init() {
          FirebaseApp.configure()
      }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
