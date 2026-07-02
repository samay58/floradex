import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Profile", systemImage: "person.crop.circle")
            } description: {
                Text("Settings and preferences arrive when there is something to set.")
            }
            .navigationTitle("Profile")
        }
    }
}
