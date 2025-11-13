/*

    FlowStakingCollection

    This contract defines a collection for staking and delegating objects
    which allows users to stake and delegate for as many nodes as they want in a single account.
    It is compatible with the locked token account setup.

    See the onflow/flow-core-contracts README for more high level information about the staking collection.

 */

import "FungibleToken"
import "FlowToken"
import "FlowIDTableStaking"
import "LockedTokens"
import "FlowStorageFees"
import "FlowClusterQC"
import "FlowDKG"
import "FlowEpoch"
import "Burner"

access(all) contract FlowStakingCollection {

    /// Account paths
    access(all) let StakingCollectionStoragePath: StoragePath
    access(all) let StakingCollectionPrivatePath: PrivatePath
    access(all) let StakingCollectionPublicPath: PublicPath

    /// Events
    access(all) event NodeAddedToStakingCollection(nodeID: String, role: UInt8, amountCommitted: UFix64, address: Address?)
    access(all) event DelegatorAddedToStakingCollection(nodeID: String, delegatorID: UInt32, amountCommitted: UFix64, address: Address?)

    access(all) event NodeRemovedFromStakingCollection(nodeID: String, role: UInt8, address: Address?)
    access(all) event DelegatorRemovedFromStakingCollection(nodeID: String, delegatorID: UInt32, address: Address?)

    access(all) event MachineAccountCreated(nodeID: String, role: UInt8, address: Address)

    /// Struct that stores delegator ID info
    access(all) struct DelegatorIDs {
        access(all) let delegatorNodeID: String
        access(all) let delegatorID: UInt32

        view init(nodeID: String, delegatorID: UInt32) {
            self.delegatorNodeID = nodeID
            self.delegatorID = delegatorID
        }
    }

    /// Contains information about a node's machine Account
    /// which is a secondary account that is only meant to hold
    /// the QC or DKG object and FLOW to automatically pay for transaction fees
    /// related to QC or DKG operations.
    access(all) struct MachineAccountInfo {
        access(all) let nodeID: String
        access(all) let role: UInt8
        // Capability to the FLOW Vault to allow the owner
        // to withdraw or deposit to their machine account if needed
        access(contract) let machineAccountVaultProvider: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>

        init(nodeID: String, role: UInt8, machineAccountVaultProvider: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>) {
            pre {
                machineAccountVaultProvider.check():
                    "FlowStakingCollection.MachineAccountInfo.init: Invalid Flow Token Vault Provider."
            }
            self.nodeID = nodeID
            self.role = role
            self.machineAccountVaultProvider = machineAccountVaultProvider
        }

        // Gets the address of the machine account
        access(all) view fun getAddress(): Address {
            return self.machineAccountVaultProvider.borrow()!.owner!.address
        }
    }

    /// Public interface that users can publish for their staking collection
    /// so that others can query their staking info
    access(all) resource interface StakingCollectionPublic {
        access(all) var lockedTokensUsed: UFix64
        access(all) var unlockedTokensUsed: UFix64
        access(all) fun addNodeObject(_ node: @FlowIDTableStaking.NodeStaker, machineAccountInfo: MachineAccountInfo?)
        access(all) fun addDelegatorObject(_ delegator: @FlowIDTableStaking.NodeDelegator)
        access(all) view fun doesStakeExist(nodeID: String, delegatorID: UInt32?): Bool
        access(all) fun getNodeIDs(): [String]
        access(all) fun getDelegatorIDs(): [DelegatorIDs]
        access(all) fun getAllNodeInfo(): [FlowIDTableStaking.NodeInfo]
        access(all) fun getAllDelegatorInfo(): [FlowIDTableStaking.DelegatorInfo]
        access(all) fun getMachineAccounts(): {String: MachineAccountInfo}
    }

    access(all) entitlement CollectionOwner

    /// The resource that stakers store in their accounts to store
    /// all their staking objects and capability to the locked account object
    /// Keeps track of how many locked and unlocked tokens are staked
    /// so it knows which tokens to give to the user when they deposit and withdraw
    /// different types of tokens
    /// 
    /// WARNING: If you destroy a staking collection with the `destroy` command,
    /// you will lose access to all your nodes and delegators that the staking collection
    /// manages. If you want to destroy it, you must either transfer your node to a different account
    /// unstake all your tokens and withdraw
    /// your unstaked tokens and rewards first before destroying.
    /// Then use the `destroyStakingCollection` method to destroy it
    access(all) resource StakingCollection: StakingCollectionPublic, Burner.Burnable {

        /// unlocked vault
        access(self) var unlockedVault: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>

        /// locked vault
        /// will be nil if the account has no corresponding locked account
        access(self) var lockedVault: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>?

        /// Stores staking objects for nodes and delegators
        /// Can only use one delegator per node ID
        /// need to be private for now because they could be using locked tokens
        access(self) var nodeStakers: @{String: FlowIDTableStaking.NodeStaker}
        access(self) var nodeDelegators: @{String: FlowIDTableStaking.NodeDelegator}

        /// Capabilty to the TokenHolder object in the unlocked account
        /// Accounts without a locked account will not store this, it will be nil
        access(self) var tokenHolder: Capability<auth(FungibleToken.Withdraw, LockedTokens.TokenOperations) &LockedTokens.TokenHolder>?

        /// Tracks how many locked and unlocked tokens the staker is using for all their nodes and/or delegators
        /// When committing new tokens, locked tokens are used first, followed by unlocked tokens
        /// When withdrawing tokens, unlocked tokens are withdrawn first, followed by locked tokens
        access(all) var lockedTokensUsed: UFix64
        access(all) var unlockedTokensUsed: UFix64

        /// Tracks the machine accounts associated with nodes
        access(self) var machineAccounts: {String: MachineAccountInfo}

        init(
            unlockedVault: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>,
            tokenHolder: Capability<auth(FungibleToken.Withdraw, LockedTokens.TokenOperations) &LockedTokens.TokenHolder>?
        ) {
            pre {
                unlockedVault.check():
                    "FlowStakingCollection.StakingCollection.init: Cannot Initialize a Staking Collection! "
                    .concat("The provided FlowToken Vault capability with withdraw entitlements is invalid.")
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

            self.machineAccounts = {}
        }

        /// Gets a standard error message to show when the requested staker
        /// is not controlled by the staking collection
        ///
        /// @param nodeID: The ID of the requested node
        /// @param delegatorID: The ID of the requested delegator
        ///
        /// @return String: The full error message to print
        access(all) view fun getStakerDoesntExistInCollectionError(funcName: String, nodeID: String, delegatorID: UInt32?): String {
            // Construct the function name for the beginning of the error
            let errorBeginning = "FlowStakingCollection.StakingCollection.".concat(funcName).concat(": ")
            
            // The error message is different if it is a delegator vs a node
            if let delegator = delegatorID {
                return errorBeginning.concat("The specified delegator with node ID ")
                    .concat(nodeID).concat(" and delegatorID ").concat(delegator.toString())
                    .concat(" does not exist in the owner's collection. ")
                    .concat("Make sure that the IDs you entered correspond to a delegator that is controlled by this staking collection.")
            } else {
                return errorBeginning.concat("The specified node with ID ")
                    .concat(nodeID).concat(" does not exist in the owner's collection. ")
                    .concat("Make sure that the ID you entered corresponds to a node that is controlled by this staking collection.")
            }
        }

        /// Called when the collection is destroyed via `Burner.burn()`
        access(contract) fun burnCallback() {

            let nodeIDs = self.getNodeIDs()
            let delegatorIDs = self.getDelegatorIDs()

            for nodeID in nodeIDs {
                self.closeStake(nodeID: nodeID, delegatorID: nil)
            }

            for delegatorID in delegatorIDs {
                self.closeStake(nodeID: delegatorID.delegatorNodeID, delegatorID: delegatorID.delegatorID)
            }
        }

        /// Called when committing tokens for staking. Gets tokens from either or both vaults
        /// Uses locked tokens first, then unlocked if any more are still needed
        access(self) fun getTokens(amount: UFix64): @{FungibleToken.Vault} {

            let unlockedVault = self.unlockedVault.borrow()!
            let unlockedBalance = unlockedVault.balance - FlowStorageFees.minimumStorageReservation

            // If there is a locked account, use the locked vault first
            if self.lockedVault != nil {

                let lockedVault = self.lockedVault!.borrow()!
                let lockedBalance = lockedVault.balance - FlowStorageFees.minimumStorageReservation

                assert(
                    amount <= lockedBalance + unlockedBalance,
                    message: "FlowStakingCollection.StakingCollection.getTokens: Cannot get tokens to stake! "
                            .concat("The amount of FLOW requested to use, ")
                            .concat(amount.toString()).concat(", is more than the sum of ")
                            .concat("locked and unlocked FLOW, ").concat((lockedBalance+unlockedBalance).toString())
                            .concat(", in the owner's accounts.")
                )

                // If all the tokens can be removed from locked, withdraw and return them
                if (amount <= lockedBalance) {
                    self.lockedTokensUsed = self.lockedTokensUsed + amount

                    return <-lockedVault.withdraw(amount: amount)
                
                // If not all can be removed from locked, remove what can be, then remove the rest from unlocked
                } else {

                    // update locked tokens used record by adding the rest of the locked balance
                    self.lockedTokensUsed = self.lockedTokensUsed + lockedBalance

                    let numUnlockedTokensToUse = amount - lockedBalance

                    // Update the unlocked tokens used record by adding the amount requested
                    // minus whatever was used from the locked tokens
                    self.unlockedTokensUsed = self.unlockedTokensUsed + numUnlockedTokensToUse

                    let tokens <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())

                    // Get the actual tokens from each vault
                    let lockedPortion <- lockedVault.withdraw(amount: lockedBalance)
                    let unlockedPortion <- unlockedVault.withdraw(amount: numUnlockedTokensToUse)

                    // Deposit them into the same vault
                    tokens.deposit(from: <-lockedPortion)
                    tokens.deposit(from: <-unlockedPortion)

                    return <-tokens
                }
            } else {
                // Since there is no locked account, all tokens have to come from the normal unlocked balance

                assert(
                    amount <= unlockedBalance,
                    message: "FlowStakingCollection.StakingCollection.getTokens: Cannot get tokens to stake! "
                            .concat("The amount of FLOW requested to use, ")
                            .concat(amount.toString()).concat(", is more than the amount of FLOW, ")
                            .concat((unlockedBalance).toString())
                            .concat(", in the owner's account.")
                )

                self.unlockedTokensUsed = self.unlockedTokensUsed + amount

                return <-unlockedVault.withdraw(amount: amount)
            }
        }

        /// Deposits tokens back to a vault after being withdrawn from a Stake or Delegation.
        /// Deposits to unlocked tokens first, if possible, followed by locked tokens
        access(self) fun depositTokens(from: @{FungibleToken.Vault}) {
            pre {
                // This error should never be triggered in production becasue the tokens used fields
                // should be properly managed by all the other functions
                from.balance <= self.unlockedTokensUsed + self.lockedTokensUsed:
                    "FlowStakingCollection.StakingCollection.depositTokens: "
                    .concat(" Cannot return more FLOW to the account than is already in use for staking.")
            }

            let unlockedVault = self.unlockedVault.borrow()!

            /// If there is a locked account, get the locked vault holder for depositing
            if self.lockedVault != nil {
  
                if (from.balance <= self.unlockedTokensUsed) {
                    self.unlockedTokensUsed = self.unlockedTokensUsed - from.balance

                    unlockedVault.deposit(from: <-from)
                } else {
                    // Return unlocked tokens first
                    unlockedVault.deposit(from: <-from.withdraw(amount: self.unlockedTokensUsed))
                    self.unlockedTokensUsed = 0.0

                    self.lockedTokensUsed = self.lockedTokensUsed - from.balance
                    // followed by returning the difference as locked tokens
                    self.lockedVault!.borrow()!.deposit(from: <-from)
                }
            } else {
                self.unlockedTokensUsed = self.unlockedTokensUsed - from.balance
                
                // If there is no locked account, get the users vault capability and deposit tokens to it.
                unlockedVault.deposit(from: <-from)
            }
        }

        /// Returns true if a Stake or Delegation record exists in the StakingCollection for a given nodeID and optional delegatorID, otherwise false.
        access(all) view fun doesStakeExist(nodeID: String, delegatorID: UInt32?): Bool {
            var tokenHolderNodeID: String? = nil
            var tokenHolderDelegatorNodeID: String? = nil
            var tokenHolderDelegatorID: UInt32?  = nil

            // If there is a locked account, get the staking info from that account
            if self.tokenHolder != nil {
                if let _tokenHolder = self.tokenHolder!.borrow() {
                    tokenHolderNodeID = _tokenHolder.getNodeID()
                    tokenHolderDelegatorNodeID = _tokenHolder.getDelegatorNodeID()
                    tokenHolderDelegatorID = _tokenHolder.getDelegatorID()
                }
            }

            // If the request is for a delegator, check all possible delegators for possible matches
            if let delegatorID = delegatorID {
                if (tokenHolderDelegatorNodeID != nil
                    && tokenHolderDelegatorID != nil
                    && tokenHolderDelegatorNodeID! == nodeID
                    && tokenHolderDelegatorID! == delegatorID)
                {
                    return true
                }

                // Look for a delegator with the specified node ID and delegator ID
                return self.borrowDelegator(nodeID: nodeID, delegatorID: delegatorID) != nil 
            } else {
                if (tokenHolderNodeID != nil && tokenHolderNodeID! == nodeID) {
                    return true
                }

                return self.borrowNode(nodeID) != nil
            }
        }

        /// Function to add an existing NodeStaker object
        access(all) fun addNodeObject(_ node: @FlowIDTableStaking.NodeStaker, machineAccountInfo: MachineAccountInfo?) {
            let id = node.id
            let stakingInfo = FlowIDTableStaking.NodeInfo(nodeID: id)
            let totalStaked = stakingInfo.totalTokensInRecord() - stakingInfo.tokensRewarded
            self.unlockedTokensUsed = self.unlockedTokensUsed + totalStaked

            emit NodeAddedToStakingCollection(
                nodeID: stakingInfo.id,
                role: stakingInfo.role,
                amountCommitted: stakingInfo.totalCommittedWithoutDelegators(),
                address: self.owner?.address
            )

            self.nodeStakers[id] <-! node
            // Set the machine account for the existing node
            // can be the same as the old account if needed
            self.machineAccounts[id] = machineAccountInfo
        }

        /// Function to add an existing NodeDelegator object
        access(all) fun addDelegatorObject(_ delegator: @FlowIDTableStaking.NodeDelegator) {
            let stakingInfo = FlowIDTableStaking.DelegatorInfo(nodeID: delegator.nodeID, delegatorID: delegator.id)
            let totalStaked = stakingInfo.totalTokensInRecord() - stakingInfo.tokensRewarded
            self.unlockedTokensUsed = self.unlockedTokensUsed + totalStaked
            emit DelegatorAddedToStakingCollection(
                nodeID: stakingInfo.nodeID,
                delegatorID: stakingInfo.id,
                amountCommitted: stakingInfo.tokensStaked + stakingInfo.tokensCommitted - stakingInfo.tokensRequestedToUnstake,
                address: self.owner?.address
            )
            self.nodeDelegators[delegator.nodeID] <-! delegator
        }

        /// Function to remove an existing NodeStaker object.
        /// If the user has used any locked tokens, removing NodeStaker objects is not allowed.
        /// We do not clear the machine account field for this node here
        /// because the operator may want to keep it the same
        access(CollectionOwner) fun removeNode(nodeID: String): @FlowIDTableStaking.NodeStaker? {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil):
                    self.getStakerDoesntExistInCollectionError(funcName: "removeNode", nodeID: nodeID, delegatorID: nil)
                self.lockedTokensUsed == UFix64(0.0):
                    "FlowStakingCollection.StakingCollection.removeNode: Cannot remove a node from the collection "
                    .concat("because the collection still manages ").concat(self.lockedTokensUsed.toString())
                    .concat(" locked tokens. This is to prevent locked tokens ")
                    .concat("from being unlocked and withdrawn before their allotted unlocking time.")
            }
            
            if self.nodeStakers[nodeID] != nil {
                let stakingInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
                let totalStaked = stakingInfo.totalTokensInRecord() - stakingInfo.tokensRewarded

                // Since the NodeStaker object is being removed, the total number of unlocked tokens staked to it is deducted from the counter.
                self.unlockedTokensUsed = self.unlockedTokensUsed - totalStaked

                // Removes the NodeStaker object from the Staking Collections internal nodeStakers map.
                let nodeStaker <- self.nodeStakers[nodeID] <- nil

                // Clear the machine account info from the record
                self.machineAccounts[nodeID] = nil

                emit NodeRemovedFromStakingCollection(nodeID: nodeID, role: stakingInfo.role, address: self.owner?.address)
                
                return <- nodeStaker
            } else {
                // The function does not allow for removing a NodeStaker stored in the locked account, if one exists.
                panic("Cannot remove node stored in locked account.")
            }
        }

        /// Function to remove an existing NodeDelegator object.
        /// If the user has used any locked tokens, removing NodeDelegator objects is not allowed.
        access(CollectionOwner) fun removeDelegator(nodeID: String, delegatorID: UInt32): @FlowIDTableStaking.NodeDelegator? {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID):
                    self.getStakerDoesntExistInCollectionError(funcName: "removeDelegator", nodeID: nodeID, delegatorID: delegatorID)
                self.lockedTokensUsed == UFix64(0.0):
                    "FlowStakingCollection.StakingCollection.removeDelegator: Cannot remove a delegator from the collection "
                    .concat("because the collection still manages ").concat(self.lockedTokensUsed.toString())
                    .concat(" locked tokens. This is to prevent locked tokens ")
                    .concat("from being unlocked and withdrawn before their allotted unlocking time.")
            }
            
            if self.nodeDelegators[nodeID] != nil {
                let delegatorRef = (&self.nodeDelegators[nodeID] as &FlowIDTableStaking.NodeDelegator?)!
                if delegatorRef.id == delegatorID { 
                    let stakingInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
                    let totalStaked = stakingInfo.totalTokensInRecord() - stakingInfo.tokensRewarded

                    // Since the NodeDelegator object is being removed, the total number of unlocked tokens delegated to it is deducted from the counter.
                    self.unlockedTokensUsed = self.unlockedTokensUsed - totalStaked

                    // Removes the NodeDelegator object from the Staking Collections internal nodeDelegators map.
                    let nodeDelegator <- self.nodeDelegators[nodeID] <- nil

                    emit DelegatorRemovedFromStakingCollection(
                        nodeID: nodeID,
                        delegatorID: delegatorID,
                        address: self.owner?.address
                    )

                    return <- nodeDelegator
                } else { 
                    panic("FlowStakingCollection.StakingCollection.removeDelegator: "
                            .concat("Expected delegatorID ").concat(delegatorID.toString())
                            .concat(" does not correspond to the Staking Collection's delegator ID ")
                            .concat(delegatorRef.id.toString()))
                }
            } else {
                // The function does not allow for removing a NodeDelegator stored in the locked account, if one exists.
                panic("FlowStakingCollection.StakingCollection.removeDelegator: "
                    .concat("Cannot remove a delegator with ID ").concat(delegatorID.toString())
                    .concat(" because it is stored in the locked account."))
            }
        }

        /// Operations to register new staking objects

        /// Function to register a new Staking Record to the Staking Collection
        access(CollectionOwner) fun registerNode(
            id: String,
            role: UInt8,
            networkingAddress: String,
            networkingKey: String,
            stakingKey: String,
            stakingKeyPoP: String,
            amount: UFix64,
            payer: auth(BorrowValue) &Account
        ): auth(Storage, Capabilities, Contracts, Keys, Inbox) &Account? {

            let tokens <- self.getTokens(amount: amount)

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(
                id: id,
                role: role,
                networkingAddress: networkingAddress,
                networkingKey: networkingKey,
                stakingKey: stakingKey,
                stakingKeyPoP: stakingKeyPoP,
                tokensCommitted: <-tokens
            )

            emit NodeAddedToStakingCollection(
                nodeID: nodeStaker.id,
                role: role,
                amountCommitted: amount,
                address: self.owner?.address
            )

            self.nodeStakers[id] <-! nodeStaker

            let nodeReference = self.borrowNode(id)
                ?? panic("FlowStakingCollection.StakingCollection.registerNode: "
                        .concat("Could not borrow a reference to the newly created node with ID ")
                        .concat(id).concat("."))

            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeReference.id)

            // Register the machine account for the node
            // creates an auth account object and returns it to the caller
            if nodeInfo.role == FlowEpoch.NodeRole.Collector.rawValue || nodeInfo.role == FlowEpoch.NodeRole.Consensus.rawValue {
                return self.registerMachineAccount(nodeReference: nodeReference, payer: payer)
            } else {
                return nil
            }
        }

        /// Registers the secondary machine account for a node
        /// to store their epoch-related objects
        /// Only returns an AuthAccount object if the node is collector or consensus, otherwise returns nil
        /// The caller's qc or dkg object is stored in the new account
        /// but it is the caller's responsibility to add public keys to it
        access(self) fun registerMachineAccount(
            nodeReference: &FlowIDTableStaking.NodeStaker,
            payer: auth(BorrowValue) &Account
        ): auth(Storage, Capabilities, Contracts, Keys, Inbox) &Account? {

            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeReference.id)

            // Create the new account
            let machineAcct = Account(payer: payer)

            // Get the vault capability and create the machineAccountInfo struct
            let machineAccountVaultProvider = machineAcct.capabilities.storage
                .issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)!

            let machineAccountInfo = MachineAccountInfo(
                nodeID: nodeInfo.id,
                role: nodeInfo.role,
                machineAccountVaultProvider: machineAccountVaultProvider
            )
            
            // If they are a collector node, create a QC Voter object and store it in the account
            if nodeInfo.role == FlowEpoch.NodeRole.Collector.rawValue {

                // Get the voter object and store it
                let qcVoter <- FlowEpoch.getClusterQCVoter(nodeStaker: nodeReference)
                machineAcct.storage.save(<-qcVoter, to: FlowClusterQC.VoterStoragePath)

                // set this node's machine account
                self.machineAccounts[nodeInfo.id] = machineAccountInfo

                emit MachineAccountCreated(
                    nodeID: nodeInfo.id,
                    role: FlowEpoch.NodeRole.Collector.rawValue,
                    address: machineAccountVaultProvider.borrow()!.owner!.address
                )

                return machineAcct

            // If they are a consensus node, create a DKG Participant object and store it in the account
            } else if nodeInfo.role == FlowEpoch.NodeRole.Consensus.rawValue {

                // get the participant object and store it
                let dkgParticipant <- FlowEpoch.getDKGParticipant(nodeStaker: nodeReference)
                machineAcct.storage.save(<-dkgParticipant, to: FlowDKG.ParticipantStoragePath)

                // set this node's machine account
                self.machineAccounts[nodeInfo.id] = machineAccountInfo

                emit MachineAccountCreated(
                    nodeID: nodeInfo.id,
                    role: FlowEpoch.NodeRole.Consensus.rawValue,
                    address: machineAccountVaultProvider.borrow()!.owner!.address
                )

                return machineAcct
            }

            return nil
        }

        /// Allows the owner to set the machine account for one of their nodes
        /// This is used if the owner decides to transfer the machine account resource to another account
        /// without also transferring the old machine account record,
        /// or if they decide they want to use a different machine account for one of their nodes
        /// If they want to use a different machine account, it is their responsibility to
        /// transfer the qc or dkg object to the new account
        access(all) fun addMachineAccountRecord(
            nodeID: String,
            machineAccount: auth(BorrowValue, StorageCapabilities) &Account
        ) {

            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil):
                    self.getStakerDoesntExistInCollectionError(funcName: "addMachineAccountRecord", nodeID: nodeID, delegatorID: nil)
            }

            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)

            // Make sure that the QC or DKG object in the machine account is correct for this node ID

            if nodeInfo.role == FlowEpoch.NodeRole.Collector.rawValue {
                let qcVoterRef = machineAccount.storage.borrow<&FlowClusterQC.Voter>(from: FlowClusterQC.VoterStoragePath)
                    ?? panic("FlowStakingCollection.StakingCollection.addMachineAccountRecord: "
                            .concat("Could not access a QC Voter object from the provided machine account with address ").concat(machineAccount.address.toString()))

                assert(
                    nodeID == qcVoterRef.nodeID,
                    message: "FlowStakingCollection.StakingCollection.addMachineAccountRecord: "
                            .concat("The QC Voter Object in the machine account with node ID ").concat(qcVoterRef.nodeID)
                            .concat(" does not match the Staking Collection's specified node ID ").concat(nodeID)
                )
            } else if nodeInfo.role == FlowEpoch.NodeRole.Consensus.rawValue {
                let dkgParticipantRef = machineAccount.storage.borrow<&FlowDKG.Participant>(from: FlowDKG.ParticipantStoragePath)
                    ?? panic("FlowStakingCollection.StakingCollection.addMachineAccountRecord: "
                            .concat("Could not access a DKG Participant object from the provided machine account with address ").concat(machineAccount.address.toString()))

                assert(
                    nodeID == dkgParticipantRef.nodeID,
                    message: "FlowStakingCollection.StakingCollection.addMachineAccountRecord: "
                            .concat("The DKG Participant Object in the machine account with node ID ").concat(dkgParticipantRef.nodeID)
                            .concat(" does not match the Staking Collection's specified node ID ").concat(nodeID)
                )
            }

            // Make sure that the vault capability is created
            let machineAccountVaultProvider = machineAccount.capabilities.storage
                .issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)!

            // Create the new Machine account info object and store it
            let machineAccountInfo = MachineAccountInfo(
                nodeID: nodeID,
                role: nodeInfo.role,
                machineAccountVaultProvider: machineAccountVaultProvider
            )

            self.machineAccounts[nodeID] = machineAccountInfo
        }

        /// If a user has created a node before epochs were enabled, they'll need to use this function
        /// to create their machine account with their node 
        access(CollectionOwner) fun createMachineAccountForExistingNode(nodeID: String, payer: auth(BorrowValue) &Account): auth(Storage, Capabilities, Contracts, Keys, Inbox) &Account? {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil):
                    self.getStakerDoesntExistInCollectionError(funcName: "createMachineAccountForExistingNode", nodeID: nodeID, delegatorID: nil)
            }

            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)

            if let nodeReference = self.borrowNode(nodeID) {
                return self.registerMachineAccount(nodeReference: nodeReference, payer: payer)
            } else {
                if let tokenHolderObj = self.tokenHolder {

                    // borrow the main token manager object from the locked account 
                    // to get access to the locked vault capability
                    let lockedTokenManager = tokenHolderObj.borrow()!.borrowTokenManager()
                
                    let lockedNodeReference = lockedTokenManager.borrowNode()
                        ?? panic("FlowStakingCollection.StakingCollection.createMachineAccountForExistingNode: "
                                .concat("Could not borrow a node reference from the locked account."))

                    return self.registerMachineAccount(nodeReference: lockedNodeReference, payer: payer)
                }
            }

            return nil
        }

        /// Allows the owner to withdraw any available FLOW from their machine account
        access(CollectionOwner) fun withdrawFromMachineAccount(nodeID: String, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil):
                    self.getStakerDoesntExistInCollectionError(funcName: "withdrawFromMachineAccount", nodeID: nodeID, delegatorID: nil)
            }
            if let machineAccountInfo = self.machineAccounts[nodeID] {
                let vaultRef = machineAccountInfo.machineAccountVaultProvider.borrow()
                    ?? panic("FlowStakingCollection.StakingCollection.withdrawFromMachineAccount: "
                            .concat("Could not borrow reference to machine account vault."))

                let tokens <- vaultRef.withdraw(amount: amount)

                let unlockedVault = self.unlockedVault.borrow()!
                unlockedVault.deposit(from: <-tokens)

            } else {
                panic("FlowStakingCollection.StakingCollection.withdrawFromMachineAccount: "
                    .concat("Could not find a machine account for the specified node ID ")
                    .concat(nodeID).concat("."))
            }
        }

        /// Function to register a new Delegator Record to the Staking Collection
        access(CollectionOwner) fun registerDelegator(nodeID: String, amount: UFix64) {
            let delegatorIDs = self.getDelegatorIDs()
            for idInfo in delegatorIDs {
                if idInfo.delegatorNodeID == nodeID { 
                    panic("FlowStakingCollection.StakingCollection.registerDelegator: "
                        .concat("Cannot register a delegator for node ").concat(nodeID)
                        .concat(" because that node is already being delegated to from this Staking Collection."))
                }
            }
            
            let tokens <- self.getTokens(amount: amount)

            let nodeDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID, tokensCommitted: <-tokens)

            emit DelegatorAddedToStakingCollection(
                nodeID: nodeDelegator.nodeID,
                delegatorID: nodeDelegator.id,
                amountCommitted: amount,
                address: self.owner?.address
            )

            self.nodeDelegators[nodeDelegator.nodeID] <-! nodeDelegator
        }

        /// Borrows a reference to a node in the collection
        access(self) view fun borrowNode(_ nodeID: String): auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker? {
            if self.nodeStakers[nodeID] != nil {
                return &self.nodeStakers[nodeID] as auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker?
            } else {
                return nil
            }
        }

        /// Borrows a reference to a delegator in the collection
        access(self) view fun borrowDelegator(nodeID: String, delegatorID: UInt32): auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator? {
            if self.nodeDelegators[nodeID] != nil {
                let delegatorRef = (&self.nodeDelegators[nodeID] as auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator?)!
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

        /// Updates the stored networking address for the specified node
        access(CollectionOwner) fun updateNetworkingAddress(nodeID: String, newAddress: String) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil):
                    self.getStakerDoesntExistInCollectionError(funcName: "updateNetworkingAddress", nodeID: nodeID, delegatorID: nil)
            }

            // If the node is stored in the collection, borrow it 
            if let node = self.borrowNode(nodeID) {
                node.updateNetworkingAddress(newAddress)
            } else {
                // Use the node stored in the locked account
                let node = self.tokenHolder!.borrow()!.borrowStaker()
                node.updateNetworkingAddress(newAddress)
            }
        }

        /// Function to stake new tokens for an existing Stake or Delegation record in the StakingCollection
        access(CollectionOwner) fun stakeNewTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID): 
                    self.getStakerDoesntExistInCollectionError(funcName: "stakeNewTokens", nodeID: nodeID, delegatorID: delegatorID)
            }

            // If staking as a delegator, use the delegate functionality
            if let delegatorID = delegatorID {       
                // If the delegator is stored in the collection, borrow it         
                if let delegator = self.borrowDelegator(nodeID: nodeID, delegatorID: delegatorID) {
                    delegator.delegateNewTokens(from: <- self.getTokens(amount: amount))
                } else {
                    let tokenHolder = self.tokenHolder!.borrow()!

                    // Get any needed unlocked tokens, and deposit them to the locked vault.
                    let lockedBalance = self.lockedVault!.borrow()!.balance - FlowStorageFees.minimumStorageReservation
                    if (amount > lockedBalance) {
                        let numUnlockedTokensToUse = amount - lockedBalance
                        tokenHolder.deposit(from: <- self.unlockedVault.borrow()!.withdraw(amount: numUnlockedTokensToUse))
                    }   

                    // Use the delegator stored in the locked account
                    let delegator = tokenHolder.borrowDelegator()
                    delegator.delegateNewTokens(amount: amount)
                }

            // If the node is stored in the collection, borrow it 
            } else if let node = self.borrowNode(nodeID) {
                node.stakeNewTokens(<-self.getTokens(amount: amount))
            } else {
                // Get any needed unlocked tokens, and deposit them to the locked vault.
                let lockedBalance = self.lockedVault!.borrow()!.balance - FlowStorageFees.minimumStorageReservation
                if (amount > lockedBalance) {
                    let numUnlockedTokensToUse = amount - lockedBalance
                    self.tokenHolder!.borrow()!.deposit(from: <- self.unlockedVault.borrow()!.withdraw(amount: numUnlockedTokensToUse))
                } 

                // Use the staker stored in the locked account
                let staker = self.tokenHolder!.borrow()!.borrowStaker()
                staker.stakeNewTokens(amount: amount)
            }
        }

        /// Function to stake unstaked tokens for an existing Stake or Delegation record in the StakingCollection
        access(CollectionOwner) fun stakeUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID):
                    self.getStakerDoesntExistInCollectionError(funcName: "stakeUnstakedTokens", nodeID: nodeID, delegatorID: delegatorID)
            }

            if let delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID: nodeID, delegatorID: delegatorID) {
                    delegator.delegateUnstakedTokens(amount: amount)

                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    delegator.delegateUnstakedTokens(amount: amount)
                }
            } else if let node = self.borrowNode(nodeID) {
                node.stakeUnstakedTokens(amount: amount)
            } else {
                let staker = self.tokenHolder!.borrow()!.borrowStaker()
                staker.stakeUnstakedTokens(amount: amount)
            }
        }

        /// Function to stake rewarded tokens for an existing Stake or Delegation record in the StakingCollection
        access(CollectionOwner) fun stakeRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID):
                    self.getStakerDoesntExistInCollectionError(funcName: "stakeRewardedTokens", nodeID: nodeID, delegatorID: delegatorID)
            }

            if let delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID: nodeID, delegatorID: delegatorID) {
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
            } else if let node = self.borrowNode(nodeID) {
                self.unlockedTokensUsed = self.unlockedTokensUsed + amount
                node.stakeRewardedTokens(amount: amount)
            } else {
                let staker = self.tokenHolder!.borrow()!.borrowStaker()
                staker.stakeRewardedTokens(amount: amount)
            }
        }

        /// Function to request tokens to be unstaked for an existing Stake or Delegation record in the StakingCollection
        access(CollectionOwner) fun requestUnstaking(nodeID: String, delegatorID: UInt32?, amount: UFix64) { 
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID):
                    self.getStakerDoesntExistInCollectionError(funcName: "requestUnstaking", nodeID: nodeID, delegatorID: delegatorID)
            }

            if let delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID: nodeID, delegatorID: delegatorID) {
                    delegator.requestUnstaking(amount: amount)

                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    delegator.requestUnstaking(amount: amount)
                }
            } else if let node = self.borrowNode(nodeID) {
                node.requestUnstaking(amount: amount)
            } else {
                let staker = self.tokenHolder!.borrow()!.borrowStaker()
                staker.requestUnstaking(amount: amount)
            }
        }

        /// Function to unstake all tokens for an existing node staking record in the StakingCollection
        /// Only available for node operators
        access(CollectionOwner) fun unstakeAll(nodeID: String) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: nil):
                    self.getStakerDoesntExistInCollectionError(funcName: "unstakeAll", nodeID: nodeID, delegatorID: nil)
            }
    
            if let node = self.borrowNode(nodeID) {
                node.unstakeAll()
            } else {
                let staker = self.tokenHolder!.borrow()!.borrowStaker()
                staker.unstakeAll()
            }
        }

        /// Function to withdraw unstaked tokens for an existing Stake or Delegation record in the StakingCollection
        access(CollectionOwner) fun withdrawUnstakedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) { 
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID):
                    self.getStakerDoesntExistInCollectionError(funcName: "withdrawUnstakedTokens", nodeID: nodeID, delegatorID: delegatorID)
            }

            if let delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID: nodeID, delegatorID: delegatorID) {
                    let tokens <- delegator.withdrawUnstakedTokens(amount: amount)
                    self.depositTokens(from: <-tokens)
                } else {
                    let delegator = self.tokenHolder!.borrow()!.borrowDelegator()
                    delegator.withdrawUnstakedTokens(amount: amount)
                }
            } else if let node = self.borrowNode(nodeID) {
                let tokens <- node.withdrawUnstakedTokens(amount: amount)
                self.depositTokens(from: <-tokens)
            } else {
                let staker = self.tokenHolder!.borrow()!.borrowStaker()
                staker.withdrawUnstakedTokens(amount: amount)
            }
        }

        /// Function to withdraw rewarded tokens for an existing Stake or Delegation record in the StakingCollection
        access(CollectionOwner) fun withdrawRewardedTokens(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID):
                    self.getStakerDoesntExistInCollectionError(funcName: "withdrawRewardedTokens", nodeID: nodeID, delegatorID: delegatorID)
            }

            if let delegatorID = delegatorID {
                if let delegator = self.borrowDelegator(nodeID: nodeID, delegatorID: delegatorID) {
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
            } else if let node = self.borrowNode(nodeID) {
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

        // Closers

        /// Closes an existing stake or delegation, moving all withdrawable tokens back to the users account and removing the stake
        /// or delegator object from the StakingCollection.
        access(CollectionOwner) fun closeStake(nodeID: String, delegatorID: UInt32?) {
            pre {
                self.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID):
                    self.getStakerDoesntExistInCollectionError(funcName: "closeStake", nodeID: nodeID, delegatorID: delegatorID)
            }

            if let delegatorID = delegatorID {
                let delegatorInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)

                assert(
                    delegatorInfo.tokensStaked + delegatorInfo.tokensCommitted + delegatorInfo.tokensUnstaking == 0.0,
                    message: "FlowStakingCollection.StakingCollection.closeStake: "
                            .concat("Cannot close a delegation until all tokens have been withdrawn, or moved to a withdrawable state.")
                )

                if delegatorInfo.tokensUnstaked > 0.0 {
                    self.withdrawUnstakedTokens(nodeID: nodeID, delegatorID: delegatorID, amount: delegatorInfo.tokensUnstaked)
                }

                if delegatorInfo.tokensRewarded > 0.0 {
                    self.withdrawRewardedTokens(nodeID: nodeID, delegatorID: delegatorID, amount: delegatorInfo.tokensRewarded)
                }

                if let delegator = self.borrowDelegator(nodeID: nodeID, delegatorID: delegatorID) {
                    let delegator <- self.nodeDelegators[nodeID] <- nil
                    destroy delegator
                } else if let tokenHolderCapability = self.tokenHolder {
                    let tokenManager = tokenHolderCapability.borrow()!.borrowTokenManager()
                    let delegator <- tokenManager.removeDelegator()
                    destroy delegator
                } else {
                    panic("FlowStakingCollection.StakingCollection.closeStake: Token Holder capability needed and not found.")
                }

                emit DelegatorRemovedFromStakingCollection(nodeID: nodeID, delegatorID: delegatorID, address: self.owner?.address)

            } else {
                let stakeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)

                /// Set the machine account for this node to `nil` because it no longer exists
                if let machineAccountInfo = self.machineAccounts[nodeID] {
                    let vaultRef = machineAccountInfo.machineAccountVaultProvider.borrow()
                        ?? panic("FlowStakingCollection.StakingCollection.closeStake: Could not borrow vault ref from machine account.")

                    let unlockedVault = self.unlockedVault!.borrow()!
                    var availableBalance: UFix64 = 0.0
                    if FlowStorageFees.storageMegaBytesPerReservedFLOW != (0.0) {
                        availableBalance = FlowStorageFees.defaultTokenAvailableBalance(machineAccountInfo.machineAccountVaultProvider.borrow()!.owner!.address)
                    } else {
                        availableBalance = vaultRef.balance
                    }
                    unlockedVault.deposit(from: <-vaultRef.withdraw(amount: availableBalance))

                    self.machineAccounts[nodeID] = nil
                }

                assert(
                    stakeInfo.tokensStaked + stakeInfo.tokensCommitted + stakeInfo.tokensUnstaking == 0.0,
                    message: "FlowStakingCollection.StakingCollection.closeStake: Cannot close a stake until all tokens have been withdrawn, or moved to a withdrawable state."
                )

                if stakeInfo.tokensUnstaked > 0.0 {
                    self.withdrawUnstakedTokens(nodeID: nodeID, delegatorID: delegatorID, amount: stakeInfo.tokensUnstaked)
                }

                if stakeInfo.tokensRewarded > 0.0 {
                    self.withdrawRewardedTokens(nodeID: nodeID, delegatorID: delegatorID, amount: stakeInfo.tokensRewarded)
                }

                if let node = self.borrowNode(nodeID) {
                    let staker <- self.nodeStakers[nodeID] <- nil
                    destroy staker
                } else if let tokenHolderCapability = self.tokenHolder {
                    let tokenManager = tokenHolderCapability.borrow()!.borrowTokenManager()
                    let staker <- tokenManager.removeNode()
                    destroy staker
                } else {
                    panic("FlowStakingCollection.StakingCollection.closeStake: Token Holder capability needed and not found.")
                }

                emit NodeRemovedFromStakingCollection(nodeID: nodeID, role: stakeInfo.role, address: self.owner?.address)
            }
        }

        /// Getters

        /// Function to get all node ids for all Staking records in the StakingCollection
        access(all) fun getNodeIDs(): [String] {
            let nodeIDs: [String] = self.nodeStakers.keys

            if let tokenHolderCapability = self.tokenHolder {
                let _tokenHolder = tokenHolderCapability.borrow()!

                let tokenHolderNodeID = _tokenHolder.getNodeID()
                if let _tokenHolderNodeID = tokenHolderNodeID {
                    nodeIDs.append(_tokenHolderNodeID)
                }
            }

            return nodeIDs
        }

        /// Function to get all delegator ids for all Delegation records in the StakingCollection
        access(all) fun getDelegatorIDs(): [DelegatorIDs] {
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
        access(all) fun getAllNodeInfo(): [FlowIDTableStaking.NodeInfo] {
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
        access(all) fun getAllDelegatorInfo(): [FlowIDTableStaking.DelegatorInfo] {
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

        /// Gets a users list of machine account information
        access(all) fun getMachineAccounts(): {String: MachineAccountInfo} {
            return self.machineAccounts
        }

    } 

    // Getter functions for accounts StakingCollection information

    /// Function to get see if a node or delegator exists in an accounts staking collection
    access(all) view fun doesStakeExist(address: Address, nodeID: String, delegatorID: UInt32?): Bool {
        let account = getAccount(address)

        let stakingCollectionRef = account.capabilities.borrow<&StakingCollection>(self.StakingCollectionPublicPath)
            ?? panic(self.getCollectionMissingError(address))

        return stakingCollectionRef.doesStakeExist(nodeID: nodeID, delegatorID: delegatorID)
    }

    /// Function to get the unlocked tokens used amount for an account
    access(all) view fun getUnlockedTokensUsed(address: Address): UFix64 {
        let account = getAccount(address)

        let stakingCollectionRef = account.capabilities.borrow<&StakingCollection>(self.StakingCollectionPublicPath)
            ?? panic(self.getCollectionMissingError(address))

        return stakingCollectionRef.unlockedTokensUsed
    }

    /// Function to get the locked tokens used amount for an account
    access(all) view fun getLockedTokensUsed(address: Address): UFix64 {
        let account = getAccount(address)

        let stakingCollectionRef = account.capabilities.borrow<&StakingCollection>(self.StakingCollectionPublicPath)
            ?? panic(self.getCollectionMissingError(address))

        return stakingCollectionRef.lockedTokensUsed
    }

    /// Function to get all node ids for all Staking records in a users StakingCollection, if one exists.
    access(all) fun getNodeIDs(address: Address): [String] {
        let account = getAccount(address)

        let stakingCollectionRef = account.capabilities.borrow<&StakingCollection>(self.StakingCollectionPublicPath)
            ?? panic(self.getCollectionMissingError(address))

        return stakingCollectionRef.getNodeIDs()
    }

    /// Function to get all delegator ids for all Delegation records in a users StakingCollection, if one exists.
    access(all) fun getDelegatorIDs(address: Address): [DelegatorIDs] {
        let account = getAccount(address)

        let stakingCollectionRef = account.capabilities.borrow<&StakingCollection>(self.StakingCollectionPublicPath)
            ?? panic(self.getCollectionMissingError(address))

        return stakingCollectionRef.getDelegatorIDs()
    }

    /// Function to get all Node Info records for all Staking records in a users StakingCollection, if one exists.
    access(all) fun getAllNodeInfo(address: Address): [FlowIDTableStaking.NodeInfo] {
        let account = getAccount(address)

        let stakingCollectionRef = account.capabilities.borrow<&StakingCollection>(self.StakingCollectionPublicPath)
            ?? panic(self.getCollectionMissingError(address))

        return stakingCollectionRef.getAllNodeInfo()
    }

    /// Function to get all Delegator Info records for all Delegation records in a users StakingCollection, if one exists.
    access(all) fun getAllDelegatorInfo(address: Address): [FlowIDTableStaking.DelegatorInfo] {
        let account = getAccount(address)

        let stakingCollectionRef = account.capabilities.borrow<&StakingCollection>(self.StakingCollectionPublicPath)
            ?? panic(self.getCollectionMissingError(address))

        return stakingCollectionRef.getAllDelegatorInfo()
    }

    /// Global function to get all the machine account info for all the nodes managed by an address' staking collection
    access(all) fun getMachineAccounts(address: Address): {String: MachineAccountInfo} {
        let account = getAccount(address)

        let stakingCollectionRef = account.capabilities.borrow<&StakingCollection>(self.StakingCollectionPublicPath)
            ?? panic(self.getCollectionMissingError(address))

        return stakingCollectionRef.getMachineAccounts()
    }

    /// Determines if an account is set up with a Staking Collection
    access(all) view fun doesAccountHaveStakingCollection(address: Address): Bool {
        let account = getAccount(address)
        return account.capabilities
            .get<&StakingCollection>(self.StakingCollectionPublicPath)
            .check()
    }

    /// Gets a standard error message for when a signer does not store a staking collection
    ///
    /// @param account: The account address if talking about an account that is not the signer.
    ///                 If referring to the signer, leave this argument as `nil`.
    ///
    /// @return String: The full error message
    access(all) view fun getCollectionMissingError(_ account: Address?): String {
        if let address = account {
            return "The account ".concat(address.toString())
                .concat(" does not store a Staking Collection object at the path ")
                .concat(FlowStakingCollection.StakingCollectionStoragePath.toString())
                .concat(". They must initialize their account with this object first!")
        } else {
            return "The signer does not store a Staking Collection object at the path "
                .concat(FlowStakingCollection.StakingCollectionStoragePath.toString())
                .concat(". The signer must initialize their account with this object first!")
        }
    }

    /// Creates a brand new empty staking collection resource and returns it to the caller
    access(all) fun createStakingCollection(
        unlockedVault: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>,
        tokenHolder: Capability<auth(FungibleToken.Withdraw, LockedTokens.TokenOperations) &LockedTokens.TokenHolder>?
    ): @StakingCollection {
        return <- create StakingCollection(unlockedVault: unlockedVault, tokenHolder: tokenHolder)
    }

    init() {
        self.StakingCollectionStoragePath = /storage/stakingCollection
        self.StakingCollectionPrivatePath = /private/stakingCollection
        self.StakingCollectionPublicPath = /public/stakingCollection
    }
}
 