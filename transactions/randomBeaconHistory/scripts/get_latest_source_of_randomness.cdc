import "RandomBeaconHistory"

access(all) fun main(): RandomBeaconHistory.RandomSource {
    return RandomBeaconHistory.sourceOfRandomnessAtBlockHeight(
        blockHeight: getCurrentBlock().height - 1
    )
}
