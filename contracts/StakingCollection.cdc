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

        // Gets tokens to commit to a node
        // Uses locked tokens first, if possible
        access(self) fun getTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64): @FungibleToken.Vault {
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            if let _lockedValutHolder = self.lockedVaultHolder {
                var lockedBalance: UFix64 = _lockedValutHolder.getVaultBalance()
                var unlockedBalance: UFix64 = self.vaultCapability.balance

                assert(
                    lockedBalance + unlockedBalance < amount,
                    messsage: "Insufficient total Flow balance"
                )

                if (amount <= lockedBalance) {
                    if (delegatorID != nil) {
                        self.numLockedTokensForDelegator[nodeID][delegatorID] = self.numLockedTokensForDelegator[nodeID][delegatorID] + amount
                    } else {
                        self.numLockedTokensForNode[nodeID] = self.numLockedTokensForNode[nodeID] + amount
                    }

                    return _lockedValutHolder.withdraw(amount: amount)
                } else {
                    if (delegatorID != nil) {
                        self.numLockedTokensForDelegator[nodeID][delegatorID] = self.numLockedTokensForDelegator[nodeID][delegatorID] + lockedBalance
                    } else {
                        self.numLockedTokensForNode[nodeID] = self.numLockedTokensForNode[nodeID] + lockedBalance
                    }

                    return _lockedValutHolder.withdraw(amount: lockedBalance).deposit(from: self.vaultCapability.withdraw(amount: amount - lockedBalance))
                }
            } else {
                var unlockedBalance: UFix64 = self.vaultCapability.balance

                assert(
                    unlockedBalance <= amount,
                    messsage: "Insufficient total Flow balance"
                )

                return self.vaultCapability.withdraw(amount: amount)
            }
        }

        // Tracks where tokens go to after being unstaked
        access(self) fun depositTokens(nodeID: String, delegatorID: UInt32?, from: @FungibleToken.Vault) {
            
        }

        access(self) fun doesStakeExist(nodeID: String, delegatorID: UInt32?): Bool {
            let tokenHolderNodeID: String? = self.tokenHolder != nil ? self.tokenHolder.getNodeID() : nil
            let tokenHolderDelegatorNodeID: String? = self.tokenHolder != nil ? self.tokenHolder.getDelegatorNodeID() : nil
            let tokenHolderDelegatorID: String? = self.tokenHolder != nil ? self.tokenHolder.getDelegatorID() : nil

            if let _delegatorID = delegatorID {
                if (tokenHolderDelegatorNodeID != nil && tokenHolderDelegatorID != nil && tokenHolderDelegatorNodeID == nodeID && tokenHolderDelegatorID == delegatorID) {
                    return true
                }

                return self.nodeDelegators[nodeID] != nil && self.nodeDelegators[nodeID][delegatorID] != nil
            } else {
                if (tokenHolderNodeID != nil && tokenHolderNodeID == nodeID) {
                    return true
                }

                return self.nodeStakers[nodeID] != nil
            }
        }

        init(vaultCapability: Capability<&FlowToken.Vault>, tokenHolder: Capability<LockedTokens.TokenHolder>?) {
            pre {
                vaultCapability.check(): "Invalid FlowToken.Vault capability"
            }
            self.vaultCapability = vaultCapability

            self.lockedVaultHolder = nil
            self.tokenHolder = tokenHolder

            self.nodeStakers = {}
            self.nodeDelegators = {}

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
        }

        // function to add an existing node object
        pub fun addNodeObject(node: @FlowIDTableStaking.NodeStaker) {
            self.nodeStakers[node.id] <- node
        }

        pub fun addDelegatorObject(delegator: @FlowIDTableStaking.NodeDelegator) {
            self.nodeStakers[node.nodeID][node.id] <- node
        }

        // Operations to register new staking objects

        pub fun registerNode(nodeInfo: StakingProxy.NodeInfo, amount: UFix64) {
            if let nodeStaker <- self.nodeStaker.borrowStaker() {
                let stakingInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)

                assert(
                    stakingInfo.tokensStaked + stakingInfo.totalTokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked + stakingInfo.tokensRewarded == 0.0,
                    message: "Cannot register a new node until all tokens from the previous node have been withdrawn"
                )

                destroy nodeStaker
            }

            destroy nodeStaker

            let tokens <- self.getTokens(amount: amount)

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(id: nodeInfo.id, role: nodeInfo.role, networkingAddress: nodeInfo.networkingAddress, networkingKey: nodeInfo.networkingKey, stakingKey: nodeInfo.stakingKey, tokensCommitted: <-tokens)

            destroy nodeStaker

            // Maybe should emit event here?
        }

        pub fun registerDelegator(nodeID: String, amount: UFix64) {
            if let nodeStaker <- self.nodeStaker.borrowDelegator() {
                let stakingInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)

                assert(
                    stakingInfo.tokensStaked + stakingInfo.totalTokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked + stakingInfo.tokensRewarded == 0.0,
                    message: "Cannot register a new node until all tokens from the previous node have been withdrawn"
                )

                destroy nodeStaker
            }

            destroy nodeStaker

            let tokens <- self.getTokens(amount: amount)

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(id: nodeInfo.id, role: nodeInfo.role, networkingAddress: nodeInfo.networkingAddress, networkingKey: nodeInfo.networkingKey, stakingKey: nodeInfo.stakingKey, tokensCommitted: <-tokens)

            destroy nodeStaker

            // Maybe should emit event here?
        }

        // Staking Operations

        pub fun stakeNewTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            if (delegatorID != nil) {
                let delegator = self.nodeDelegators[nodeID][delegatorID]

                delegator.delegateNewTokens(from: <- getTokens(nodeID: nodeID, delegatorID: delegatorID, amount: amount))
            } else {
                let delegator = self.nodeDelegators[nodeID][delegatorID]

                node.stakeNewTokens(from: <- getTokens(nodeID: nodeID, delegatorID: delegatorID, amount: amount))
            }
        }

        pub fun stakeUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            if (delegatorID != nil) {
                let delegator = self.nodeDelegators[nodeID][delegatorID]

                delegator.delegateUnstakedTokens(amount: amount)
            } else {
                let node = self.nodeStakers[nodeID]

                node.stakeUnstakedTokens(amount: amount)
            }
        }

        pub fun stakeRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            if (delegatorID != nil) {
                let delegator = self.nodeDelegators[nodeID][delegatorID]

                delegator.delegateRewardedTokens(amount: amount)
            } else {
                let node = self.nodeStakers[nodeID]

                node.stakeRewardedTokens(amount: amount)
            }
        }

        pub fun requestUnstaking(nodeID: String, delegatorID: UInt32?, amount: UFix64) { 
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            if (delegatorID != nil) {
                let delegator = self.nodeDelegators[nodeID][delegatorID]

                delegator.requestUnstaking(amount: amount)
            } else {
                let node = self.nodeStakers[nodeID]
                
                node.requestUnstaking(amount: amount)
            }
        }

        pub fun unstakeAll(nodeID: String, delegatorID: UInt32?) {
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            let node = self.nodeStakers[nodeID]
            
            node.unstakeAll(amount: amount)
        }

        pub fun withdrawUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) { 
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            if (delegatorID != nil) {
                let delegator = self.nodeDelegators[nodeID][delegatorID]

                self.depositTokens(nodeID: nodeID, delegatorID: delegatorID, from: <- node.withdrawUnstakedTokens(amount: amount))
            } else {
                let node = self.nodeStakers[nodeID]

                self.depositTokens(nodeID: nodeID, delegatorID: delegatorID, from: <- node.withdrawUnstakedTokens(amount: amount))
            }
        }

        pub fun withdrawRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            if (delegatorID != nil) {
                let delegator = self.nodeDelegators[nodeID][delegatorID]

                self.depositTokens(nodeID: nodeID, delegatorID: delegatorID, from: <- node.withdrawRewardedTokens(amount: amount))
            } else {
                let node = self.nodeStakers[nodeID]

                self.depositTokens(nodeID: nodeID, delegatorID: delegatorID, from: <- node.withdrawRewardedTokens(amount: amount))
            }
        }

        // Getters

        pub fun getNodeIDs(): [String] {
            return self.nodeStakers.keys
        }
        
        pub fun getDelegatorIDs(): [DelegatorID] {
            let nodeIDs: [String] = self.nodeStakers.keys
            let delegatorIDs: [DelegatorID] = []
            for nodeID in nodeIDs {
                let delegatorIDs: [UInt32] = self.nodeStakers[nodeID]

                for delegatorID in delegatorIDs {
                    ret.append(DelegatorID(nodeID: nodeID, delegatorID: delegatorID))
                }
            }

            return delegatorIDs
        }

        pub fun getAllNodeInfo(): {String: FlowIDTableStaking.NodeInfo} {
            return self.nodeStakers
        }

        pub fun getAllDelegatorInfo(): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {
            return self.nodeDelegators
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
