import "RandomBeaconHistory"

/// Retrieves the source of randomness for the requested block height from the RandomBeaconHistory contract.
///
access(all) fun main(page: UInt64, perPage: UInt64): RandomBeaconHistory.RandomSourceHistoryPage {
    return RandomBeaconHistory.getRandomSourceHistoryPage(page, perPage: perPage)
}
