// This contract defines an interface for node stakers
// to use to be able to perform common staking actions

// It also defines a resource that a node operator can
// use to store staking proxies for all of their node operation
// relationships 

pub contract StakingProxy {

    pub struct interface NodeDelegatorProxy {

        pub fun delegateNewTokens(amount: UFix64)

        pub fun delegateUnlockedTokens(amount: UFix64)
        
        pub fun delegateRewardedTokens(amount: UFix64)

        pub fun requestUnstaking(amount: UFix64)

        pub fun unstakeAll(amount: UFix64)

        pub fun withdrawUnlockedTokens(amount: UFix64)

        pub fun withdrawRewardedTokens(amount: UFix64)
    }

    /// Contains the node info associated with a node operator
    pub struct NodeInfo {

        pub let nodeID: String
        pub let networkingAddress: String
        pub let networkingKey: String
        pub let stakingKey: String

        init(nodeID: String, networkingAddress: String, networkingKey: String, stakingKey: String) {
            pre {
                networkingAddress.length > 0 && networkingKey.length > 0 && stakingKey.length > 0:
                        "Address and Key have to be the correct length"
            }
            self.nodeID = nodeID
            self.networkingAddress = networkingAddress
            self.networkingKey = networkingKey
            self.stakingKey = stakingKey
        }
    }

    /// The interface that limits what a node operator can access
    /// from the staker who they operate for
    pub struct interface NodeStakerProxy {

        pub fun stakeNewTokens(amount: UFix64)

        pub fun stakeUnlockedTokens(amount: UFix64)

        pub fun requestUnstaking(amount: UFix64)

        pub fun unstakeAll(amount: UFix64)

        pub fun withdrawUnlockedTokens(amount: UFix64)

        pub fun withdrawRewardedTokens(amount: UFix64)

    }

    pub resource interface NodeStakerProxyHolderPublic {
        
        pub fun addStakingProxy(nodeID: String, proxy: AnyStruct{NodeStakerProxy})

        pub fun getNodeInfo(nodeID: String): NodeInfo
    }

    pub resource NodeStakerProxyHolder: NodeStakerProxyHolderPublic {

        access(self) var stakingProxies: {String: AnyStruct{NodeStakerProxy}}

        access(self) var nodeInfo: {String: NodeInfo}

        init() {
            self.stakingProxies = {}
            self.nodeInfo = {}
        }

        pub fun addNodeInfo(nodeInfo: NodeInfo) {
            pre {
                self.nodeInfo[nodeInfo.nodeID] == nil
            }
            self.nodeInfo[nodeInfo.nodeID] = nodeInfo
        }

        pub fun removeNodeInfo(nodeID: String): NodeInfo {
            return self.nodeInfo.remove(key: nodeID)!
        }

        pub fun getNodeInfo(nodeID: String): NodeInfo {
            return self.nodeInfo[nodeID]!
        }

        pub fun addStakingProxy(nodeID: String, proxy: AnyStruct{NodeStakerProxy}) {
            pre {
                self.stakingProxies[nodeID] == nil
            }
            self.stakingProxies[nodeID] = proxy
        }

        pub fun removeStakingProxy(nodeID: String): AnyStruct{NodeStakerProxy} {
            pre {
                self.stakingProxies[nodeID] != nil
            }

            return self.stakingProxies.remove(key: nodeID)!
        }

        pub fun borrowStakingProxy(nodeID: String): AnyStruct{NodeStakerProxy} {
            return self.stakingProxies[nodeID]!
        }
    }

    pub fun createProxyHolder(): @NodeStakerProxyHolder {
        return <- create NodeStakerProxyHolder()
    }
}
