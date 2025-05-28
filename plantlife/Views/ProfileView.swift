import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Metrics.Padding.large) {
                Spacer()
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primaryGreen)
                
                Text("Profile")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Settings and user preferences coming soon")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.systemBackground)
            .navigationTitle("Profile")
        }
        .navigationViewStyle(.stack)
    }
}

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
#endif 