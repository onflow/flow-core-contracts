import "RandomBeaconHistory"

/// Retrieves the source of randomness for the requested block height from the RandomBeaconHistory contract.
///
pub fun main(atBlockHeight: UInt64): [UInt8] {
    return RandomBeaconHistory.sourceOfRandomness(atBlockHeight: atBlockHeight)
}