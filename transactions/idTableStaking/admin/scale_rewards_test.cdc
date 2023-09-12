import FlowIDTableStaking from "FlowIDTableStaking"

transaction {

    prepare(acct: &Account) {
        let rewardsBreakdown = FlowIDTableStaking.RewardsBreakdown(nodeID: "000000001")

        rewardsBreakdown.setNodeRewards(1000.0)
        rewardsBreakdown.setDelegatorReward(delegatorID: 1 as UInt32, rewards: 100.0)

        rewardsBreakdown.scaleAllRewards(scalingFactor: 0.5)
        assert(
            rewardsBreakdown.nodeRewards == 500.0,
            message: "wrong node rewards scale"
        )

        let delegatorRewards = rewardsBreakdown.delegatorRewards[1 as UInt32]!

        assert(
            delegatorRewards == 50.0,
            message: "wrong delegator rewards scale"
        )
    }
}