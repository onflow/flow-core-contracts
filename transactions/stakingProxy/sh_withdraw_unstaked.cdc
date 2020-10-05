import StakingProxy from 0x179b6b1cb6755e31

transaction(nodeID: String, amount: UFix64) {

    prepare(acct: AuthAccount) {
        let proxyHolder = acct.borrow<&StakingProxy.NodeStakerProxyHolder>(from: StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow reference to staking proxy holder")

        let stakingProxy = proxyHolder.borrowStakingProxy(nodeID: nodeID)!

        stakingProxy.withdrawUnstakedTokens(amount: amount)
    }
}