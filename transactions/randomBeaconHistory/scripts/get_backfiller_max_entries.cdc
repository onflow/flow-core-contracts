import "RandomBeaconHistory"

access(all) fun main(): UInt64 {
    let backfiller = RandomBeaconHistory.borrowBackfiller() ?? panic("Problem borrowing backfiller")
    return backfiller.getMaxEntriesPerCall()
}
