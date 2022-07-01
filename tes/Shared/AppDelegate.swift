//
//  AppDelegate.swift
//  tes
//
//  Created by Karuna on 2022/7/1.
//

import UIKit
import Firebase

class AppDelegate: NSObject {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
          
          FirebaseApp.configure()
          
          return true
}
}
