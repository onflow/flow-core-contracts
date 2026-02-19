import "StakingProxy"

transaction(nodeID: String, amount: UFix64) {

    prepare(account: auth(BorrowValue) &Account) {
        let proxyHolder = account.storage.borrow<auth(StakingProxy.NodeOperator) &StakingProxy.NodeStakerProxyHolder>(from: StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow reference to staking proxy holder")

        let stakingProxy = proxyHolder.borrowStakingProxy(nodeID: nodeID)!

        stakingProxy.requestUnstaking(amount: amount)
    }
}
