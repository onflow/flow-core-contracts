import "RandomBeaconHistory"

transaction(maxEntries: UInt64) {
    prepare(acct: AuthAccount) {
        let backfiller = acct.borrow<&RandomBeaconHistory.Backfiller>(
            from: /storage/randomBeaconHistoryBackfiller
        ) ?? panic("Could not borrow backfiller resource")
    
        backfiller.setMaxEntriesPerCall(max: maxEntries) 
    } 
}
