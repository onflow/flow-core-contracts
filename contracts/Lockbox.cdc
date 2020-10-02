/*

    Lockbox implements the functionality required to manage FLOW
    buyers locked tokens from the token sale.

    Each token holer gets two accounts. One account is their locked token
    account. It will be jointly controlled by the user and Dapper Labs.
    No actions will be able to be performed with this account without authorization
    from Dapper Labs. Locked tokens are stored in this account and Dapper Labs
    with authorize withdrawals every time a milestone is passed in the
    vesting period.
        
    The second account is the unlocked user account. This account is
    in full possesion and control of the user and they can do whatever
    they want with it. This account will store a capability that allows
    them to withdraw tokens when they become unlocked and also to
    perform staking operations with their locked tokens.

    When a user account is created, both accounts are initialized with
    their respective objects, LockedTokenManager for the shared account,
    and TokenHolder for the unlocked account. The user calls functions
    on TokenHolder to withdraw tokens from the shared account and to 
    perform staking actions with the locked tokens

 */

import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import FlowIDTableStaking from 0x179b6b1cb6755e31

import StakingProxy from 

pub contract Lockbox {

    /// path to store the locked token manager resource 
    /// in the shared account
    pub let LockedTokenManagerPath: Path

    /// path to store the private locked token admin link
    /// in the shared account
    pub let LockedTokenAdminPrivatePath: Path

    /// path to store the admin collection 
    /// in the admin account
    pub let LockedTokenAdminCollectionPath: Path

    /// path to store the token holder resource
    /// in the unlocked account
    pub let TokenHolderStoragePath: Path

    /// stored in Admin account to use to increase the unlock
    /// token limit every time a vesting release happens
    pub resource interface TokenAdmin {
        pub fun increaseUnlockLimit(delta: UFix64)
    }

    /// stored in the shared account to manage access to the locked token vault
    /// and to the staking/delegating resources
    pub resource LockedTokenManager: FungibleToken.Receiver, FungibleToken.Provider, TokenAdmin {
    
        /// Capability to the normal Flow Token Vault in the shared account
        pub var vault: Capability<&FlowToken.Vault>

        /// The amount of tokens that the user can withdraw. 
        /// It is decreased when the user withdraws
        pub var unlockLimit: UFix64

        /// Optional NodeStaker resource. Will only be filled if the user
        /// signs up to be a node operator
        pub var nodeStaker: @FlowIDTableStaking.NodeStaker?

        /// Optional NodeDelegator resource. Will only be filled if the user
        /// signs up to be a delegator
        pub var nodeDelegator: @FlowIDTableStaking.NodeDelegator?

        init(vault: Capability<&FungibleToken.Vault>) {
            self.vault = vault
            self.nodeStaker = nil
            self.nodeDelegator = nil
            self.unlockLimit = 0.0
        }

        // FungibleToken.Receiver actions

        pub fun deposit(from: @FungibleToken.Vault) {
            let balance = from.balance

            self.vault.deposit(from: <- from)

            self.increaseUnlockLimit(delta: balance)
        }

        // FungibleToken.Provider actions

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.unlockLimit >= amount: "Requested amount exceeds unlocked token limit"
            }

            post {
                self.unlockLimit == before(self.unlockLimit) - amount: "Updated unlocked token limit is incorrect"
            }

            let vault <- self.vault.withdraw(amount: amount)

            self.decreaseUnlockLimit(delta: amount)

            return <- vault
        }

        access(self) fun decreaseUnlockLimit(delta: UFix64) {  
            self.unlockLimit = self.unlockLimit - delta
        }

        // Lockbox.TokenAdmin actions

        /// Called by the admin every time a vesting release happens
        pub fun increaseUnlockLimit(delta: UFix64) {  
            self.unlockLimit = self.unlockLimit + delta
        }

        // Lockbox.TokenHolder actions

        /// Registers a new node operator with the Flow Staking contract
        ///
        pub fun registerNode(nodeInfo: StakingProxy.NodeInfo) {
            self.nodeStaker <- FlowIDTableStaking.addNodeRecord(id: nodeInfo.id, role: nodeInfo.role, networkingAddress: nodeInfo.networkingAddress, networkingKey: nodeInfo.String, stakingKey: nodeInfo.stakingKey)
        }

        /// Registers a new Delegator with the Flow Staking contract
        /// the caller has to specify the ID of the node operator
        /// they are delegating to
        pub fun registerDelegator(nodeID: String) {
            self.nodeDelegator <- FlowIDTableStaking.registerDelegator(nodeID: nodeID)
        }
    }

    // Stored in Holder unlocked account
    pub resource TokenHolder {

        /// Capability that is used to access the LockedTokenManager
        /// in the shared account
        access(self) var tokenManager: Capability<&LockedTokenManager>

        /// Used to perform staking actions if the user has signed up
        /// as a node operator
        access(self) var nodeStakerProxy: LockedNodeStakerProxy?

        /// Used to perform delegating actions if the user has signed up
        /// as a delegator
        access(self) var nodeDelegatorProxy: LockedNodeDelegatorProxy?

        init(tokenManager: Capability<&LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Must pass a LockedTokenManager capability"
            }
            self.tokenManager = tokenManager
            self.nodeStakerProxy = nil
            self.nodeDelegatorProxy = nil
        }

        /// Deposits tokens in the locked vault, which marks them as 
        /// unlocked and available to withdraw
        pub fun deposit(from: @FungibleToken.Vault) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.deposit(from: <-from)
        }

        // FungibleToken.Provider actions

        /// Withdraws tokens from the locked vault. This will only succeed
        /// if the withdraw amount is less than or equal to the limit
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            let tokenManagerRef = self.tokenManager.borrow()!

            return <- tokenManagerRef.withdraw(amount: amount)
        }

        /// The user calls this function if they want to register as a node operator
        /// They have to provide all the info for their node
        pub fun createNodeStaker(nodeInfo: StakingProxy.NodeInfo) {
            pre {
                self.nodeStakerProxy == nil && self.nodeDelegatorProxy == nil: "Already initialized"
            }

            let tokenManagerRef = self.tokenManager.borrow()!

            // register node, which stores the NodeStaker object in the LockedTokenManager
            tokenManagerRef.registerNode(nodeInfo: nodeInfo)

            // Create a new staker proxy that can be accessed in transactions
            self.nodeStakerProxy = LockedNodeStakerProxy(tokenManager: self.tokenManager)
        }

        /// The user calls this function if they want to register as a node operator
        /// They have to provide all the info for their node
        pub fun createNodeDelagtor(nodeID: String) {
            pre {
                self.nodeStakerProxy == nil && self.nodeDelegatorProxy == nil: "Already initialized"
            }

            let tokenManagerRef = self.tokenManager.borrow()!

            // register delegator, which stores the NodeDelegator object in the LockedTokenManager
            tokenManagerRef.registerDelegator(nodeID: nodeID)

            // create a new delegator proxy that can be accessed in transactions
            self.nodeDelegatorProxy = LockedNodeDelegatorProxy(tokenManager: self.tokenManager)
        }

        /// Borrow a "reference" to the staking object which allows the caller
        /// to perform all staking actions with locked tokens.
        pub fun borrowStaker(): LockedNodeStakerProxy {
            pre {
                self.nodeStakerProxy != nil:
                    "The NodeStakerProxy doesn't exist!"
            }
            return self.nodeStakerProxy!
        }

        /// Borrow a "reference" to the delegating object which allows the caller
        /// to perform all delegating actions with locked tokens.
        pub fun borrowDelegator(): LockedNodeDelegatorProxy {
            pre {
                self.nodeDelegatorProxy != nil:
                    "The NodeDelegatorProxy doesn't exist!"
            }
            return self.nodeDelegatorProxy!
        }
    }

    /// Used to perform staking actions
    pub struct LockedNodeStakerProxy: StakingProxy.NodeStakerProxy {

        access(self) var tokenManager: Capability<&LockedTokenManager>

        init(tokenManager: Capability<&LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Invalid token manager capability"
            }
            self.tokenManager = tokenManager
        }

        /// Stakes new locked tokens
        pub fun stakeNewTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            let vaultRef = tokenManagerRef.vault.borrow()!

            tokenManagerRef.nodeStaker?.stakeNewTokens(from: <-vaultRef.withdraw(amount: amount))
        }

        /// Stakes unlocked tokens from the staking contract
        pub fun stakeUnlockedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeStaker?.stakeUnlockedTokens(amount: amount)
        }

        /// Stakes rewarded tokens. Rewarded tokens are freely withdrawable
        /// so if they are staked, the withdraw limit should be increased
        /// because staked tokens are effectively treated as locked tokens
        pub fun stakeRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeStaker?.stakeRewardedTokens(amount:amount)

            tokenManagerRef.increaseUnlockLimit(delta: amount)
        }

        /// Requests unstaking for the node
        pub fun requestUnstaking(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeStaker?.requestUnStaking(amount: amount)
        }

        /// Requests to unstake all of the node's tokens and all of
        /// the tokens that have been delegated to the node
        pub fun unstakeAll(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeStaker?.unstakeAll()
        }

        /// Withdraw the unstaked/unlocked tokens back to 
        /// the locked token vault. This does not increase the withdraw
        /// limit because staked/unstaked tokens are considered to still
        /// be locked in terms of the vesting schedule
        pub fun withdrawUnlockedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            let vaultRef = tokenManagerRef.vault.borrow()!

            let withdrawnTokens <- tokenManagerRef.nodeStaker?.withdrawUnlockedTokens(amount: amount)!

            vaultRef.deposit(from: <-withdrawnTokens)
        }

        /// Withdraw reward tokens to the locked vault, 
        /// which increases the withdraw limit
        pub fun withdrawRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.deposit(from: <-tokenManagerRef.nodeStaker?.withdrawRewardedTokens(amount: amount))
        }
    }

    /// Used to perform delegating actions in transactions
    pub struct LockedNodeDelegatorProxy: StakingProxy.NodeDelegatorProxy {

        access(self) var tokenManager: Capability<&LockedTokenManager>

        init(tokenManager: Capability<&LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Invalid LockedTokenManager capability"
            }
            self.tokenManager = tokenManager
        }

        /// delegates tokens from the locked token vault
        pub fun delegateNewTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            let vaultRef = tokenManagerRef.vault.borrow()!

            tokenManagerRef.nodeDelegator?.delegatorNewTokens(from: <-vaultRef.withdraw(amount: amount))
        }

        /// Delegate tokens from the unlocked staking bucket
        pub fun delegateUnlockedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeDelegator?.delegateUnlockedTokens(amount: amount)
        }

        /// Delegate rewarded tokens. Increases the unlock limit
        /// because these are freely withdrawable
        pub fun delegateRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeDelegator?.delegateRewardedTokens(amount: amount)

            tokenManagerRef.increaseUnlockLimit(delta: amount)
        }

        /// Request to unstake tokens
        pub fun requestUnstaking(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeDelegator?.requestUnStaking(amount: amount)
        }

        /// withdraw unlocked tokens back to the locked vault
        /// This does not increase the withdraw limit
        pub fun withdrawUnlockedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            let vaultRef = tokenManagerRef.vault.borrow()!

            vaultRef.deposit(from: <-tokenManagerRef.nodeDelegator?.withdrawUnlockedTokens(amount: amount))
        }

        /// Withdraw rewarded tokens back to the locked vault,
        /// which increases the withdraw limit because these 
        /// are considered unlocked in terms of the vesting schedule
        pub fun withdrawRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.deposit(from: <-tokenManagerRef.nodeDelegator?.withdrawRewardedTokens(amount: amount))
        }
    }

    /// Resource that the Dapper Labs token admin
    /// stores in their account to manage the vesting schedule
    /// for all the token holders
    pub resource TokenAdminCollection {
        
        /// Mapping of account addresses to LockedTokenManager capabilities
        access(self) var accounts: {Address: Capability<&LockedTokenManager{TokenAdmin}>}

        init() {
            self.accounts = {}
        }

        /// Add a new account's locked token manager capability
        /// to the record
        pub fun addAccount(
            address: Address, 
            tokenAdmin: Capability<&LockedTokenManager{TokenAdmin}>,
        ) {
            self.accounts[address] = tokenAdmin
        }

        /// Get an accounts capability
        pub fun getAccount(address: Address): Capability<&LockedTokenManager{TokenAdmin}> {
            return self.accounts[address]!
        }
    }

    /// Public function to create a new token admin collection
    pub fun createTokenAdminCollection(): @TokenAdminCollection {
        return <- create TokenAdminCollection()
    }

    /// Public function to create a new Locked Token Manager
    /// every time a new user account is created
    pub fun createNewLockedTokenManager(vault: Capability<&FlowToken.Vault>): @LockedTokenManager {
        return <- create LockedTokenManager(vault: vault)
    }

    // Creates a new TokenHolder resource for this LockedTokenManager
    /// that the user can store in their unlocked account.
    pub fun createTokenHolder(tokenManager: Capability<&LockedTokenManager>): @TokenHolder {
        return <- create TokenHolder(tokenManager: tokenManager)
    }

    init() {
        self.LockedTokenManagerPath = /storage/lockedTokenManager

        self.LockedTokenAdminPrivatePath = /private/lockedTokenAdmin
        self.LockedTokenAdminCollectionPath = /storage/lockedTokenAdminCollection

        self.TokenHolderStoragePath = /storage/flowTokenHolder
    }
}