/*

    This contract defines a collection for staking and delegating objects
    which allows users to stake and delegate for as many nodes as they want in a single account.

 */

// import FungibleToken from 0xFUNGIBLETOKENADDRESS
// import FlowToken from 0xFLOWTOKENADDRESS
// import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS
// import StakingProxy from 0xSTAKINGPROXYADDRESS
// import LockedTokens from 0xLOCKEDTOKENSADDRESS

pub contract StakingProxyCollection {

    pub let StakingProxyCollectionStoragePath: StoragePath
    pub let StakingProxyCollectionPublicPath: PublicPath

    pub struct DelegatorIDs {
        pub let delegatorNodeID: String
        pub let delegatorID: UInt32

        init(nodeID: String, delegatorID: UInt32) {
            self.delegatorNodeID = nodeID
            self.delegatorID = delegatorID
        }
    }

    pub resource interface StakingProxyCollectionPublic {

        pub fun getNodeIDs(): [String]
        
        pub fun getDelegatorIDs(): [DelegatorIDs]

        pub fun getNodeInfo(nodeID: String): FlowIDTableStaking.NodeInfo?
        pub fun getAllNodeInfo(): [FlowIDTableStaking.NodeInfo]

        pub fun getDelegatorInfo(delegatorNodeID: String, delegatorID: UInt32): FlowIDTableStaking.DelegatorInfo
        pub fun getAllDelegatorInfo(): [FlowIDTableStaking.DelegatorInfo]
    }

    /// The resource that stakers store in their accounts to store
    /// all their staking objects and staking proxies

    pub resource Collection: StakingProxyCollectionPublic {

        access(self) var vaultCapability: Capability<&FlowToken.Vault>

        access(self) var lockedVaultHolder: @LockedTokens.LockedVaultHolder?

        access(self) var lockedNodeStakers: @{String: FlowIDTableStaking.NodeStaker}
        access(self) var lockedNodeDelegators: @{String: {UInt32: FlowIDTableStaking.NodeDelegator}}

        access(self) var nodeStakers: @{String: FlowIDTableStaking.NodeStaker}
        access(self) var nodeDelegators: @{String: {UInt32: FlowIDTableStaking.NodeDelegator}}

        access(self) var nodeStakingProxies: {String: AnyStruct{StakingProxy.NodeStakerProxy}}
        access(self) var delegatingProxies: {String: {UInt32: AnyStruct{StakingProxy.NodeDelegatorProxy}}}

        init(vaultCapability: Capability<&FlowToken.Vault>) {
            pre {
                vaultCapability.check(): "Invalid FlowToken.Vault capability"
            }
            self.vaultCapability = vaultCapability

            self.lockedVaultHolder = nil
            self.lockedNodeStakers = {}
            self.lockedNodeDelegators = {}

            self.nodeStakers = {}
            self.nodeDelegators = {}

            self.nodeStakingProxies = {}
            self.delegatingProxies = {}
        }

        pub fun addLockedVault(tokenHolder: &LockedTokens.TokenHolder) {
            let lockedVaultHolder <- LockedTokens.createLockedVaultHolder()

            let lockedTokenManager = tokenHolder.borrowTokenManager()

            lockedVaultHolder.addVault(lockedVault: lockedTokenManager.vault)

            self.lockedVaultHolder <- lockedVaultHolder
        }

        // Operations to add staking objects

        pub fun addStakingProxy(nodeID: String, delegatorID: UInt32?, proxy: AnyStruct) {
            if delegatorID == nil {

            }
            
        }

        pub fun removeStakingProxy(nodeID: String, delegatorID: UInt32?): AnyStruct? {
            if delegatorID == nil {

            }
            
        }

        pub fun registerLockedTokenNode(nodeInfo: StakingProxy.NodeInfo, amount: UFix64) {

        }

        pub fun registerLockedTokenDelegator(nodeID: String, amount: UFix64) {

        }

        pub fun addUnlockedNodeStaker(_ nodeStaker: @FlowIDTableStaking.NodeStaker) {
            
        }

        pub fun removeUnlockedNodeStaker(nodeID: String): @FlowIDTableStaking.NodeStaker {

        }

        pub fun addUnlockedNodeDelegator(_ nodeDelegator: @FlowIDTableStaking.NodeDelegator) {

        }

        pub fun removeUnlockedNodeDelegator(nodeID: String, delegatorID: UInt32): @FlowIDTableStaking.NodeDelegator {

        }

        // Staking Operations

        pub fun stakeNewTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {

        }

        pub fun stakeUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64)

        pub fun stakeRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64)

        pub fun requestUnstaking(nodeID: String, delegatorID: UInt32?, amount: UFix64)

        pub fun unstakeAll(nodeID: String, delegatorID: UInt32?)

        pub fun withdrawUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64)

        pub fun withdrawRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64)

        // Getters

        pub fun getNodeIDs(): [String] {}
        
        pub fun getDelegatorIDs(): [DelegatorIDs] {}

        pub fun getNodeInfo(nodeID: String): FlowIDTableStaking.NodeInfo? {}

        pub fun getAllNodeInfo(): [FlowIDTableStaking.NodeInfo] {}

        pub fun getDelegatorInfo(delegatorNodeID: String, delegatorID: UInt32): FlowIDTableStaking.DelegatorInfo {}

        pub fun getAllDelegatorInfo(): [FlowIDTableStaking.DelegatorInfo] {}

    }

    init() {
        self.StakingProxyCollectionStoragePath = /storage/nodeOperator
        self.StakingProxyCollectionPublicPath = /public/nodeOperator
    }
}
