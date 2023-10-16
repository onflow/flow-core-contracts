import "RandomBeaconHistory"

/// Retrieves the source of randomness for the requested block height from the RandomBeaconHistory contract.
///
access(all) fun main(blockHeight: UInt64): RandomBeaconHistory.RandomSource {
    return RandomBeaconHistory.sourceOfRandomnessAtBlockHeight(blockHeight: blockHeight)
}
