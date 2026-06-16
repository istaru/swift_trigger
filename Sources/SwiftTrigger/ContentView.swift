import SwiftUI

struct ContentView: View {
    @State private var selection: String? = "automations"

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("自动化", systemImage: "bolt.fill")
                    .tag("automations")
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            AutomationListView()
        }
        .frame(minWidth: 680, minHeight: 480)
    }
}
