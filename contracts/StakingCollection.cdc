/*

    This contract defines a collection for staking and delegating objects
    which allows users to stake and delegate for as many nodes as they want in a single account.

 */

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS
import StakingProxy from 0xSTAKINGPROXYADDRESS
import LockedTokens from 0xLOCKEDTOKENSADDRESS

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
        // access(self) var lockedTokensForNode: {String: UFix64}
        // access(self) var tokensForDelegator: {String: {UInt32: UFix64}}

        access(self) var lockedTokensUsed: UFix64
        access(self) var unlockedTokensUsed: UFix64

        init(vaultCapability: Capability<&FlowToken.Vault>, tokenHolder: Capability<LockedTokens.TokenHolder>?) {
            pre {
                vaultCapability.check(): "Invalid FlowToken.Vault capability"
            }
            self.vaultCapability = vaultCapability

            self.lockedVaultHolder = nil
            self.tokenHolder = tokenHolder

            self.nodeStakers = {}
            self.nodeDelegators = {}

            self.lockedTokensUsed = UFix64(0)
            self.unlockedTokensUsed = UFix64(0)

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

        // Gets tokens to commit to a node. Uses locked tokens first, if possible
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
                    self.lockedTokensUsed = self.lockedTokensUsed + amount

                    return _lockedValutHolder.withdraw(amount: amount)
                } else {
                    self.lockedTokensUsed = self.lockedTokensUsed + lockedBalance
                    self.unlockedTokensUsed = self.unlockedTokensUsed + (amount - lockedBalance)

                    return _lockedValutHolder.withdraw(amount: lockedBalance).deposit(from: self.vaultCapability.withdraw(amount: amount - lockedBalance))
                }
            } else {
                var unlockedBalance: UFix64 = self.vaultCapability.balance

                assert(
                    unlockedBalance <= amount,
                    messsage: "Insufficient total Flow balance"
                )

                self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                return self.vaultCapability.withdraw(amount: amount)
            }
        }

        // Deposits tokens after being withdrawn from a Stake or Delegation. Deposits to unlocked tokens first, if possible.
        access(self) fun depositTokens(nodeID: String, delegatorID: UInt32?, from: @FungibleToken.Vault) {
            pre {
                delegatorID != nil && self.nodeDelegators[nodeID] != nil:
                    "Specified nodeID does not exist in the nodeDelegators record"

                delegatorID != nil && self.nodeDelegators[nodeID][delegatorID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeDelegators record"

                delegatorID == nil && self.nodeStakers[nodeID] != nil:
                    "Specified delegatorID for specified nodeID does not exist in the nodeStakers record"
            }

            if let _lockedValutHolder = self.lockedVaultHolder {

                if self.unlockedTokensUsed > UFix64(0) {
                    
                    if (from.balance < self.unlockedTokensUsed) {
                        self.unlockedTokensUsed = self.unlockedTokensUsed - from.balance

                        return _lockedValutHolder.deposit(from: <- from.withdraw(amount: from.balance))
                    } else {
                        self.unlockedTokensUsed = self.unlockedTokensUsed - self.unlockedTokensUsed

                        _lockedValutHolder.deposit(from: <- from.withdraw(amount: self.unlockedTokensUsed))
                    }
                }

            }

            self.lockedTokensUsed = self.lockedTokensUsed - from.balance

            _lockedValutHolder.deposit(from: <-from)
        }

        // Returns true if a Stake or Delegation record exists in the StakingCollection for a given nodeID and optional delegatorID, otherwise false.
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

        // Function to add an existing NodeStaker object
        pub fun addNodeObject(node: @FlowIDTableStaking.NodeStaker) {
            self.nodeStakers[node.id] <- node
        }

        // Function to add an existing NodeDelegator object
        pub fun addDelegatorObject(delegator: @FlowIDTableStaking.NodeDelegator) {
            self.nodeStakers[node.nodeID][node.id] <- node
        }

        // Operations to register new staking objects

        // Function to register a new Staking Record to the Staking Collection
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

        // Function to register a new Delegator Record to the Staking Collection
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

        // Function to stake new tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun stakeNewTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                let delegatorExistsInNodeDelegatorsDictionary = self.nodeDelegators[nodeID] != nil && self.nodeDelegators[nodeID][_delegatorID] != nil

                let delegator = delegatorExistsInNodeDelegatorsDictionary ? self.nodeDelegators[nodeID][_delegatorID] : self.tokenHolder.borrowDelegator()

                delegatorExistsInDictionary ? delegator.delegateNewTokens(from: <- getTokens(nodeID: nodeID, delegatorID: delegatorID, amount: amount)) : delegator.delegateNewTokens(amount: amount)
            } else {
                let stakerExistsInNodeStakersDictionary = self.nodeStakers[nodeID] != nil

                let staker = stakerExistsInNodeStakersDictionary ? self.nodeStakers[nodeID] != nil : self.tokenHolder.borrowStaker()

                stakerExistsInNodeStakersDictionary ? staker.stakeNewTokens(from: <- getTokens(nodeID: nodeID, delegatorID: delegatorID, amount: amount)) : staker.stakeNewTokens(amount: amount)
            }
        }

        // Function to stake unstaked tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun stakeUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                let delegatorExistsInNodeDelegatorsDictionary = self.nodeDelegators[nodeID] != nil && self.nodeDelegators[nodeID][_delegatorID] != nil

                let delegator = delegatorExistsInNodeDelegatorsDictionary ? self.nodeDelegators[nodeID][_delegatorID] : self.tokenHolder.borrowDelegator()

                delegator.delegateUnstakedTokens(amount: amount)
            } else {
                let stakerExistsInNodeStakersDictionary = self.nodeStakers[nodeID] != nil

                let staker = stakerExistsInNodeStakersDictionary ? self.nodeStakers[nodeID] : self.tokenHolder.borrowStaker()

                staker.stakeUnstakedTokens(amount: amount)
            }
        }

        // Function to stake rewarded tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun stakeRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                let delegatorExistsInNodeDelegatorsDictionary = self.nodeDelegators[nodeID] != nil && self.nodeDelegators[nodeID][_delegatorID] != nil

                let delegator = delegatorExistsInNodeDelegatorsDictionary ? self.nodeDelegators[nodeID][_delegatorID] : self.tokenHolder.borrowDelegator()

                delegator.delegateRewardedTokens(amount: amount)
            } else {
                let stakerExistsInNodeStakersDictionary = self.nodeStakers[nodeID] != nil

                let staker = stakerExistsInNodeStakersDictionary ? self.nodeStakers[nodeID] != nil : self.tokenHolder.borrowStaker()

                staker.stakeRewardedTokens(amount: amount)
            }
        }

        // Function to request tokens to be unstaked for an existing Stake or Delegation record in the StakingCollection
        pub fun requestUnstaking(nodeID: String, delegatorID: UInt32?, amount: UFix64) { 
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                let delegatorExistsInNodeDelegatorsDictionary = self.nodeDelegators[nodeID] != nil && self.nodeDelegators[nodeID][_delegatorID] != nil

                let delegator = delegatorExistsInNodeDelegatorsDictionary ? self.nodeDelegators[nodeID][_delegatorID] : self.tokenHolder.borrowDelegator()

                delegator.requestUnstaking(amount: amount)
            } else {
                let stakerExistsInNodeStakersDictionary = self.nodeStakers[nodeID] != nil

                let staker = stakerExistsInNodeStakersDictionary ? self.nodeStakers[nodeID] != nil : self.tokenHolder.borrowStaker()
                
                staker.requestUnstaking(amount: amount)
            }
        }

        // Function to unstake all tokens for an existing Staking record in the StakingCollection
        pub fun unstakeAll(nodeID: String) {
            pre {
                self.doesStakeExist(nodeID: nodeID) == false : "Specified stake does not exist"
            }
            
            let stakerExistsInNodeStakersDictionary = self.nodeStakers[nodeID] != nil

            let staker = stakerExistsInNodeStakersDictionary ? self.nodeStakers[nodeID] != nil : self.tokenHolder.borrowStaker()
            
            staker.unstakeAll(amount: amount)
        }

        // Function to withdraw unstaked tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun withdrawUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) { 
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                let delegatorExistsInNodeDelegatorsDictionary = self.nodeDelegators[nodeID] != nil && self.nodeDelegators[nodeID][_delegatorID] != nil

                let delegator = delegatorExistsInNodeDelegatorsDictionary ? self.nodeDelegators[nodeID][_delegatorID] : self.tokenHolder.borrowDelegator()

                delegatorExistsInNodeDelegatorsDictionary ?
                    self.depositTokens(nodeID: nodeID, delegatorID: delegatorID, from: <- delegator.withdrawUnstakedTokens(amount: amount))
                    :
                    delegator.withdrawUnstakedTokens(amount: amount)

            } else {
                let stakerExistsInNodeStakersDictionary = self.nodeStakers[nodeID] != nil

                let staker = stakerExistsInNodeStakersDictionary ? self.nodeStakers[nodeID] != nil : self.tokenHolder.borrowStaker()

                stakerExistsInNodeStakersDictionary ?     
                    self.depositTokens(nodeID: nodeID, delegatorID: delegatorID, from: <- staker.withdrawUnstakedTokens(amount: amount))
                    :
                    staker.withdrawUnstakedTokens(amount: amount)
            }
        }

        // Function to withdraw rewarded tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun withdrawRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                let delegatorExistsInNodeDelegatorsDictionary = self.nodeDelegators[nodeID] != nil && self.nodeDelegators[nodeID][_delegatorID] != nil

                let delegator =delegatorExistsInNodeDelegatorsDictionary ? self.nodeDelegators[nodeID][_delegatorID] : self.tokenHolder.borrowDelegator()

                delegatorExistsInNodeDelegatorsDictionary ?
                    self.depositTokens(nodeID: nodeID, delegatorID: delegatorID, from: <- delegator.withdrawRewardedTokens(amount: amount))
                    :
                    delegator.withdrawRewardedTokens(amount: amount)
            } else {
                let stakerExistsInNodeStakersDictionary = self.nodeStakers[nodeID] != nil

                let staker = stakerExistsInNodeStakersDictionary ? self.nodeStakers[nodeID] != nil : self.tokenHolder.borrowStaker()

                stakerExistsInNodeStakersDictionary ?     
                    self.depositTokens(nodeID: nodeID, delegatorID: delegatorID, from: <- staker.withdrawRewardedTokens(amount: amount))
                    :
                    staker.withdrawRewardedTokens(amount: amount)
            }
        }

        // Getters

        // Function to get all node ids for all Staking records in the StakingCollection
        pub fun getNodeIDs(): [String] {
            let nodeIDs: [String] = self.nodeStakers.keys

            if let _tokenHolder = self.tokenHolder {
                let tokenHolderNodeID = _tokenHolder.getNodeID()
                if let _tokenHolderNodeID = tokenHolderNodeID {
                    nodeIDs.append(_tokenHolderNodeID)
                }
            }

            return nodeIDs
        }

        // Function to get all delegator ids for all Delegation records in the StakingCollection
        pub fun getDelegatorIDs(): [DelegatorID] {
            let nodeIDs: [String] = self.nodeDelegators.keys
            let delegatorIDs: [DelegatorID] = []
            for nodeID in nodeIDs {
                let delegatorIDs: [UInt32] = self.nodeDelegators[nodeID]

                for delegatorID in delegatorIDs {
                    ret.append(DelegatorID(nodeID: nodeID, delegatorID: delegatorID))
                }
            }

            if let _tokenHolder = self.tokenHolder {
                let tokenHolderDelegatorNodeID = _tokenHolder.getDelegatorNodeID()
                let tokenHolderDelegatorID = _tokenHolder.getDelegatorID()

                if let _tokenHolderDelegatorNodeID = tokenHolderDelegatorNodeID {
                    if let _tokenHolderDelegatorID = tokenHolderDelegatorID {
                        nodeIDs.append(DelegatorID(nodeID: _tokenHolderDelegatorNodeID, delegatorID: _tokenHolderDelegatorID))
                    }
                }
            }

            return delegatorIDs
        }

        // Function to get all Node Info records for all Staking records in the StakingCollection
        pub fun getAllNodeInfo(): {String: FlowIDTableStaking.NodeInfo} {
            let nodeInfo = {}

            let nodeIDs: [String] = self.nodeStakers.keys
            for nodeID in nodeIDs {
                nodeInfo[nodeID] = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
            }

            if let _tokenHolder = self.tokenHolder {
                let tokenHolderNodeID = _tokenHolder.getNodeID()
                if let _tokenHolderNodeID = tokenHolderNodeID {
                    nodeInfo[_tokenHolderNodeID] = FlowIDTableStaking.NodeInfo(nodeID: _tokenHolderNodeID)
                }
            }

            return nodeInfo
        }

        // Function to get all Delegator Info records for all Delegation records in the StakingCollection
        pub fun getAllDelegatorInfo(): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {
            let nodeInfo = {}

            let nodeIDs: [String] = self.nodeDelegators.keys
            for nodeID in nodeIDs {
                let delegatorIDs: [UInt32] = self.nodeDelegators[nodeID]

                for delegatorID in delegatorIDs {
                    nodeInfo[nodeID][delegatorID] = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
                }
            }

            if let _tokenHolder = self.tokenHolder {
                let tokenHolderDelegatorNodeID = _tokenHolder.getDelegatorNodeID()
                let tokenHolderDelegatorID = _tokenHolder.getDelegatorID()

                if let _tokenHolderDelegatorNodeID = tokenHolderDelegatorNodeID {
                    if let _tokenHolderDelegatorID = tokenHolderDelegatorID {
                        nodeInfo[_tokenHolderDelegatorNodeID][_tokenHolderDelegatorID] = FlowIDTableStaking.DelegatorInfo(nodeID: _tokenHolderDelegatorNodeID, delegatorID: _tokenHolderDelegatorID)
                    }
                }
            }

            return nodeInfo
        }

    } 

    // Getter functions for accounts StakingCollection information

    // Function to get all node ids for all Staking records in a users StakingCollection, if one exists.
    pub fun getNodeIDs(address: Address): [String] {
        let account = getAccount(address)

        let stakingCollectionRef = account.borrow<&Collection{StakingCollectionPublic}>(from: StakingCollectionPublicPath)
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getNodeIDs()
    }
        
    // Function to get all delegator ids for all Delegation records in a users StakingCollection, if one exists.
    pub fun getDelegatorIDs(address: Address): [DelegatorIDs] {
        let account = getAccount(address)

        let stakingCollectionRef = account.borrow<&Collection{StakingCollectionPublic}>(from: StakingCollectionPublicPath)
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getDelegatorIDs()
    }

    // Function to get all Node Info records for all Staking records in a users StakingCollection, if one exists.
    pub fun getAllNodeInfo(address: Address): {String: FlowIDTableStaking.NodeInfo} {
        let account = getAccount(address)

        let stakingCollectionRef = account.borrow<&Collection{StakingCollectionPublic}>(from: StakingCollectionPublicPath)
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getAllNodeInfo()
    }

    // Function to get all Delegator Info records for all Delegation records in a users StakingCollection, if one exists.
    pub fun getAllDelegatorInfo(address: Address): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {
        let account = getAccount(address)

        let stakingCollectionRef = account.borrow<&Collection{StakingCollectionPublic}>(from: StakingCollectionPublicPath)
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getAllDelegatorInfo()
    }

    init() {
        self.StakingCollectionStoragePath = /storage/stakingCollection
        self.StakingCollectionPublicPath = /public/stakingCollection
    }
}
