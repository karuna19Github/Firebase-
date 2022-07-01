//
//  ContentView.swift
//  Shared
//
//  Created by Karuna on 2022/6/28.
//

import SwiftUI

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestoreSwift
import FirebaseFirestore

class AppViewModel: ObservableObject {
    
    let auth = Auth.auth()
    
    @Published var isNew = false
    @Published var signedIn = false
    
    func signIn(email: String, password: String, completion: @escaping((Result<String, LoginError>) -> Void)) {
        auth.signIn(withEmail: email, password: password) { result, error in
            guard result != nil, error == nil else {
                if (error?.localizedDescription == "Invalid Password") {
                    completion(.failure(LoginError.InvalidPW))
                }
                else if (error?.localizedDescription == "No user found") {
                    completion(.failure(LoginError.NoAccount))
                }
                else {
                    completion(.failure(LoginError.others))
                }
                return
            }
            completion(.success("Success"))
        }
    }
    
    func signUp(email: String, password: String, completion: @escaping((Result<String, RegError>) -> Void)) {
        auth.createUser(withEmail: email, password: password) { result, error in
            guard let user = result?.user , error == nil else {
                if (error?.localizedDescription == "Bad Format") {
                    completion(.failure(RegError.EmailFormat))
                }
                else if (error?.localizedDescription == "Password must be more than 6 characters") {
                    completion(.failure(RegError.ShortPw))
                }
                else if (error?.localizedDescription == "Email used") {
                    completion(.failure(RegError.EmailUsed))
                }
                else {
                    completion(.failure(RegError.others))
                }
                return
            }
            completion(.success(user.uid))
        }
    }
    
    func signOut() {
        try? auth.signOut()
        self.signedIn = false
    }
    
    func fetchUsers (completion: @escaping((Result<[UserData], NormalError>) -> Void)) {
        let db = Firestore.firestore()
        db.collection("Users_Data").getDocuments { snapshot, error in
            guard let snapshot = snapshot else { return }
            let users = snapshot.documents.compactMap { snapshot in
                try? snapshot.data(as: UserData.self)
                
            }
            completion(.success(users))
            if error?.localizedDescription != nil {
                completion(.failure(NormalError.error))
            }
        }
    }
    
