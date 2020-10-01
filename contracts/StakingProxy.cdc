pub contract StakingProxy {

  pub struct NodeInfo {
    pub var stakingKey: String
    pub var networkingKey: String
    pub var networkingAddress: String

    init(stakingKey: String, networkingKey: String, networkingAddress: String) {
      self.stakingKey = stakingKey
      self.networkingKey = networkingKey
      self.networkingAddress = networkingAddress
    }
  }

  pub resource interface NodeStakerProxy {

    pub fun createStakingRequest(nodeInfo: NodeInfo)

    pub fun stakeNewTokens(amount: UFix64)

    pub fun stakeUnlockedTokens(amount: UFix64)

    pub fun stakeRewardedTokens(amount: UFix64)

    pub fun requestUnstaking(amount: UFix64)

    pub fun unstakeAll(amount: UFix64)

    pub fun withdrawUnlockedTokens(amount: UFix64)

    pub fun withdrawRewardedTokens(amount: UFix64)
  }

  pub resource interface NodeDelagatorProxy {

    pub fun delegateNewTokens(amount: UFix64)

    pub fun delegateUnlockedTokens(amount: UFix64)

    pub fun delegateRewardedTokens(amount: UFix64)

    pub fun requestUnstaking(amount: UFix64)

    pub fun withdrawUnlockedTokens(amount: UFix64)

    pub fun withdrawRewardedTokens(amount: UFix64)
  }
}
