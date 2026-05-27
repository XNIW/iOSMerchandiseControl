import SwiftData
import SwiftUI

struct OptionsView: View {
    @Query private var localPendingChanges: [LocalPendingChange]

    var body: some View {
        Text("\(localPendingChanges.count)")
    }
}