    func uploadPhoto(image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
        
        let fileReference = Storage.storage().reference().child(UUID().uuidString + ".jpg")
        if let data = image.jpegData(compressionQuality: 0.9) {
            
            fileReference.putData(data, metadata: nil) { result in
                switch result {
                case .success(_):
                    fileReference.downloadURL(completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func setUserDisplayName(userDisplayName: String) -> Void {
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = userDisplayName
        changeRequest?.commitChanges(completion: { error in
            guard error == nil else {
                print(error?.localizedDescription as Any)
                print("there's problem with user display name")
                return
            }
        })
    }

    func setUserPhoto(url: URL, completion: @escaping((Result<String, NormalError>) -> Void)) {
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.photoURL = url
            completion(.success("set user photo successful"))
            changeRequest?.commitChanges(completion: { error in
               guard error == nil else {
                   print(error?.localizedDescription as Any)
                    completion(.failure(NormalError.error))
                   return
               }
            })
        }
        
    func createUserData(ud: UserData, uid: String, completion: @escaping((Result<String, NormalError>) -> Void)) {
        let db = Firestore.firestore()
        do {
            try db.collection("Users_Data").document(uid).setData(from: ud)
            completion(.success("create user data successful"))
        } catch {
            completion(.failure(NormalError.error))
            print(error)
        }
    }
}

enum RegError: Error {
    case EmailFormat
    case ShortPw
    case EmailUsed
    case others
}

enum LoginError: Error {
    case InvalidPW
    case NoAccount
    case others
}

enum NormalError: Error {
    case error
}

struct UserData:Codable, Identifiable {
    @DocumentID var id: String?
    let userGender: String
    let userBD: String
    let userFirstLogin: String
    let userCountry: String
}

var countries: [String] = []
var count = 1
struct ContentView: View {
    init() {
           UITableView.appearance().backgroundColor = .clear
       }
       @State var currentUser = Auth.auth().currentUser
       @State var userPhotoURL = URL(string: "")
       @State var currentUserData = UserData(id: "", userGender: "", userBD: "", userFirstLogin: "", userCountry: "")
       @EnvironmentObject var viewModel: AppViewModel
    var body: some View {
        NavigationView {
                    if viewModel.signedIn {
                        if viewModel.isNew == true {
                            FirstView()
                        }
                        else if viewModel.isNew == false {
                            VStack {
                                Form {
                                    HStack {
                                        Text("Information")
                                            .font(.system(size:27))
                                            .bold()
                                    }
                                    .frame(height:100)
                                    HStack {
                                        Spacer()
                                        KFImage(userPhotoURL)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100, height: 150)
                                        Spacer()
                                    }
                                    Group {
                                        HStack {
                                            Image(systemName: "person.crop.circle")
                                            if currentUser?.displayName != nil {
                                                Text("Username: " + (currentUser?.displayName)!)
                                            } else {
                                                Text("Username not found")
                                            }
                                        }
                                        HStack{
                                            Image(systemName: "g.circle")
                                            Text("Gender: " + currentUserData.userGender)
                                        }
                                        HStack{
                                            Image(systemName: "calendar")
                                            Text("Birthday: " + currentUserData.userBD)
                                        }
                                        HStack{
                                            Image(systemName: "globe")
                                            Text("Country: " + currentUserData.userCountry)
                                        }
                                        HStack{
                                            Image(systemName: "clock")
                                            Text("Last Signed In: " + currentUserData.userFirstLogin)
                                        }
                                        HStack{
                                            Image(systemName: "face.smiling")
                                        }
                                    }
                                }
                                Button(action: {
                                    viewModel.signOut()
                                }, label: {
                                    Text("Sign Out")
                                        .frame(width: 200, height: 50)
                                        .background(.blue)
                                        .foregroundColor(.white)
                                        .padding()
                                })
                            }
                        }
                    }
                    else {
                        SignInView()
                    }
                }
                .onAppear {
                    userPhotoURL = (currentUser?.photoURL)
                    viewModel.fetchUsers(){ result in
                        switch (result) {
                        case .success(let usersArray):
                            for u in usersArray {
                                if u.id == currentUser?.uid {
                                    currentUserData = u
                                    break
                                }
                            }
                        case .failure(_):
                            print("Photo can't be shown")
                        }
                    }
    }
    }
}
struct SignInView: View {
    @State var email = ""
    @State var password = ""
    @State var alertMsg = ""
    @State var showAlert = false
    @State var returnBool = false
    @EnvironmentObject var viewModel: AppViewModel
    var body: some View {
        VStack {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
            
            VStack {
                TextField("Email Address", text: $email)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .background(Color(.secondarySystemBackground))
                    .padding()
                SecureField("Password", text: $password)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .background(Color(.secondarySystemBackground))
                    .padding()
                
                Button(action: {
                    viewModel.signIn(email: email, password: password) {
                        (result) in
                        switch result {
                        case .success( _):
                            if let user = viewModel.auth.currentUser {
                                print("\(user.uid) Signed In!")
                                viewModel.fetchUsers() {
                                    (result) in
                                    switch result {
                                    case.success(let udArray):
                                        print("User Sign in!")
                                        for u in udArray {
                                            if u.id == user.uid {
                                                returnBool = true
                                            }
                                        }
                                        viewModel.signedIn = true
                                    case .failure(_):
                                        print("User not found")
                                        returnBool = false
                                    }
                                }
                            }
                            else {
                                print("Sign in Failed")
                            }
                        case .failure(let errormsg):
                            switch errormsg {
                            case .InvalidPW:
                                alertMsg = "Wrong Password"
                                showAlert = true
                            case .NoAccount:
                                alertMsg = "User not Found"
                                showAlert = true
                            case .others:
                                alertMsg = "Invalid Email"
                                showAlert = true
                            }
                        }
                    }
                }, label: {
                    Text("Sign In")
                        .foregroundColor(.white)
                        .frame(width:200, height:50)
                        .background(Color.blue)
                        .cornerRadius(8)
                })
                
                NavigationLink("Create Account", destination:SignUpView())
                    .padding()
            }
            .padding()
            
            
            Spacer()
        }
        .navigationTitle("Sign In")
    }
}


struct SignUpView: View {
    @State var email = ""
    @State var password = ""
    @State var alertMsg = ""
    @State var showAlert = false
    @State var returnBool = false
    @State var showFLView = false
    @State var myAlert = Alert(title: Text(""))
    @Environment(\.presentationMode) var presentationMode: Binding <PresentationMode>
                                            
    @EnvironmentObject var viewModel: AppViewModel
    
    func showAlertMsg(msg: String) -> Void {
        self.alertMsg = msg
        if alertMsg == "User Registered" {
            self.myAlert = Alert(title: Text("Successful"), message: Text(alertMsg), dismissButton: .cancel(Text("Set up"), action: changetoFirstView))
            self.showAlert = true
        }
        else {
            self.myAlert = Alert(title: Text("Failed"), message: Text(alertMsg), dismissButton: .cancel(Text("Error")))
            self.showAlert = true
        }
    }
    
    func changetoFirstView() -> Void {
        print(viewModel.auth.currentUser!.uid)
        self.presentationMode.wrappedValue.dismiss()
        self.showFLView = true
    }
    
    
    var body: some View {
        VStack {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
            
            VStack {
                TextField("Email Address", text: $email)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .background(Color(.secondarySystemBackground))
                    .padding()
                SecureField("Password", text: $password)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .background(Color(.secondarySystemBackground))
                    .padding()
                
                Button(action: {
                    if email != "" && password != "" {
                        viewModel.signUp(email: email, password: password) { (result) in
                            switch result {
                            case .success(_):
                                showAlertMsg(msg: "User Registered")
                            
                            case .failure(let errormsg):
                                print("Signed up Failed")
                                switch errormsg {
                                case .EmailFormat:
                                    showAlertMsg(msg: "Invalid Email")
                                case .EmailUsed:
                                    showAlertMsg(msg: "Email Used")
                                case .ShortPw:
                                    showAlertMsg(msg: "Password at least 6 characters")
                                case .others:
                                    showAlertMsg(msg: "Re Register")
                                }
                                break
                            }
                        }
                    }
                    else {
                        showAlertMsg(msg: "Username and Password can't be empty")
                    }
                }, label: {
                    Text("Register")
                        .foregroundColor(.white)
                        .frame(width:200, height:50)
                        .background(Color.blue)
                        .cornerRadius(8)
                })
            }.alert(isPresented: $showAlert) { () -> Alert in
                return myAlert
            }
            .padding()
            Spacer()
        }
        .navigationTitle("Create Account")
    }
}

struct FirstView: View {
    @State private var currentUser = Auth.auth().currentUser
    @State private var userDisplayName = ""
    @State private var userGender = ""
    @State private var userFirstLoginStr = ""
    @State private var userBirthday = Date()
    @State private var currentDate = Date()
    @State private var genderSelect = 0
    @State private var country = ""
    @State private var alertMsg = ""
    @State private var showAlert = false
    @State private var showContentView = false
    @State private var myAlert = Alert(title: Text(""))
    @State private var isShowPhotoLibrary = false
    @State private var image = UIImage()
    @State private var bool = false
    @State private var hairSelect = 0
    @State private var clothesSelect = 0
    @State private var faceSelect = 0
    @EnvironmentObject var viewModel: AppViewModel
    var gender = ["Male", "Female"]
    var hair = ["Bald","Short","Long"]
    var clothes = ["Tshirt","Sport","Formal"]
    var face = ["Smile","Calm","Cute"]
    let myDateFormatter = DateFormatter()
    let flgFormatter = DateFormatter()

    var body: some View {
        NavigationView{
            VStack{
                Form{
                    VStack{
                        Text("Custom Character")
                        Spacer()
                            .frame(height:20)
                        ZStack{
                            Image("Hair"+String(hairSelect+1))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 80)
                                .offset(x:-5)
                            Image("Face"+String(faceSelect+1))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 65, height: 65)
                                .offset(x:3,y:5)
                        }
                        Image("Body"+String(clothesSelect+1))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 100)
                            .offset(x:-12,y:-5)
                        Button{
                            randomPic()
                        }label:{
                            Text("Random")
                        }
                        HStack{
                            Picker(selection: $hairSelect, label: Text("select hair")){
                                ForEach(hair.indices){ index in
                                    Text(hair[index])
                                }
                            }
                        }.pickerStyle(SegmentedPickerStyle())
                        HStack{
                            Picker(selection: $clothesSelect, label: Text("Select Clothes")){
                                ForEach(clothes.indices){ index in
                                    Text(clothes[index])
                                }
                            }
                        }.pickerStyle(SegmentedPickerStyle())
                        HStack{
                            Picker(selection: $faceSelect, label: Text("Select Face")){
                                ForEach(face.indices){ index in
                                    Text(face[index])
                                }
                            }
                        }.pickerStyle(SegmentedPickerStyle())
                        
                    }
                    Group{
                        HStack{
                            Image(systemName: "person.fill")
                            TextField("Username: ", text: $userDisplayName)
                        }
                        HStack{
                            Image(systemName: "g.circle")
                            Text("Gender")
                            Spacer()
                            Picker(selection: $genderSelect, label: Text("Gender")) {
                                Text(gender[0]).tag(0)
                                Text(gender[1]).tag(1)
                            }.pickerStyle(SegmentedPickerStyle())
                            .frame(width: 100)
                            .shadow(radius: 5)
                        }
                        HStack{
                            Image(systemName: "calendar.circle")
                            DatePicker("Birthday", selection: $userBirthday, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                        }
                        TextField("Country: ", text: $country)
                    }
                    HStack{
                        Button(action:{
                            if userDisplayName == "" {
                                alertMsg = "Username can't be empty"
                                showAlert = true
                            }
                            else{
                                viewModel.setUserDisplayName(userDisplayName: userDisplayName)
                                let newUser = UserData(userGender: gender[genderSelect], userBD: myDateFormatter.string(from: userBirthday), userFirstLogin: userFirstLoginStr, userCountry: country)
                                viewModel.isNew = false
                                viewModel.createUserData(ud: newUser, uid: currentUser!.uid) {
                                    (result) in
                                    switch result {
                                    case .success(let sucmsg):
                                        print(sucmsg)
                                        uploadPhoto()
                                        bool.toggle()
                                    case .failure(_):
                                        print("Picture can't be uploaded")
                                    }
                                }
                            }
                        }){
                            Text("Continue")
                                .font(.system(size: 27))
                                .bold()
                                .frame(width: 150, height: 50)
                                .foregroundColor(.red)
                        }
                        .alert(isPresented: $showAlert) { () -> Alert in
                            return self.myAlert
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BgDark"))
        .navigationTitle("User Settings")
        .onAppear{
            myDateFormatter.dateFormat = "y MMM dd"
            flgFormatter.dateFormat = "y MMM dd HH:mm"
            self.userFirstLoginStr = flgFormatter.string(from: currentDate)
        }
        .fullScreenCover(isPresented: $bool, content: {
            ContentView()
        })
    }

    func randomPic() -> Void {
        hairSelect = Int.random(in: 0...2)
        clothesSelect = Int.random(in: 0...2)
        faceSelect = Int.random(in: 0...2)
    }
    
    func uploadPhoto() -> Void {
        let text = "char"+String(hairSelect+1)+String(clothesSelect+1)+String(faceSelect+1)
        let charImage = UIImage(named: text)
        viewModel.uploadPhoto(image: charImage!) { result in
            switch result {
            case .success(let url):
                print("Photo uploaded")
                viewModel.setUserPhoto(url: url) { result in
                    switch result {
                    case .success(let msg):
                        print(msg)
                        viewModel.signOut()
                    case .failure(_):
                        print("error")
                    }
                }
            case .failure(_):
               print("Photo can't be uploaded")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView() .preferredColorScheme(.dark)
    }
}
