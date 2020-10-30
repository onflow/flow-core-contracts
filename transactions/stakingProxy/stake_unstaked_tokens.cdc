import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction(nodeID: String, amount: UFix64) {

    prepare(account: AuthAccount) {
        let proxyHolder = account.borrow<&StakingProxy.NodeStakerProxyHolder>(from: StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow reference to staking proxy holder")

        let stakingProxy = proxyHolder.borrowStakingProxy(nodeID: nodeID)!

        stakingProxy.stakeUnstakedTokens(amount: amount)
    }
}
