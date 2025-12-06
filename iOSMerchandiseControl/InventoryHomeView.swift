import SwiftUI

struct InventoryHomeView: View {
    @EnvironmentObject var excelSession: ExcelSessionViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)   // <<< cambiato, niente .accent

            Text("Inventario")
                .font(.title2)
                .bold()

            Text("Qui potrai caricare file Excel, fare pre-elaborazione e lavorare sulla griglia.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Text("Per ora è solo uno scheletro (step 2).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Inventario")
    }
}

#Preview {
    InventoryHomeView()
        .environmentObject(ExcelSessionViewModel())
}
