import SwiftUI
import SwiftData

struct DatabaseView: View {
    @Environment(\.modelContext) private var context

    // Tutti i prodotti dal database, ordinati per nome
    @Query(sort: \Product.productName, order: .forward)
    private var products: [Product]

    @State private var barcodeFilter: String = ""
    @State private var showAddSheet = false
    @State private var productToEdit: Product?

    var body: some View {
        // filtro in memoria sui prodotti
        let filteredProducts = products.filter { product in
            barcodeFilter.isEmpty ||
            product.barcode.localizedStandardContains(barcodeFilter)
        }

        VStack {
            // ----------- FILTRO BARCODE -----------
            HStack {
                TextField("Filtra per barcode", text: $barcodeFilter)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !barcodeFilter.isEmpty {
                    Button {
                        barcodeFilter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding([.horizontal, .top])

            // ----------- LISTA PRODOTTI -----------
            List {
                ForEach(filteredProducts) { product in
                    VStack(alignment: .leading) {
                        Text(product.productName ?? "Senza nome")
                            .font(.headline)
                        Text("Barcode: \(product.barcode)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())          // rende tappabile tutta la riga
                    .onTapGesture {
                        productToEdit = product
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let product = filteredProducts[index]
                        context.delete(product)
                    }
                    try? context.save()
                }
            }
        }
        .navigationTitle("Database")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // Sheet per NUOVO prodotto
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                EditProductView()
            }
        }
        // Sheet per MODIFICA prodotto esistente
        .sheet(item: $productToEdit) { product in
            NavigationStack {
                EditProductView(product: product)
            }
        }
    }
}
