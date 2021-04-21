/*

    FlowStakingCollection

    This contract defines a collection for staking and delegating objects
    which allows users to stake for as many nodes and/or delegators as they want in a single account.
    It is compatible with the locked token account setup.

 */

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS
import LockedTokens from 0xLOCKEDTOKENSADDRESS
import FlowStorageFees from 0xFLOWSTORAGEFEESADDRESS

pub contract FlowStakingCollection {

    /// Account paths
    pub let StakingCollectionStoragePath: StoragePath
    pub let StakingCollectionPrivatePath: PrivatePath
    pub let StakingCollectionPublicPath: PublicPath

    /// Events
    pub event NewNodeCreated(nodeID: String, role: UInt8, amountCommitted: UFix64, address: Address)
    pub event NewDelegatorCreated(nodeID: String, delegatorID: UInt32, amountCommitted: UFix64, address: Address)

    /// Struct that stores delegator ID info
    pub struct DelegatorIDs {
        pub let delegatorNodeID: String
        pub let delegatorID: UInt32

        init(nodeID: String, delegatorID: UInt32) {
            self.delegatorNodeID = nodeID
            self.delegatorID = delegatorID
        }
    }

    /// Public interface that users can publish for their staking collection
    /// so that others can query their staking info
    pub resource interface StakingCollectionPublic {
        pub var lockedTokensUsed: UFix64
        pub var unlockedTokensUsed: UFix64
        pub fun addNodeObject(_ node: @FlowIDTableStaking.NodeStaker)
        pub fun addDelegatorObject(_ delegator: @FlowIDTableStaking.NodeDelegator)
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
        access(self) var unlockedVault: Capability<&FlowToken.Vault>

        /// locked vault
        /// will be nil if the account has no corresponding locked account
        access(self) var lockedVault: Capability<&FlowToken.Vault>?

        /// Stores staking objects for nodes and delegators
        /// Can only use one delegator per node ID
        /// need to be private for now because they could be using locked tokens
        access(self) var nodeStakers: @{String: FlowIDTableStaking.NodeStaker}
        access(self) var nodeDelegators: @{String: FlowIDTableStaking.NodeDelegator}

        /// Capabilty to the TokenHolder object in the unlocked account
        /// Accounts without a locked account will not store this, it will be nil
        access(self) var tokenHolder: Capability<&LockedTokens.TokenHolder>?

        /// Tracks how many locked and unlocked tokens the staker is using for all their nodes and/or delegators
        /// When committing new tokens, locked tokens are used first, followed by unlocked tokens
        /// When withdrawing tokens, unlocked tokens are withdrawn first, followed by locked tokens
        pub var lockedTokensUsed: UFix64
        pub var unlockedTokensUsed: UFix64

        init(unlockedVault: Capability<&FlowToken.Vault>, tokenHolder: Capability<&LockedTokens.TokenHolder>?) {
            pre {
                unlockedVault.check(): "Invalid FlowToken.Vault capability"
            }
            self.unlockedVault = unlockedVault

            self.nodeStakers <- {}
            self.nodeDelegators <- {}

            self.lockedTokensUsed = 0.0
            self.unlockedTokensUsed = 0.0

            // If the account has a locked account, initialize its token holder
            // and locked vault capability
            if let tokenHolderObj = tokenHolder {
                self.tokenHolder = tokenHolder

                // borrow the main token manager object from the locked account 
                // to get access to the locked vault capability
                let lockedTokenManager = tokenHolderObj.borrow()!.borrowTokenManager()
                self.lockedVault = lockedTokenManager.vault
            } else {
                self.tokenHolder = nil
                self.lockedVault = nil
            }
        }

        /// Close all the stakes before destroying everything
        /// This uses the closeStake method, so it will panic if there are still tokens staked in any of the objects
        destroy() {
            let nodeIDs = self.getNodeIDs()
            let delegatorIDs = self.getDelegatorIDs()

            for nodeID in nodeIDs {
                self.closeStake(nodeID: nodeID, delegatorID: nil)
            }

            for delegatorID in delegatorIDs {
                self.closeStake(nodeID: delegatorID.delegatorNodeID, delegatorID: delegatorID.delegatorID)
            }

            destroy self.nodeStakers
            destroy self.nodeDelegators
        }

        /// Called when committing tokens for staking. Gets tokens from either or both vaults
        /// Uses locked tokens first, then unlocked if any more are still needed
        access(self) fun getTokens(amount: UFix64): @FungibleToken.Vault {

            // If there is a locked account, use the locked vault first
            if self.lockedVault != nil {

                var lockedBalance: UFix64 = self.lockedVault!.borrow()!.balance - FlowStorageFees.minimumStorageReservation
                var unlockedBalance: UFix64 = self.unlockedVault.borrow()!.balance - FlowStorageFees.minimumStorageReservation

                assert(
                    amount <= lockedBalance + unlockedBalance,
                    message: "Insufficient total available Flow balance"
                )

                // If all the tokens can be removed from locked, withdraw and return them
                if (amount <= lockedBalance) {
                    self.lockedTokensUsed = self.lockedTokensUsed + amount

                    return <-self.lockedVault!.borrow()!.withdraw(amount: amount)
                
                // If not all can be removed from locked, remove what can be, then remove the rest from unlocked
                } else {

                    // update locked tokens used record by adding the rest of the locked balance
                    self.lockedTokensUsed = self.lockedTokensUsed + lockedBalance

                    // Update the unlocked tokens used record by adding the amount requested
                    // minus whatever was used from the locked tokens
                    self.unlockedTokensUsed = self.unlockedTokensUsed + (amount - lockedBalance)

                    let tokens <- FlowToken.createEmptyVault()

                    // Get the actual tokens from each vault
                    let lockedPortion <- self.lockedVault!.borrow()!.withdraw(amount: lockedBalance)
                    let unlockedPortion <- self.unlockedVault.borrow()!.withdraw(amount: amount - lockedBalance)

                    // Deposit them into the same vault
                    tokens.deposit(from: <-lockedPortion)
                    tokens.deposit(from: <-unlockedPortion)

                    return <-tokens
                }
            } else {
                // Since there is no locked account, all tokens have to come from the normal unlocked balance
                var unlockedBalance: UFix64 = self.unlockedVault.borrow()!.balance - FlowStorageFees.minimumStorageReservation

                assert(
                    amount <= unlockedBalance,
                    message: "Insufficient total Flow balance"
                )

                self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                return <-self.unlockedVault.borrow()!.withdraw(amount: amount)
            }
        }

        /// Deposits tokens back to a vault after being withdrawn from a Node or Delegator.
        /// Deposits to unlocked tokens first, if possible, followed by locked tokens
        access(self) fun depositTokens(from: @FungibleToken.Vault) {
            pre {
                // This error should never be triggered in production becasue the tokens used fields
                // should be properly managed by all the other functions
                from.balance <= self.unlockedTokensUsed + self.lockedTokensUsed: "Cannot deposit more than is already used"
            }

            /// If there is a locked account, get the locked vault holder for depositing
            if self.lockedVault != nil {
  
                if (from.balance <= self.unlockedTokensUsed) {
                    self.unlockedTokensUsed = self.unlockedTokensUsed - from.balance

                    self.unlockedVault.borrow()!.deposit(from: <-from)
                } else {
                    // Return unlocked tokens first
                    self.unlockedVault.borrow()!.deposit(from: <-from.withdraw(amount: self.unlockedTokensUsed))
                    self.unlockedTokensUsed = 0.0

                    self.lockedTokensUsed = self.lockedTokensUsed - from.balance
                    // followed by returning the difference as locked tokens
                    self.lockedVault!.borrow()!.deposit(from: <-from)
                }
            } else {
                self.unlockedTokensUsed = self.unlockedTokensUsed - from.balance
                
                // If there is no locked account, get the users vault capability and deposit tokens to it.
                self.unlockedVault.borrow()!.deposit(from: <-from)
            }
        }

        /// Returns true if a Node or Delegator record exists in the StakingCollection for a given nodeID and optional delegatorID, otherwise false.
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

                return self.borrowNode(nodeID) != nil
            }
        }

        /// Function to add an existing NodeStaker object
        pub fun addNodeObject(_ node: @FlowIDTableStaking.NodeStaker) {
            let stakingInfo = FlowIDTableStaking.NodeInfo(nodeID: node.id)
            let totalStaked = stakingInfo.tokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked
            self.unlockedTokensUsed = self.unlockedTokensUsed + totalStaked
            self.nodeStakers[node.id] <-! node
        }

        /// Function to add an existing NodeDelegator object
        pub fun addDelegatorObject(_ delegator: @FlowIDTableStaking.NodeDelegator) {
            let stakingInfo = FlowIDTableStaking.DelegatorInfo(nodeID: delegator.nodeID, delegatorID: delegator.id)
            let totalStaked = stakingInfo.tokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked
            self.unlockedTokensUsed = self.unlockedTokensUsed + totalStaked
            self.nodeDelegators[delegator.nodeID] <-! delegator
        }

        /// Function to remove an existing NodeStaker object.
        /// If the user has used any locked tokens, removing NodeStaker objects is not allowed.
        pub fun removeNode(nodeID: String): @FlowIDTableStaking.NodeStaker? {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil): "Specified node does not exist"
                self.lockedTokensUsed == UFix64(0.0): "Cannot remove node if locked tokens are used"
            }
            
            if self.nodeStakers[nodeID] != nil {
                let stakingInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
                let totalStaked = stakingInfo.tokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked

                // Since the NodeStaker object is being removed, the total number of unlocked tokens staked to it is deducted from the counter.
                self.unlockedTokensUsed = self.unlockedTokensUsed - totalStaked

                // Removes the NodeStaker object from the Staking Collections internal nodeStakers map.
                let nodeStaker <- self.nodeStakers[nodeID] <- nil
                
                return <- nodeStaker
            } else {
                // The function does not allow for removing a NodeStaker stored in the locked account, if one exists.
                panic("Cannot remove node stored in locked account.")
            }

            return nil
        }

        /// Function to remove an existing NodeDelegator object.
        /// If the user has used any locked tokens, removing NodeDelegator objects is not allowed.
        pub fun removeDelegator(nodeID: String, delegatorID: UInt32): @FlowIDTableStaking.NodeDelegator? {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified delegator does not exist"
                self.lockedTokensUsed == UFix64(0.0): "Cannot remove delegator if locked tokens are used"
            }
            
            if self.nodeDelegators[nodeID] != nil {
                let delegatorRef = &self.nodeDelegators[nodeID] as? &FlowIDTableStaking.NodeDelegator
                if delegatorRef.id == delegatorID { 
                    let stakingInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
                    let totalStaked = stakingInfo.tokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked

                    // Since the NodeDelegator object is being removed, the total number of unlocked tokens delegated to it is deducted from the counter.
                    self.unlockedTokensUsed = self.unlockedTokensUsed - totalStaked

                    // Removes the NodeDelegator object from the Staking Collections internal nodeDelegators map.
                    let nodeDelegator <- self.nodeDelegators[nodeID] <- nil

                    return <- nodeDelegator
                } else { 
                    panic("Expected delegatorID does not correspond to the delegator in the Staking Collection.")
                }
            } else {
                // The function does not allow for removing a NodeDelegator stored in the locked account, if one exists.
                panic("Cannot remove delegator stored in locked account.")
            }

            return nil
        }

        /// Operations to register new staking objects

        /// Function to register a new Staking Record to the Staking Collection
        pub fun registerNode(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, amount: UFix64) {

            let tokens <- self.getTokens(amount: amount)

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, tokensCommitted: <-tokens)

            //emit NewNodeCreated(nodeID: nodeStaker.id, role: nodeStaker.id, amountCommitted: amount)

            self.nodeStakers[id] <-! nodeStaker
        }

        /// Function to register a new Delegator Record to the Staking Collection
        pub fun registerDelegator(nodeID: String, amount: UFix64) {
            let delegatorIDs = self.getDelegatorIDs()
            for idInfo in delegatorIDs {
                if idInfo.delegatorNodeID == nodeID { panic("Cannot register a delegator for a node that is already being delegated to") }
            }
            
            let tokens <- self.getTokens(amount: amount)

            let nodeDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID)

            nodeDelegator.delegateNewTokens(from: <- tokens)

            //emit NewDelegatorCreated(nodeID: nodeDelegator.nodeID, delegatorID: nodeDelegator.id, amountCommitted: amount)

            self.nodeDelegators[nodeDelegator.nodeID] <-! nodeDelegator
        }

        /// Borrows a reference to a node in the collection
        access(self) fun borrowNode(_ nodeID: String): &FlowIDTableStaking.NodeStaker? {
            if self.nodeStakers[nodeID] != nil {
                return &self.nodeStakers[nodeID] as? &FlowIDTableStaking.NodeStaker
            } else {
                return nil
            }
        }

        /// Borrows a reference to a delegator in the collection
        access(self) fun borrowDelegator(_ nodeID: String, _ delegatorID: UInt32): &FlowIDTableStaking.NodeDelegator? {
            if self.nodeDelegators[nodeID] != nil {
                let delegatorRef = &self.nodeDelegators[nodeID] as? &FlowIDTableStaking.NodeDelegator
                if delegatorRef.id == delegatorID { return delegatorRef } else { return nil }
            } else {
                return nil
            }
        }

        // Staking Operations

        // The owner calls the same function whether or not they are staking for a node or delegating.
        // If they are staking for a node, they provide their node ID and `nil` as the delegator ID
        // If they are staking for a delegator, they provide the node ID for the node they are delegating to
        // and their delegator ID to specify that it is for their delegator object

        /// Function to stake new tokens for an existing Node or Delegator record in the StakingCollection
        pub fun stakeNewTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            // If staking as a delegator, use the delegate functionality
            if let _delegatorID = delegatorID {       
                // If the delegator is stored in the collection, borrow it         
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    delegator.delegateNewTokens(from: <- self.getTokens(amount: amount))
                } else {
                    // Get any needed unlocked tokens, and deposit them to the locked vault.
                    let lockedBalance = self.lockedVault!.borrow()!.balance - FlowStorageFees.minimumStorageReservation
                    if (amount > lockedBalance) {
                        self.tokenHolder!.borrow()!.deposit(from: <- self.unlockedVault.borrow()!.withdraw(amount: amount - lockedBalance))
                    }   

                    // Use the delegator stored in the locked account
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    delegator.delegateNewTokens(amount: amount)
                }
                
            } else {
                // If the node is stored in the collection, borrow it    
                if let node = self.borrowNode(nodeID) {
                    node.stakeNewTokens(<-self.getTokens(amount: amount))
                } else {
                    // Get any needed unlocked tokens, and deposit them to the locked vault.
                    let lockedBalance = self.lockedVault!.borrow()!.balance - FlowStorageFees.minimumStorageReservation
                    if (amount > lockedBalance) {
                        self.tokenHolder!.borrow()!.deposit(from: <- self.unlockedVault.borrow()!.withdraw(amount: amount - lockedBalance))
                    } 

                    // Use the Node stored in the locked account
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    staker.stakeNewTokens(amount: amount)
                }
            }
        }

        /// Function to stake unstaked tokens for an existing Node or Delegator record in the StakingCollection
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

        /// Function to stake rewarded tokens for an existing Node or Delegator record in the StakingCollection
        pub fun stakeRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    // We add the amount to the unlocked tokens used because rewards are newly minted tokens
                    // and aren't immediately reflected in the tokens used fields
                    self.unlockedTokensUsed = self.unlockedTokensUsed + amount
                    delegator.delegateRewardedTokens(amount: amount)
                } else {
                    // Staking tokens in the locked account staking objects are not reflected in the tokens used fields,
                    // so they are not updated here
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

        /// Function to request tokens to be unstaked for an existing Node or Delegator record in the StakingCollection
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

        /// Function to unstake all tokens for an existing node or delegator in the StakingCollection
        pub fun unstakeAll(nodeID: String, delegatorID: UInt32?) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                let delegatorInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: _delegatorID)
                let tokensStaked = delegatorInfo.tokensCommitted + delegatorInfo.tokensStaked - delegatorInfo.tokensRequestedToUnstake

                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    delegator.requestUnstaking(amount: tokensStaked)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    delegator.requestUnstaking(amount: tokensStaked)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    node.unstakeAll()
                } else {
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    staker.unstakeAll()
                }
            }
        }

        /// Function to withdraw unstaked tokens for an existing Node or Delegator record in the StakingCollection
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

        /// Function to withdraw rewarded tokens for an existing Node or Delegator record in the StakingCollection
        pub fun withdrawRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    // We update the unlocked tokens used field before withdrawing because 
                    // rewards are newly minted and not immediately reflected in the tokens used fields
                    self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                    let tokens <- delegator.withdrawRewardedTokens(amount: amount)

                    self.depositTokens(from: <-tokens)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    
                    delegator.withdrawRewardedTokens(amount: amount)

                    // move the unlocked rewards from the locked account to the unlocked account
                    let unlockedRewards <- self.tokenHolder!.borrow()!.withdraw(amount: amount)
                    self.unlockedVault.borrow()!.deposit(from: <-unlockedRewards)
                }
            } else {
                if let node = self.borrowNode(nodeID) {
                    self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                    let tokens <- node.withdrawRewardedTokens(amount: amount)

                    self.depositTokens(from: <-tokens)
                } else {
                    let staker = self.tokenHolder!.borrow()!.borrowStaker()
                    
                    staker.withdrawRewardedTokens(amount: amount)

                    // move the unlocked rewards from the locked account to the unlocked account
                    let unlockedRewards <- self.tokenHolder!.borrow()!.withdraw(amount: amount)
                    self.unlockedVault.borrow()!.deposit(from: <-unlockedRewards)
                }
            }
        }

        // Closers

        /// Closes an existing Node or delegator, moving all withdrawable tokens back to the users account and removing the node
        /// or delegator object from the StakingCollection.
        pub fun closeStake(nodeID: String, delegatorID: UInt32?) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): "Specified stake does not exist"
            }

            if let _delegatorID = delegatorID {
                let delegatorInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: _delegatorID)

                assert(
                    delegatorInfo.tokensStaked + delegatorInfo.tokensCommitted + delegatorInfo.tokensUnstaking == 0.0,
                    message: "Cannot close a delegation until all tokens have been withdrawn, or moved to a withdrawable state."
                )

                if (delegatorInfo.tokensUnstaked > 0.0) {
                    self.withdrawUnstakedTokens(nodeID: nodeID, delegatorID: _delegatorID, amount: delegatorInfo.tokensUnstaked)
                }

                if (delegatorInfo.tokensRewarded > 0.0) {
                    self.withdrawRewardedTokens(nodeID: nodeID, delegatorID: _delegatorID, amount: delegatorInfo.tokensRewarded)
                }

                if let delegator = self.borrowDelegator(nodeID, _delegatorID) {
                    let delegator <- self.nodeDelegators[nodeID] <- nil
                    destroy delegator
                } else {
                    if let tokenHolderCapability = self.tokenHolder {
                        let tokenManager = tokenHolderCapability.borrow()!.borrowTokenManager()
                        let delegator <- tokenManager.removeDelegator()
                        destroy delegator
                    } else {
                        panic("Token Holder capability needed and not found.")
                    }
                }
            } else {
                let stakeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)

                assert(
                    stakeInfo.tokensStaked + stakeInfo.tokensCommitted + stakeInfo.tokensUnstaking == 0.0,
                    message: "Cannot close a stake until all tokens have been withdrawn, or moved to a withdrawable state."
                )

                if (stakeInfo.tokensUnstaked > 0.0) {
                    self.withdrawUnstakedTokens(nodeID: nodeID, delegatorID: delegatorID, amount: stakeInfo.tokensUnstaked)
                }

                if (stakeInfo.tokensRewarded > 0.0) {
                    self.withdrawRewardedTokens(nodeID: nodeID, delegatorID: delegatorID, amount: stakeInfo.tokensRewarded)
                }

                if let node = self.borrowNode(nodeID) {
                    let staker <- self.nodeStakers[nodeID] <- nil
                    destroy staker
                } else {
                    if let tokenHolderCapability = self.tokenHolder {
                        let tokenManager = tokenHolderCapability.borrow()!.borrowTokenManager()
                        let staker <- tokenManager.removeNode()
                        destroy staker
                    } else {
                        panic("Token Holder capability needed and not found.")
                    }
                }
            }
        }

        // Getters

        /// Function to get all node ids for all Staking records in the StakingCollection
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

        /// Function to get all delegator ids for all Delegation records in the StakingCollection
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

        /// Function to get all Node Info records for all Staking records in the StakingCollection
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

        /// Function to get all Delegator Info records for all Delegation records in the StakingCollection
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

    /// Function to get see if a node or delegator exists in an accounts staking collection
    pub fun doesStakeExist(address: Address, nodeID: String, delegatorID: UInt32?): Bool {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID)
    }

    /// Function to get the unlocked tokens used amount for an account
    pub fun getUnlockedTokensUsed(address: Address): UFix64 {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.unlockedTokensUsed
    }

    /// Function to get the locked tokens used amount for an account
    pub fun getLockedTokensUsed(address: Address): UFix64 {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.lockedTokensUsed
    }

    /// Function to get all node ids for all Staking records in a users StakingCollection, if one exists.
    pub fun getNodeIDs(address: Address): [String] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getNodeIDs()
    }
        
    /// Function to get all delegator ids for all Delegation records in a users StakingCollection, if one exists.
    pub fun getDelegatorIDs(address: Address): [DelegatorIDs] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getDelegatorIDs()
    }

    /// Function to get all Node Info records for all Staking records in a users StakingCollection, if one exists.
    pub fun getAllNodeInfo(address: Address): [FlowIDTableStaking.NodeInfo] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getAllNodeInfo()
    }

    /// Function to get all Delegator Info records for all Delegation records in a users StakingCollection, if one exists.
    pub fun getAllDelegatorInfo(address: Address): [FlowIDTableStaking.DelegatorInfo] {
        let account = getAccount(address)

        let stakingCollectionRef = account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")

        return stakingCollectionRef.getAllDelegatorInfo()
    }

    /// Determines if an account is set up with a Staking Collection
    pub fun doesAccountHaveStakingCollection(address: Address): Bool {
        let account = getAccount(address)

        return account.getCapability<&StakingCollection{StakingCollectionPublic}>(self.StakingCollectionPublicPath).check()
    }

    /// Creates a brand new empty staking collection resource and returns it to the caller
    pub fun createStakingCollection(unlockedVault: Capability<&FlowToken.Vault>, tokenHolder: Capability<&LockedTokens.TokenHolder>?): @StakingCollection {
        return <- create StakingCollection(unlockedVault: unlockedVault, tokenHolder: tokenHolder)
    }

    init() {
        self.StakingCollectionStoragePath = /storage/stakingCollection
        self.StakingCollectionPrivatePath = /private/stakingCollection
        self.StakingCollectionPublicPath = /public/stakingCollection
    }
}
 