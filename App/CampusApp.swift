// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

@main
struct CampusApp: App {
    @StateObject private var store = CampusStore()
    var body: some Scene {
        WindowGroup { CampusTabs().environmentObject(store).tint(.indigo) }
    }
}
