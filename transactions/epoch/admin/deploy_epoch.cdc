transaction(name: String, 
            code: [UInt8],
            currentEpochCounter: UInt64,
            numViewsInEpoch: UInt64,
            numViewsInStakingAuction: UInt64,
            numViewsInDKGPhase: UInt64,
            numCollectorClusters: UInt16,
            FLOWsupplyIncreasePercentage: UFix64,
            randomSource: String,
            collectorClusters: [String]
            clusterQCs: [String],
            dkgPubKeys: [String]) {

  prepare(signer: AuthAccount) {

    signer.contracts.add(name: name, 
            code: code,
            currentEpochCounter: currentEpochCounter,
            numViewsInEpoch: numViewsInEpoch,
            numViewsInStakingAuction: numViewsInStakingAuction, 
            numViewsInDKGPhase: numViewsInDKGPhase, 
            numCollectorClusters: numCollectorClusters,
            FLOWsupplyIncreasePercentage: FLOWsupplyIncreasePercentage,
            randomSource: randomSource,
            collectorClusters: [],
            clusterQCs: [],
            dkgPubKeys: [])
  }
}