import "FlowClusterQC"

transaction(name: String, 
            code: [UInt8],
            currentEpochCounter: UInt64,
            numViewsInEpoch: UInt64,
            numViewsInStakingAuction: UInt64,
            numViewsInDKGPhase: UInt64,
            numCollectorClusters: UInt16,
            FLOWsupplyIncreasePercentage: UFix64,
            randomSource: String,
            collectorClusters: [FlowClusterQC.Cluster],
            clusterQCs: [FlowClusterQC.ClusterQC],
            dkgPubKeys: [String]) {

  prepare(signer: auth(AddContract) &Account) {

    signer.contracts.add(name: name, 
            code: code,
            currentEpochCounter: currentEpochCounter,
            numViewsInEpoch: numViewsInEpoch,
            numViewsInStakingAuction: numViewsInStakingAuction, 
            numViewsInDKGPhase: numViewsInDKGPhase, 
            numCollectorClusters: numCollectorClusters,
            FLOWsupplyIncreasePercentage: FLOWsupplyIncreasePercentage,
            randomSource: randomSource,
            collectorClusters: [] as [FlowClusterQC.Cluster],
            clusterQCs: [] as [FlowClusterQC.ClusterQC],
            dkgPubKeys: [] as [String])
  }
}