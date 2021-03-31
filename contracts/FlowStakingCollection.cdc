/*

    This contract defines a collection for staking and delegating objects
    which allows users to stake and delegate for as many nodes as they want in a single account.

 */

// import FungibleToken from 0xee82856bf20e2aa6
// import FlowToken from 0x0ae53cb6e3f42a79

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS
import LockedTokens from 0xLOCKEDTOKENSADDRESS

pub contract FlowStakingCollection {

    pub let StakingCollectionStoragePath: StoragePath
    pub let StakingCollectionPrivatePath: PrivatePath
    pub let StakingCollectionPublicPath: PublicPath

    // Events
    pub event NewNodeCreated(nodeID: String, role: UInt8, amountCommitted: UFix64, address: Address)
    pub event NewDelegatorCreated(nodeID: String, delegatorID: UInt32, amountCommitted: UFix64, address: Address)

    // Struct that stores delegator ID info
    pub struct DelegatorIDs {
        pub let delegatorNodeID: String
        pub let delegatorID: UInt32

        init(nodeID: String, delegatorID: UInt32) {
            self.delegatorNodeID = nodeID
            self.delegatorID = delegatorID
        }
    }

    // Public interface that users can publish for their staking collection
    // so that others can query their staking info
    pub resource interface StakingCollectionPublic {
        pub var lockedTokensUsed: UFix64
        pub var unlockedTokensUsed: UFix64
        pub fun doesStakeExist(nodeID: String, delegatorID: UInt32?): Bool
        pub fun getNodeIDs(): [String]
        pub fun getDelegatorIDs(): [DelegatorIDs]
        pub fun getAllNodeInfo(): [FlowIDTableStaking.NodeInfo]
        pub fun getAllDelegatorInfo(): [FlowIDTableStaking.DelegatorInfo]
    }

    /// The resource that stakers store in their accounts to store
    /// all their staking objects and capability to the locked account object
    /// Keeps track of how many locked and unlocked tokens are staked
    /// so it knows which tokens to give to the user when they deposit and withdraw
    /// different types of tokens

    pub resource StakingCollection: StakingCollectionPublic {

        /// unlocked vault
        access(self) var vaultCapability: Capability<&FlowToken.Vault>

        /// locked vault
        access(self) var lockedVaultHolder: @LockedTokens.LockedVaultHolder?

        /// staking objects need to be private for now because they could be using locked tokens
        access(self) var nodeStakers: @{String: FlowIDTableStaking.NodeStaker}
        access(self) var nodeDelegators: @{String: FlowIDTableStaking.NodeDelegator}

        /// Capabilty to the TokenHolder object in the unlocked account
        /// Accounts without a locked account will not store this, it will be nil
        access(self) var tokenHolder: Capability<&LockedTokens.TokenHolder>?

        // Tracks how many locked and unlocked tokens the staker is using for all their nodes and/or delegators
        // When committing new tokens, locked tokens are used first, followed by unlocked tokens
        // When withdrawing tokens, unlocked tokens are withdrawn first, followed by locked tokens
        pub var lockedTokensUsed: UFix64
        pub var unlockedTokensUsed: UFix64

        init(vaultCapability: Capability<&FlowToken.Vault>, tokenHolder: Capability<&LockedTokens.TokenHolder>?) {
            pre {
                vaultCapability.check(): "Invalid FlowToken.Vault capability"
            }
            self.vaultCapability = vaultCapability

            self.nodeStakers <- {}
            self.nodeDelegators <- {}

            self.lockedTokensUsed = 0.0
            self.unlockedTokensUsed = 0.0

            // If the account has a locked account, initialize its token holder
            // and locked vault holder from the LockedTokens contract
            if let tokenHolderObj = tokenHolder {
                self.tokenHolder = tokenHolder
                let lockedVaultHolder <- LockedTokens.createLockedVaultHolder()

                // borrow the main token manager object from the locked account 
                // to get access to the locked vault
                let lockedTokenManager = tokenHolderObj.borrow()!.borrowTokenManager()

                // Add the locked vault to the holder
                lockedVaultHolder.addVault(lockedVault: lockedTokenManager.vault)
                
                self.lockedVaultHolder <- lockedVaultHolder
            } else {
                self.tokenHolder = tokenHolder
                self.lockedVaultHolder <- nil
            }
        }

        /// TODO: Panic if there are still tokens staked in any of the objects
        destroy() {
            destroy self.lockedVaultHolder
            destroy self.nodeStakers
            destroy self.nodeDelegators
        }

        /// Called when committing tokens for staking. Gets tokens from either or both vaults
        /// Uses locked tokens first, then unlocked if any more are still needed
        access(self) fun getTokens(amount: UFix64): @FungibleToken.Vault {

            // If there is a locked account, use the locked vault first
            if self.lockedVaultHolder != nil {

                var lockedBalance: UFix64 = self.lockedVaultHolder?.getVaultBalance()!
                var unlockedBalance: UFix64 = self.vaultCapability.borrow()!.balance

                assert(
                    amount <= lockedBalance + unlockedBalance,
                    message: "Insufficient total Flow balance"
                )

                // If all the tokens can be removed from locked, withdraw and return them
                if (amount <= lockedBalance) {
                    self.lockedTokensUsed = self.lockedTokensUsed + amount

                    let tokens <- self.lockedVaultHolder?.withdrawFromLockedVault(amount: amount)!

                    return <-tokens
                
                // If not all can be removed from locked, remove what can be, then remove the rest from unlocked
                } else {

                    // update locked tokens used record by adding the rest of the locked balance
                    self.lockedTokensUsed = self.lockedTokensUsed + lockedBalance
                    // Update the unlocked tokens used record by adding the amount requested
                    // minus whatever was used from the locked tokens
                    self.unlockedTokensUsed = self.unlockedTokensUsed + (amount - lockedBalance)

                    let tokens <- FlowToken.createEmptyVault()

                    // Get the actual tokens from each vault
                    let lockedPortion <- self.lockedVaultHolder?.withdrawFromLockedVault(amount: lockedBalance)!
                    let unlockedPortion <- self.vaultCapability.borrow()!.withdraw(amount: amount - lockedBalance)

                    // Deposit them into the same vault
                    tokens.deposit(from: <-lockedPortion)
                    tokens.deposit(from: <-unlockedPortion)

                    return <-tokens
                }
            } else {
                // Since there is no locked account, all tokens have to come from the normal unlocked balance
                var unlockedBalance: UFix64 = self.vaultCapability.borrow()!.balance

                assert(
                    amount <= unlockedBalance,
                    message: "Insufficient total Flow balance"
                )

                self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                return <-self.vaultCapability.borrow()!.withdraw(amount: amount)
            }
        }

        /// Deposits tokens back to a vault after being withdrawn from a Stake or Delegation.
        /// Deposits to unlocked tokens first, if possible, followed by locked tokens
        access(self) fun depositTokens(from: @FungibleToken.Vault) {
            /// If there is a locked account, get the locked vault holder for depositing
            if self.lockedVaultHolder != nil {
  
                if (from.balance <= self.unlockedTokensUsed) {
                    self.unlockedTokensUsed = self.unlockedTokensUsed - from.balance

                    self.vaultCapability.borrow()!.deposit(from: <-from)
                } else {
                    // Return unlocked tokens first
                    self.vaultCapability.borrow()!.deposit(from: <-from.withdraw(amount: self.unlockedTokensUsed))

                    self.lockedTokensUsed = self.lockedTokensUsed - from.balance
                    // followed by returning the locked tokens
                    self.lockedVaultHolder?.depositToLockedVault(from: <-from)

                    self.unlockedTokensUsed = self.unlockedTokensUsed - self.unlockedTokensUsed
                }

            } else {

                self.unlockedTokensUsed = self.unlockedTokensUsed - from.balance
                
                // If there is no locked account, get the users vault capability and deposit tokens to it.
                self.vaultCapability.borrow()!.deposit(from: <-from)
            }
        }

        // Returns true if a Stake or Delegation record exists in the StakingCollection for a given nodeID and optional delegatorID, otherwise false.
        pub fun doesStakeExist(nodeID: String, delegatorID: UInt32?): Bool {
            var tokenHolderNodeID: String? = nil
            var tokenHolderDelegatorNodeID: String? = nil
            var tokenHolderDelegatorID: UInt32?  = nil

            // If there is a locked account, get the staking info from that account
            if self.tokenHolder != nil {
                if let _tokenHolder = self.tokenHolder!.borrow() {
                    tokenHolderNodeID = _tokenHolder!.getNodeID()
                    tokenHolderDelegatorNodeID = _tokenHolder!.getDelegatorNodeID()
                    tokenHolderDelegatorID = _tokenHolder!.getDelegatorID()
                }
            }

            // If the request is for a delegator, check all possible delegators for possible matches
            if let _delegatorID = delegatorID {
                if (tokenHolderDelegatorNodeID != nil && tokenHolderDelegatorID != nil && tokenHolderDelegatorNodeID! == nodeID && tokenHolderDelegatorID! == _delegatorID) {
                    return true
                }

                // Look for a delegator with the specified node ID and delegator ID
                return self.borrowDelegator(nodeID, _delegatorID) != nil 
            } else {
                if (tokenHolderNodeID != nil && tokenHolderNodeID! == nodeID) {
                    return true
                }

                return self.nodeStakers[nodeID] != nil
            }
        }

        // Function to add an existing NodeStaker object
        pub fun addNodeObject(_ node: @FlowIDTableStaking.NodeStaker) {
            let stakingInfo = FlowIDTableStaking.NodeInfo(nodeID: node.id)
            let totalStaked = stakingInfo.tokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked
            self.unlockedTokensUsed = self.unlockedTokensUsed + totalStaked
            self.nodeStakers[node.id] <-! node
        }

        // Function to add an existing NodeDelegator object
        pub fun addDelegatorObject(_ delegator: @FlowIDTableStaking.NodeDelegator) {
            let stakingInfo = FlowIDTableStaking.DelegatorInfo(nodeID: delegator.nodeID, delegatorID: delegator.id)
            let totalStaked = stakingInfo.tokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked
            self.unlockedTokensUsed = self.unlockedTokensUsed + totalStaked
            self.nodeDelegators[delegator.nodeID] <-! delegator
        }

        // Operations to register new staking objects

        // Function to register a new Staking Record to the Staking Collection
        pub fun registerNode(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, amount: UFix64) {

            let tokens <- self.getTokens(amount: amount)

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, tokensCommitted: <-tokens)

            //emit NewNodeCreated(nodeID: nodeStaker.id, role: nodeStaker.id, amountCommitted: amount)

            self.nodeStakers[id] <-! nodeStaker
        }

        // Function to register a new Delegator Record to the Staking Collection
        pub fun registerDelegator(nodeID: String, amount: UFix64) {
            
            let tokens <- self.getTokens(amount: amount)

            let nodeDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID)

            nodeDelegator.delegateNewTokens(from: <- tokens)

            //emit NewDelegatorCreated(nodeID: nodeDelegator.nodeID, delegatorID: nodeDelegator.id, amountCommitted: amount)

            self.nodeDelegators[nodeDelegator.nodeID] <-! nodeDelegator
        }

        access(self) fun borrowNode(_ nodeID: String): &FlowIDTableStaking.NodeStaker? {
            if self.nodeStakers[nodeID] != nil {
                return &self.nodeStakers[nodeID] as? &FlowIDTableStaking.NodeStaker
            } else {
                return nil
            }
        }

        access(self) fun borrowDelegator(_ nodeID: String, _ delegatorID: UInt32): &FlowIDTableStaking.NodeDelegator? {
            if self.nodeDelegators[nodeID] != nil {
                let delegatorRef = &self.nodeDelegators[nodeID] as? &FlowIDTableStaking.NodeDelegator
                if delegatorRef.id == delegatorID { return delegatorRef } else { return nil }
            } else {
                return nil
            }
        }

        // Staking Operations

        // Function to stake new tokens for an existing Stake or Delegation record in the StakingCollection
        pub fun stakeNewTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {                
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    delegator.delegateNewTokens(from: <- self.getTokens(amount: amount))
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
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {

                    delegator.delegateUnstakedTokens(amount: amount)

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
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                    delegator.delegateRewardedTokens(amount: amount)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.delegateRewardedTokens(amount: amount)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    self.unlockedTokensUsed = self.unlockedTokensUsed + amount
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
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {

                    delegator.requestUnstaking(amount: amount)

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
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil): "Specified stake does not exist"
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
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    let tokens <- delegator.withdrawUnstakedTokens(amount: amount)

                    self.depositTokens(from: <-tokens)
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
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                    let tokens <- delegator.withdrawRewardedTokens(amount: amount)

                    self.depositTokens(from: <-tokens)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.withdrawRewardedTokens(amount: amount)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    self.unlockedTokensUsed = self.unlockedTokensUsed + amount

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
                let delID = self.nodeDelegators[nodeID]?.id

                delegatorIDs.append(DelegatorIDs(nodeID: nodeID, delegatorID: delID!))
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
        pub fun getAllNodeInfo(): [FlowIDTableStaking.NodeInfo] {
            let nodeInfo: [FlowIDTableStaking.NodeInfo] = []

            let nodeIDs: [String] = self.nodeStakers.keys
            for nodeID in nodeIDs {
                nodeInfo.append(FlowIDTableStaking.NodeInfo(nodeID: nodeID))
            }

            if let tokenHolderCapability = self.tokenHolder {
                let _tokenHolder = tokenHolderCapability.borrow()!

                let tokenHolderNodeID = _tokenHolder.getNodeID()
                if let _tokenHolderNodeID = tokenHolderNodeID {
                    nodeInfo.append(FlowIDTableStaking.NodeInfo(nodeID: _tokenHolderNodeID))
                }
            }

            return nodeInfo
        }

        // Function to get all Delegator Info records for all Delegation records in the StakingCollection
        pub fun getAllDelegatorInfo(): [FlowIDTableStaking.DelegatorInfo] {
            let delegatorInfo: [FlowIDTableStaking.DelegatorInfo] = []

            let nodeIDs: [String] = self.nodeDelegators.keys

            for nodeID in nodeIDs {

                let delegatorID = self.nodeDelegators[nodeID]?.id

                let info = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID!)

                delegatorInfo.append(info)
            }

            if let tokenHolderCapability = self.tokenHolder {
                let _tokenHolder = tokenHolderCapability.borrow()!

                let tokenHolderDelegatorNodeID = _tokenHolder.getDelegatorNodeID()
                let tokenHolderDelegatorID = _tokenHolder.getDelegatorID()

                if let _tokenHolderDelegatorNodeID = tokenHolderDelegatorNodeID {
                    if let _tokenHolderDelegatorID = tokenHolderDelegatorID {
                        let info = FlowIDTableStaking.DelegatorInfo(nodeID: _tokenHolderDelegatorNodeID, delegatorID: _tokenHolderDelegatorID)

                        delegatorInfo.append(info)
                    }
                }
            }

            return delegatorInfo
        }

    } 

    // Getter functions for accounts StakingCollection information

    // Function to get see if a node or delegator exists in an accounts staking collection
    pub fun doesStakeExist(address: Address, nodeID: String, delegatorID: UInt32?): Bool {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID)
    }

    // Function to get the unlocked tokens used amount for an account
    pub fun getUnlockedTokensUsed(address: Address): UFix64 {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.unlockedTokensUsed
    }

    // Function to get the locked tokens used amount for an account
    pub fun getLockedTokensUsed(address: Address): UFix64 {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.lockedTokensUsed
    }

    // Function to get all node ids for all Staking records in a users StakingCollection, if one exists.
    pub fun getNodeIDs(address: Address): [String] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getNodeIDs()
    }
        
    // Function to get all delegator ids for all Delegation records in a users StakingCollection, if one exists.
    pub fun getDelegatorIDs(address: Address): [DelegatorIDs] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getDelegatorIDs()
    }

    // Function to get all Node Info records for all Staking records in a users StakingCollection, if one exists.
    pub fun getAllNodeInfo(address: Address): [FlowIDTableStaking.NodeInfo] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getAllNodeInfo()
    }

    // Function to get all Delegator Info records for all Delegation records in a users StakingCollection, if one exists.
    pub fun getAllDelegatorInfo(address: Address): [FlowIDTableStaking.DelegatorInfo] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getAllDelegatorInfo()
    }

    pub fun createStakingCollection(vaultCapability: Capability<&FlowToken.Vault>, tokenHolder: Capability<&LockedTokens.TokenHolder>?): @StakingCollection {
        return <- create StakingCollection(vaultCapability: vaultCapability, tokenHolder: tokenHolder)
    }

    init() {
        self.StakingCollectionStoragePath = /storage/stakingCollection
        self.StakingCollectionPrivatePath = /private/stakingCollection
        self.StakingCollectionPublicPath = /public/stakingCollection
    }
}
 