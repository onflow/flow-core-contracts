import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6

pub let UNLOCKED = "UNLOCKED"

pub contract Lockbox {

  pub resource TokenBucket {
    
    pub var vault: @FlowToken.Vault

    pub var withdrawalLimit: UFix64

    pub fun setWithdrawalLimit(limit: UFix64) {
      self.withdrawalLimit = limit 
    }

    pub fun withdraw(amount: UFix64): @FlowToken.Vault {
      pre {
        self.withdrawalLimit >= amount: "Requested amount exceeds withdrawal limit"
      }

      post {
        self.withdrawalLimit  == before(self.withdrawalLimit) - amount: "Updated withdrawal limit is incorrect"
      }

      let vault <- self.vault.withdraw(amount: amount)

      self.setWithdrawalLimit(self.setWithdrawalLimit - amount)

      return <- vault
    }

    init() {
      self.vault <- FlowToken.createEmptyVault()
      self.withdrawalLimit = 0.0
    }
  }

  pub resource interface Administrator {

    pub fun setWithdrawalLimit(limit: UFix64, tokenType: String)

    pub fun transfer(amount: UFix64, tokenType: String, recipient: Address)

    pub fun depositTokenType(from: @FlowToken.Vault, tokenType: String): UFix64
  }

  pub resource interface Holder {

    // submit req to stake
    pub fun stake(amount: UFix64, tokenType: String)

    // submit req to unstake
    pub fun unstake(amount: UFix64, tokenType: String)

    // move unstaked tokens back into lockbox
    pub fun claimStake(amount: UFix64, tokenType: String)

    // move rewards back into lockbox
    pub fun claimRewards(amount: UFix64)

    // withdraw unlocked rewards from the lockbox
    pub fun withdraw(amount: UFix64): @FlowToken.Vault
  }

  pub resource Vault: FungibleToken.Receiver, Administrator, Holder {
  
    pub var buckets: {String: @TokenBucket}

    // FungibleToken.Receiver actions 

    pub fun deposit(from: @Vault) {
      let newBalance = self.depositTokenType(from: <- from, tokenType: UNLOCKED)
      self.setWithdrawalLimit(limit: newBalance, tokenType: UNLOCKED)
    }

    // Administrator actions

    pub fun setWithdrawalLimit(limit: UFix64, tokenType: String) {
      let bucket = self.buckets[tokenType] ?? panic("no tokens of provided type")

      bucket.setWithdrawalLimit(limit: limit)
    }

    pub fun transfer(amount: UFix64, tokenType: String, recipient: Address) {
      // TODO
    }

    pub fun depositTokenType(from: @FlowToken.Vault, tokenType: String): UFix64 {
      let bucket = self.buckets[tokenType] ?? create TokenBucket()
      bucket.vault.deposit(from: <- from)
    }

    // Holder actions

    pub fun withdraw(amount: UFix64, tokenType: String): @FlowToken.Vault {

      let bucket = self.buckets[tokenType] ?? panic("no tokens of provided type")

      return <- bucket.withdraw(amount: amount)
    }

    pub fun stake(amount: UFix64, tokenType: String) {
      // TODO
    }

    pub fun unstake(amount: UFix64, tokenType: String) {
      // TODO
    }

    pub fun claimStake(amount: UFix64, tokenType: String) {
      // TODO
    }

    pub fun claimRewards(amount: UFix64) {
      // TODO
    }

    init() {
      self.buckets = {}
    }

  }

  pub fun createEmptyVault(): @Vault {
    return <- create Vault()
  }

}
