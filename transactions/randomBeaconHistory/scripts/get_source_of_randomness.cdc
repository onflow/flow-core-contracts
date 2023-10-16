import "RandomBeaconHistory"

/// Retrieves the source of randomness for the requested block height from the RandomBeaconHistory contract.
///
access(all) fun main(atBlockHeight: UInt64): RandomBeaconHistory.RandomSource {
    return RandomBeaconHistory.sourceOfRandomness(atBlockHeight: atBlockHeight)
}
