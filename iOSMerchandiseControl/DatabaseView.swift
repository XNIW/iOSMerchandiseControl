import SwiftUI
import SwiftData

struct DatabaseView: View {
    @Environment(\.modelContext) private var context

    // Tutti i prodotti dal database, ordinati per barcode
    @Query(sort: \Product.barcode, order: .forward)
    private var products: [Product]

    @State private var barcodeFilter: String = ""
    @State private var showAddSheet = false
    @State private var productToEdit: Product?

    // filtro in memoria sui prodotti, come facevi in Compose
    private var filteredProducts: [Product] {
        let trimmed = barcodeFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return products
        } else {
            return products.filter { product in
                product.barcode.localizedStandardContains(trimmed)
            }
        }
    }

    var body: some View {
        VStack {
            // campo filtro barcode
            HStack {
                TextField("Filtra per barcode", text: $barcodeFilter)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal)
            .padding(.top)

            // lista prodotti
            List {
                ForEach(filteredProducts) { (product: Product) in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.productName ?? "Senza nome")
                            .font(.headline)

                        Text("Barcode: \(product.barcode)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let qty = product.stockQuantity {
                            Text("Stock: \(qty)")
                                .font(.footnote)
                        }

                        if let supplierName = product.supplier?.name,
                           !supplierName.isEmpty {
                            Text("Fornitore: \(supplierName)")
                                .font(.footnote)
                        }

                        if let categoryName = product.category?.name,
                           !categoryName.isEmpty {
                            Text("Categoria: \(categoryName)")
                                .font(.footnote)
                        }
                    }
                    .contentShape(Rectangle()) // tutta la riga tappabile
                    .onTapGesture {
                        productToEdit = product
                    }
                }
                .onDelete(perform: deleteProducts)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Database")
        .toolbar {
            // bottone per aprire Cronologia
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink {
                    HistoryView()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }

            // bottone per aggiungere nuovo prodotto
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
        .sheet(item: $productToEdit) { (product: Product) in
            NavigationStack {
                EditProductView(product: product)
            }
        }
    }

    // cancellazione con swipe-to-delete
    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let product = filteredProducts[index]
            context.delete(product)
        }
        do {
            try context.save()
        } catch {
            print("Errore durante l'eliminazione: \(error)")
        }
    }
}
