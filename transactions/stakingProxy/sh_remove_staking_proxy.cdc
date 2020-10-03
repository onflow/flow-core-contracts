import Lockbox from 0xf3fcd2c1a78f5eee
import StakingProxy from 0x179b6b1cb6755e31

transaction(nodeID: String) {

    prepare(acct: AuthAccount) {
        let proxyHolder = acct.borrow<&StakingProxy.NodeStakerProxyHolder>(from: paStakingProxy.NodeOperatorCapabilityStoragePathth)

        proxyHolder.removeStakingProxy(nodeID: nodeID)
    }
}