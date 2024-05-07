import "RandomBeaconHistory"

transaction(maxEntries: UInt64) {
    prepare(acct: auth(BorrowValue) &Account) {
        let backfiller = acct.storage.borrow<&RandomBeaconHistory.Backfiller>(
            from: /storage/randomBeaconHistoryBackfiller
        ) ?? panic("Could not borrow backfiller resource")
    
        backfiller.setMaxEntriesPerCall(max: maxEntries) 
    } 
}
