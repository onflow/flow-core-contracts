import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import StakingProxy from 0x01
import FlowIDTableStaking from 0x02

pub contract Lockbox {

  // 1. Admin: Dapper Labs only
  // 2. Shared: Dapper Labs + Token Holder
  // 3. Holder: Token Holder only

  pub let LockedTokenManagerPath: Path

  pub let LockedTokenStakingProxyPrivatePath: Path
  pub let LockedTokenStakingProxyStoragePath: Path

  pub let LockedTokenAdminPrivatePath: Path
  pub let LockedTokenAdminCollectionPath: Path

  pub let LockedTokenProviderPrivatePath: Path

  // stored in Admin account
  pub resource interface TokenAdmin {
    pub fun increaseUnlockLimit(delta: UFix64)
  }

  // stored in Holder account
  pub resource interface TokenHolder {
    pub fun createNodeStakerProxy(): @LockedNodeStakerProxy

    pub fun createNodeDelagtorProxy(nodeAddress: Address): @LockedNodeDelegatorProxy
  }

  pub resource LockedNodeStakerProxy: StakingProxy.NodeStakerProxy {}

  pub resource LockedNodeDelegatorProxy: StakingProxy.NodeDelegatorProxy {
    
    pub var delegator: @FlowIDTableStaking.NodeDelegator

    init(nodeAddress: Address) {
      let nodeRef = getAccount(nodeAddress)
        .getCapability<&FlowIDTableStaking.NodeStaker{FlowIDTableStaking.PublicNodeStaker}>(FlowIDTableStaking.NodeStakerPublicPath)!
        .borrow()
          ?? panic("Could not borrow reference to node staker")

      self.delegator <- nodeRef.createNewDelegator()
    }
  }

  pub resource LockedTokenManager: FungibleToken.Receiver, FungibleToken.Provider, TokenAdmin, TokenHolder {
  
    pub var vault: Capability<&FlowToken.Vault>

    pub var unlockLimit: UFix64

    // FungibleToken.Receiver actions

    pub fun deposit(from: @FlowToken.Vault) {
      let balance = from.balance

      vault.deposit(from: <- from)

      self.increaseUnlockLimit(delta: balance)
    }

    // FungibleToken.Provider actions

    pub fun withdraw(amount: UFix64): @FlowToken.Vault {
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

    pub fun increaseUnlockLimit(delta: UFix64) {  
      self.unlockLimit = self.unlockLimit + delta
    }

    // Lockbox.TokenHolder actions

    pub fun createNodeStakerProxy(): @LockedNodeStakerProxy {
      return <- create LockedNodeStakerProxy()
    }

    pub fun createNodeDelagtorProxy(nodeAddress: Address): @LockedNodeDelegatorProxy {
      return <- create LockedNodeDelegatorProxy(nodeAddress: nodeAddress)
    }

    init(vault: Capability<&FlowToken.Vault>) {
      self.vault = vault
      self.unlockLimit = 0.0

      self.LockedTokenManagerPath = /storage/lockedTokenManager

      self.LockedTokenStakingProxyPrivatePath = /private/lockedTokenStakingProxy
      self.LockedTokenStakingProxyStoragePath = /storage/lockedTokenStakingProxy

      self.LockedTokenAdminPrivatePath = /private/lockedTokenAdmin
      self.LockedTokenAdminCollectionPath = /storage/lockedTokenAdminCollection

      self.LockedTokenProviderPrivatePath = /private/lockedTokenProvider
      self.LockedTokenProviderStoragePath = /storage/lockedTokenProvider
    }
  }

  pub resource TokenAdminCollection {
    access(self) var accounts: {Address: Capability<&LockedTokenManager{TokenAdmin}>}

    pub fun addAccount(
      address: Address, 
      tokenAdmin: Capability<&LockedTokenManager{TokenAdmin}>,
    ) {
      self.accounts[address] = tokenAdmin
    }

    pub fun getAccount(address: Address): Capability<&LockedTokenManager{TokenAdmin}> {
      return self.accounts[address]!
    }
  }

  pub fun createTokenAdminCollection(): @TokenAdminCollection {
    return <- create TokenAdminCollection()
  }

  pub fun createNewLockedTokenManager(vault: Capability<&FlowToken.Vault>): @LockedTokenManager {
    return <- create LockedTokenManager(vault: vault)
  }
}

// NOTES:

// // StakingProxy actions

// // Personas
// // Token Holder (TH)
// // Node Operator (NO)
// // Token Holder/Operator (TH-NO)

// // Use Cases
// // 1. TH-NO stakes directly
// // 2. TH delegates directly
// // 3. NO operates a node with StakingHelper
// // 4. TH stake with StakingHelper

// pub var nodeStaker: Capability<&NodeStaker>
// pub var nodeDelegator: Capability<&NodeDelegator>

// pub fun register1() {
//   // TH-NO provides all node info (keys, address, etc)
//   // Calls addNewNode on staking contract -> return NodeStaker
//   // store NodeStaker object in storage of sharedAccount
//   // create capability for NodeStaker and attach it to this proxy
// }

// pub fun register2() {
//   // TH provides ID of the node they want to delegate to
//   // Calls registerDelegator -> return NodeDelegator
//   // store NodeDelegator object in storage of sharedAccount
//   // create capability for NodeDelegator and attach it to this proxy
// }

// pub fun register3() {
//   // NO provides all node info (keys, address, etc)
//   // 
// }

// // StakingHelper instance already has been created by NO
// pub fun register4(stakingHelper: ??) {
//   stakingHelper.register(myStuff)
// }

// pub fun stake(amount: UFix64) {
//   // TODO
// }

// pub fun unstake(amount: UFix64) {
//   // TODO
// }

// pub fun claimStake(amount: UFix64) {
//   // TODO
// }

// pub fun claimRewards(amount: UFix64) {
//   // TODO
// }