/*

    This contract defines a collection for staking and delegating objects
    which allows users to stake and delegate for as many nodes as they want in a single account.

 */

// import FungibleToken from 0xFUNGIBLETOKENADDRESS
// import FlowToken from 0xFLOWTOKENADDRESS
// import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS
// import StakingProxy from 0xSTAKINGPROXYADDRESS
// import LockedTokens from 0xLOCKEDTOKENSADDRESS

pub contract StakingCollection {

    pub let StakingCollectionStoragePath: StoragePath
    pub let StakingCollectionPublicPath: PublicPath

    // Struct that stores delegator ID info
    pub struct DelegatorIDs {
        pub let delegatorNodeID: String
        pub let delegatorID: UInt32

        init(nodeID: String, delegatorID: UInt32) {
            self.delegatorNodeID = nodeID
            self.delegatorID = delegatorID
        }
    }

    pub resource interface StakingCollectionPublic {

        pub fun getNodeIDs(): [String]
        
        pub fun getDelegatorIDs(): [DelegatorIDs]

        pub fun getAllNodeInfo(): [FlowIDTableStaking.NodeInfo]

        pub fun getAllDelegatorInfo(): [FlowIDTableStaking.DelegatorInfo]
    }

    /// The resource that stakers store in their accounts to store
    /// all their staking objects and staking proxies

    pub resource Collection: StakingCollectionPublic {

        // unlocked vault
        access(self) var vaultCapability: Capability<&FlowToken.Vault>

        // locked vault
        access(self) var lockedVaultHolder: @LockedTokens.LockedVaultHolder?

        access(self) var nodeStakers: @{String: FlowIDTableStaking.NodeStaker}
        access(self) var nodeDelegators: @{String: {UInt32: FlowIDTableStaking.NodeDelegator}}

        access(self) var tokenHolder: Capability<LockedTokens.TokenHolder>?

        // Tracks how many locked tokens each node or delegator uses
        // When committing new locked tokens, add those tokens to the value
        // when withdrawing locked tokens, subtract from the value
        //
        access(self) var numLockedTokensForNode: {String: UFix64}
        access(self) var numLockedTokensForDelegator: {String: {UInt32: UFix64}}

        init(vaultCapability: Capability<&FlowToken.Vault>, tokenHolder: Capability<LockedTokens.TokenHolder>?) {
            pre {
                vaultCapability.check(): "Invalid FlowToken.Vault capability"
            }
            self.vaultCapability = vaultCapability

            self.lockedVaultHolder = nil
            self.tokenHolder = tokenHolder

            // If the account has a locked account, initialize its token holder
            // and locked vault holder from the LockedTokens contract
            if let tokenHolderObj = self.tokenHolder {
                let lockedVaultHolder <- LockedTokens.createLockedVaultHolder()

                lockedTokenManager = tokenHolder.borrowTokenManager()

                lockedVaultHolder.addVault(lockedVault: lockedTokenManager.vault)

                self.lockedVaultHolder <- lockedVaultHolder
            } else {
                self.lockedVaultHolder = nil
            }

            self.nodeStakers = {}
            self.nodeDelegators = {}
        }

        // function to add an existing node object
        pub fun addNodeObject(node: @FlowIDTableStaking.NodeStaker) {

        }

        pub fun addDelegatorObject(delegator: @FlowIDTableStaking.NodeDelegator) {

        }

        // Operations to register new staking objects

        pub fun registerNode(nodeInfo: StakingProxy.NodeInfo, amount: UFix64) {

        }

        pub fun registerDelegator(nodeID: String, amount: UFix64) {

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

        pub fun getNodeIDs(): [String] {

        }
        
        pub fun getDelegatorIDs(): [DelegatorIDs] {

        }

        pub fun getAllNodeInfo(): {String: FlowIDTableStaking.NodeInfo} {

        }

        pub fun getAllDelegatorInfo(): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {

        }

    }

    // getter functions for account staking information

    pub fun getNodeIDs(address: Address): [String] {}
        
    pub fun getDelegatorIDs(address: Address): [DelegatorIDs] {}

    pub fun getAllNodeInfo(address: Address): [{String: FlowIDTableStaking.NodeInfo} {}

    pub fun getAllDelegatorInfo(address: Address): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {}

    init() {
        self.StakingCollectionStoragePath = /storage/nodeOperator
        self.StakingCollectionPublicPath = /public/nodeOperator
    }
}
