import "RandomBeaconHistory"

access(all) fun main(backfillerAddress: Address): UInt64? {
    let backfiller = getAuthAccount(backfillerAddress).borrow<&RandomBeaconHistory.Backfiller>(from: /storage/randomBeaconHistoryBackfiller)
    return backfiller?.getMaxEntriesPerCall() ?? nil
}