transaction(name: String, 
            code: [UInt8],
            numViewsInEpoch: UInt64,
            numViewsInStakingAuction: UInt64, 
            numViewsInDKGPhase: UInt64, 
            numCollectorClusters: UInt16, 
            randomSource: String,
            collectorClusters: [String]
            dkgPubKeys: [String],
            clusterQCs: [String]) {

  prepare(signer: AuthAccount) {

    signer.contracts.add(name: name, 
            code: code, 
            numViewsInEpoch: numViewsInEpoch,
            numViewsInStakingAuction: numViewsInStakingAuction, 
            numViewsInDKGPhase: numViewsInDKGPhase, 
            numCollectorClusters: numCollectorClusters, 
            randomSource: randomSource,
            collectorClusters: [],
            dkgPubKeys: dkgPubKeys,
            clusterQCs: clusterQCs)
  }
}