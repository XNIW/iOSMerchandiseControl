struct ProductPriceRemoteSupabaseAdapter: OptionsSyncRemoteCountFetching {
    let a = "product_prices"
    let b = "sync_events"
    func dryRun() { print("DryRun Preview ManualPush") }
}
