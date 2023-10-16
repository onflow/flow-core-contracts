import "RandomBeaconHistory"

access(all) fun main(): RandomBeaconHistory.RandomSource {
    return RandomBeaconHistory.sourceOfRandomness(
        atBlockHeight: getCurrentBlock().height - 1
    )
}
