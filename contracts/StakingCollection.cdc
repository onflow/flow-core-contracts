/*

    This contract defines a collection for staking and delegating objects
    which allows users to stake and delegate for as many nodes as they want in a single account.

 */

// import FungibleToken from 0xee82856bf20e2aa6
// import FlowToken from 0x0ae53cb6e3f42a79

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS
import StakingProxy from 0xSTAKINGPROXYADDRESS
import LockedTokens from 0xLOCKEDTOKENSADDRESS

pub contract FlowStakingCollection {

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

        pub fun getAllNodeInfo(): {String: FlowIDTableStaking.NodeInfo}

        pub fun getAllDelegatorInfo(): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}}
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

        access(self) var tokenHolder: Capability<&LockedTokens.TokenHolder>?

        // Tracks how many locked tokens each node or delegator uses
        // When committing new locked tokens, add those tokens to the value
        // when withdrawing locked tokens, subtract from the value
        //
        // access(self) var lockedTokensForNode: {String: UFix64}
        // access(self) var tokensForDelegator: {String: {UInt32: UFix64}}

        access(self) var lockedTokensUsed: UFix64
        access(self) var unlockedTokensUsed: UFix64

        init(vaultCapability: Capability<&FlowToken.Vault>, tokenHolder: Capability<&LockedTokens.TokenHolder>?) {
            pre {
                vaultCapability.check(): "Invalid FlowToken.Vault capability"
            }
            self.vaultCapability = vaultCapability

            self.lockedVaultHolder <- nil
            self.tokenHolder = tokenHolder

            self.nodeStakers <- {}
            self.nodeDelegators <- {}

            self.lockedTokensUsed = UFix64(0)
            self.unlockedTokensUsed = UFix64(0)

            // If the account has a locked account, initialize its token holder
            // and locked vault holder from the LockedTokens contract
            if let tokenHolderObj = self.tokenHolder {
                let lockedVaultHolder <- LockedTokens.createLockedVaultHolder()

                let lockedTokenManager = tokenHolderObj.borrow()!.borrowTokenManager()

                lockedVaultHolder.addVault(lockedVault: lockedTokenManager.vault)
                
                self.lockedVaultHolder <-! lockedVaultHolder
            } else {
                self.lockedVaultHolder <-! nil
            }
        }

        destroy() {
            destroy self.lockedVaultHolder
            destroy self.nodeStakers
            destroy self.nodeDelegators
        }

        // Gets tokens to commit to a node. Uses locked tokens first, if possible
        access(self) fun getTokens(amount: UFix64): @FungibleToken.Vault {
            if let _lockedValutHolder <- self.lockedVaultHolder <- nil {

                var lockedBalance: UFix64 = _lockedValutHolder.getVaultBalance()
                var unlockedBalance: UFix64 = self.vaultCapability.borrow()!.balance

                assert(
                    lockedBalance + unlockedBalance < amount,
                    message: "Insufficient total Flow balance"
                )

                if (amount <= lockedBalance) {
                    self.lockedTokensUsed = self.lockedTokensUsed + amount

                    let tokens <- _lockedValutHolder.withdrawFromLockedVault(amount: amount)

                    self.lockedVaultHolder <-! _lockedValutHolder

                    return <-tokens
                } else {
                    self.lockedTokensUsed = self.lockedTokensUsed + lockedBalance
                    self.unlockedTokensUsed = self.unlockedTokensUsed + (amount - lockedBalance)

                    let tokens <- FlowToken.createEmptyVault()

                    let lockedPortion <- _lockedValutHolder.withdrawFromLockedVault(amount: lockedBalance)
                    let unlockedPortion <- self.vaultCapability.borrow()!.withdraw(amount: amount - lockedBalance)

                    tokens.deposit(from: <-lockedPortion)
                    tokens.deposit(from: <-unlockedPortion)

                    self.lockedVaultHolder <-! _lockedValutHolder

                    return <-tokens
                }
            } else {
                var unlockedBalance: UFix64 = self.vaultCapability.borrow()!.balance

                assert(
                    unlockedBalance < amount,
                    message: "Insufficient total Flow balance"
                )

                self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                return <-self.vaultCapability.borrow()!.withdraw(amount: amount)
            }
        }

        // Deposits tokens after being withdrawn from a Stake or Delegation. Deposits to unlocked tokens first, if possible.
        access(self) fun depositTokens(from: @FungibleToken.Vault) {
            if let _lockedValutHolder <- self.lockedVaultHolder <- nil {

                if self.unlockedTokensUsed > UFix64(0.0) {
                    
                    if (from.balance < self.unlockedTokensUsed) {
                        self.unlockedTokensUsed = self.unlockedTokensUsed - from.balance

                        _lockedValutHolder.depositToLockedVault(from: <-from.withdraw(amount: from.balance))
                    } else {
                        _lockedValutHolder.depositToLockedVault(from: <-from.withdraw(amount: self.unlockedTokensUsed))

                        self.unlockedTokensUsed = self.unlockedTokensUsed - self.unlockedTokensUsed
                    }
                }

                self.lockedTokensUsed = self.lockedTokensUsed - from.balance

                _lockedValutHolder.depositToLockedVault(from: <-from)

                self.lockedVaultHolder <-! _lockedValutHolder

            }
        }

        // Returns true if a Stake or Delegation record exists in the StakingCollection for a given nodeID and optional delegatorID, otherwise false.
        access(self) fun doesStakeExist(nodeID: String, delegatorID: UInt32?): Bool {
            var tokenHolderNodeID: String? = nil
            var tokenHolderDelegatorNodeID: String? = nil
            var tokenHolderDelegatorID: UInt32?  = nil

            if let _tokenHolder = self.tokenHolder!.borrow() {
                tokenHolderNodeID = _tokenHolder!.getNodeID()
                tokenHolderDelegatorNodeID = _tokenHolder!.getDelegatorNodeID()
                tokenHolderDelegatorID = _tokenHolder!.getDelegatorID()
            }

            if let _delegatorID = delegatorID {
                if (tokenHolderDelegatorNodeID != nil && tokenHolderDelegatorID != nil && tokenHolderDelegatorNodeID! == nodeID && tokenHolderDelegatorID! == _delegatorID) {
                    return true
                }

                if self.nodeDelegators[nodeID] != nil {
                    if let delegators <- self.nodeDelegators[nodeID] <- nil {
                        if delegators[_delegatorID] != nil {
                            self.nodeDelegators[nodeID] <-! delegators
                            return true
                        } else {
                            self.nodeDelegators[nodeID] <-! delegators
                            return false
                        }
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (tokenHolderNodeID != nil && tokenHolderNodeID! == nodeID) {
                    return true
                }

                return self.nodeStakers[nodeID] != nil
            }
        }

        // Function to add an existing NodeStaker object
        pub fun addNodeObject(_ node: @FlowIDTableStaking.NodeStaker) {
            self.nodeStakers[node.id] <-! node
        }

        // Function to add an existing NodeDelegator object
        pub fun addDelegatorObject(_ delegator: @FlowIDTableStaking.NodeDelegator) {
            let id = delegator.id
            let nodeID = delegator.nodeID

            if self.nodeStakers[delegator.nodeID] == nil {
                let delegators: @{UInt32: FlowIDTableStaking.NodeDelegator} <- {}
                delegators[id] <-! delegator
                self.nodeDelegators[nodeID] <-! delegators
            } else {
                if let delegators <- self.nodeDelegators[delegator.nodeID] <- nil {
                    delegators[id] <-! delegator
                    self.nodeDelegators[nodeID] <-! delegators
                }
            }
        }

        // Operations to register new staking objects

        // Function to register a new Staking Record to the Staking Collection
        pub fun registerNode(nodeInfo: StakingProxy.NodeInfo, amount: UFix64) {

            let tokens <- self.getTokens(amount: amount)

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(id: nodeInfo.id, role: nodeInfo.role, networkingAddress: nodeInfo.networkingAddress, networkingKey: nodeInfo.networkingKey, stakingKey: nodeInfo.stakingKey, tokensCommitted: <-tokens)

            self.nodeStakers[nodeInfo.id] <-! nodeStaker

            // Maybe should emit event here?
        }

        // Function to register a new Delegator Record to the Staking Collection
        pub fun registerDelegator(nodeID: String, amount: UFix64) {
            
            let tokens <- self.getTokens(amount: amount)

            let nodeDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID)

            nodeDelegator.delegateNewTokens(from: <- tokens)

            self.addDelegatorObject(<-nodeDelegator)

            // Maybe should emit event here?
        }

        access(self) fun borrowNode(_ nodeID: String): &FlowIDTableStaking.NodeStaker? {
            return &self.nodeStakers[nodeID] as? &FlowIDTableStaking.NodeStaker
        }

        access(self) fun getDelegator(_ nodeID: String, _ delegatorID: UInt32): @FlowIDTableStaking.NodeDelegator? {
            if let delegators <- self.nodeDelegators[nodeID] <- nil {
                if let delegator <- delegators[delegatorID] <- nil {
                    self.nodeDelegators[nodeID] <-! delegators
                    return <-delegator
                } else {
                    self.nodeDelegators[nodeID] <-! delegators
                    return nil
                }
            } else {
                return nil
            }
        }

        // Staking Operations

        // Function to stake new tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun stakeNewTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {                

                if let delegator <- self.getDelegator(nodeID, _delegatorID) {

                    delegator.delegateNewTokens(from: <- self.getTokens(amount: amount))

                    self.addDelegatorObject(<-delegator)

                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.delegateNewTokens(amount: amount)
                }
                
            } else {

                if let node = self.borrowNode(nodeID) {
                    node.stakeNewTokens(<-self.getTokens(amount: amount))
                } else {
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    
                    staker.stakeNewTokens(amount: amount)
                }
            }
        }

        // Function to stake unstaked tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun stakeUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator <- self.getDelegator(nodeID, _delegatorID) {

                    delegator.delegateUnstakedTokens(amount: amount)

                    self.addDelegatorObject(<-delegator)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.delegateUnstakedTokens(amount: amount)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    node.stakeUnstakedTokens(amount: amount)
                } else {
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    
                    staker.stakeUnstakedTokens(amount: amount)
                }
            }
        }

        // Function to stake rewarded tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun stakeRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator <- self.getDelegator(nodeID, _delegatorID) {

                    delegator.delegateRewardedTokens(amount: amount)

                    self.addDelegatorObject(<-delegator)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.delegateRewardedTokens(amount: amount)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    node.stakeRewardedTokens(amount: amount)
                } else {
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    
                    staker.stakeRewardedTokens(amount: amount)
                }
            }
        }

        // Function to request tokens to be unstaked for an existing Stake or Delegation record in the StakingCollection
        pub fun requestUnstaking(nodeID: String, delegatorID: UInt32?, amount: UFix64) { 
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator <- self.getDelegator(nodeID, _delegatorID) {

                    delegator.requestUnstaking(amount: amount)

                    self.addDelegatorObject(<-delegator)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.requestUnstaking(amount: amount)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    node.requestUnstaking(amount: amount)
                } else {
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    
                    staker.requestUnstaking(amount: amount)
                }
            }
        }

        // Function to unstake all tokens for an existing Staking record in the StakingCollection
        pub fun unstakeAll(nodeID: String) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil) == false : "Specified stake does not exist"
            }
    
            if let node = self.borrowNode(nodeID) {
                node.unstakeAll()
            } else {
                let staker = self.tokenHolder!.borrow()!.borrowStaker()
                
                staker.unstakeAll()
            }
        }

        // Function to withdraw unstaked tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun withdrawUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) { 
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator <- self.getDelegator(nodeID, _delegatorID) {

                    let tokens <- delegator.withdrawUnstakedTokens(amount: amount)
                    self.depositTokens(from: <-tokens)

                    self.addDelegatorObject(<-delegator)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.withdrawUnstakedTokens(amount: amount)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    let tokens <- node.withdrawUnstakedTokens(amount: amount)
                    self.depositTokens(from: <-tokens)
                } else {
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    
                    staker.withdrawUnstakedTokens(amount: amount)
                }
            }
        }

        // Function to withdraw rewarded tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun withdrawRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID) == false : "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator <- self.getDelegator(nodeID, _delegatorID) {

                    let tokens <- delegator.withdrawRewardedTokens(amount: amount)
                    self.depositTokens(from: <-tokens)

                    self.addDelegatorObject(<-delegator)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.withdrawRewardedTokens(amount: amount)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    let tokens <- node.withdrawRewardedTokens(amount: amount)
                    self.depositTokens(from: <-tokens)
                } else {
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    
                    staker.withdrawRewardedTokens(amount: amount)
                }
            }
        }

        // Getters

        // Function to get all node ids for all Staking records in the StakingCollection
        pub fun getNodeIDs(): [String] {
            let nodeIDs: [String] = self.nodeStakers.keys

            if let tokenHolderCapability = self.tokenHolder {
                let _tokenHolder = tokenHolderCapability.borrow()!

                let tokenHolderNodeID = _tokenHolder!.getNodeID()
                if let _tokenHolderNodeID = tokenHolderNodeID {
                    nodeIDs.append(_tokenHolderNodeID)
                }
            }

            return nodeIDs
        }

        // Function to get all delegator ids for all Delegation records in the StakingCollection
        pub fun getDelegatorIDs(): [DelegatorIDs] {
            let nodeIDs: [String] = self.nodeDelegators.keys
            let delegatorIDs: [DelegatorIDs] = []

            for nodeID in nodeIDs {
                let delIDs: [UInt32] = self.nodeDelegators[nodeID]?.keys!

                for delegatorID in delIDs {
                    delegatorIDs.append(DelegatorIDs(nodeID: nodeID, delegatorID: delegatorID))
                }
            }

            if let tokenHolderCapability = self.tokenHolder {
                let _tokenHolder = tokenHolderCapability.borrow()!

                let tokenHolderDelegatorNodeID = _tokenHolder.getDelegatorNodeID()
                let tokenHolderDelegatorID = _tokenHolder.getDelegatorID()

                if let _tokenHolderDelegatorNodeID = tokenHolderDelegatorNodeID {
                    if let _tokenHolderDelegatorID = tokenHolderDelegatorID {
                        delegatorIDs.append(DelegatorIDs(nodeID: _tokenHolderDelegatorNodeID, delegatorID: _tokenHolderDelegatorID))
                    }
                }
            }

            return delegatorIDs
        }

        // Function to get all Node Info records for all Staking records in the StakingCollection
        pub fun getAllNodeInfo(): {String: FlowIDTableStaking.NodeInfo} {
            let nodeInfo: {String: FlowIDTableStaking.NodeInfo} = {}

            let nodeIDs: [String] = self.nodeStakers.keys
            for nodeID in nodeIDs {
                nodeInfo[nodeID] = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
            }

            if let tokenHolderCapability = self.tokenHolder {
                let _tokenHolder = tokenHolderCapability.borrow()!

                let tokenHolderNodeID = _tokenHolder.getNodeID()
                if let _tokenHolderNodeID = tokenHolderNodeID {
                    nodeInfo[_tokenHolderNodeID] = FlowIDTableStaking.NodeInfo(nodeID: _tokenHolderNodeID)
                }
            }

            return nodeInfo
        }

        // Function to get all Delegator Info records for all Delegation records in the StakingCollection
        pub fun getAllDelegatorInfo(): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {
            let delegatorInfo: {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} = {}

            let nodeIDs: [String] = self.nodeDelegators.keys

            for nodeID in nodeIDs {
                if let delegators <- self.nodeDelegators[nodeID] <- nil {
                    let delegatorIDs: [UInt32] = delegators.keys

                    for delegatorID in delegatorIDs {
                        let info = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
                        if let delegatorInfos = delegatorInfo[nodeID] {
                            delegatorInfos[delegatorID] = info
                            delegatorInfo[nodeID] = delegatorInfos
                        } else {
                            let delegatorInfos: {UInt32: FlowIDTableStaking.DelegatorInfo} = {}
                            delegatorInfos[delegatorID] = info
                            delegatorInfo[nodeID] = delegatorInfos
                        }
                    }
                    self.nodeDelegators[nodeID] <-! delegators
                }
            }

            if let tokenHolderCapability = self.tokenHolder {
                let _tokenHolder = tokenHolderCapability.borrow()!

                let tokenHolderDelegatorNodeID = _tokenHolder.getDelegatorNodeID()
                let tokenHolderDelegatorID = _tokenHolder.getDelegatorID()

                if let _tokenHolderDelegatorNodeID = tokenHolderDelegatorNodeID {
                    if let _tokenHolderDelegatorID = tokenHolderDelegatorID {
                        let info = FlowIDTableStaking.DelegatorInfo(nodeID: _tokenHolderDelegatorNodeID, delegatorID: _tokenHolderDelegatorID)
                        if let delegatorInfos = delegatorInfo[_tokenHolderDelegatorNodeID] {
                            delegatorInfos[_tokenHolderDelegatorID] = info
                            delegatorInfo[_tokenHolderDelegatorNodeID] = delegatorInfos
                        } else {
                            let delegatorInfos: {UInt32: FlowIDTableStaking.DelegatorInfo} = {}
                            delegatorInfos[_tokenHolderDelegatorID] = info
                            delegatorInfo[_tokenHolderDelegatorNodeID] = delegatorInfos
                        }
                    }
                }
            }

            return delegatorInfo
        }

    } 

    // Getter functions for accounts StakingCollection information

    // Function to get all node ids for all Staking records in a users StakingCollection, if one exists.
    pub fun getNodeIDs(address: Address): [String] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&Collection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getNodeIDs()
    }
        
    // Function to get all delegator ids for all Delegation records in a users StakingCollection, if one exists.
    pub fun getDelegatorIDs(address: Address): [DelegatorIDs] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&Collection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getDelegatorIDs()
    }

    // Function to get all Node Info records for all Staking records in a users StakingCollection, if one exists.
    pub fun getAllNodeInfo(address: Address): {String: FlowIDTableStaking.NodeInfo} {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&Collection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getAllNodeInfo()
    }

    // Function to get all Delegator Info records for all Delegation records in a users StakingCollection, if one exists.
    pub fun getAllDelegatorInfo(address: Address): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&Collection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getAllDelegatorInfo()
    }

    init() {
        self.StakingCollectionStoragePath = /storage/stakingCollection
        self.StakingCollectionPublicPath = /public/stakingCollection
    }
}
 