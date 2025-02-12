import "StakingProxy"

transaction(nodeID: String, amount: UFix64) {

    prepare(account: auth(BorrowValue) &Account) {
        let proxyHolder = account.storage.borrow<&StakingProxy.NodeStakerProxyHolder>(from: StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow reference to staking proxy holder")

        let stakingProxy = proxyHolder.borrowStakingProxy(nodeID: nodeID)!

        stakingProxy.withdrawRewardedTokens(amount: amount)
    }
}
