//
//  tisk_iosApp.swift
//  tisk-ios
//
//  Created by Conrad Booker on 11/9/26.
//

import SwiftUI

@main
struct tisk_iosApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .signedOut:
                    AuthView()
                case .signedIn(let email):
                    RootView(email: email)
                }
            }
            .environment(auth)
            .animation(.easeInOut(duration: 0.15), value: auth.state.key)
        }
    }
}

private extension AuthStore.State {
    var key: Int {
        switch self {
        case .loading: 0
        case .signedOut: 1
        case .signedIn: 2
        }
    }
}
