import "FlowEpoch"
import "FlowIDTableStaking"

/// Pays the rewards for the previous epoch
/// If the rewards have already been paid, the payment will not happen

transaction {
    prepare(signer: auth(BorrowValue) &Account) {
        let heartbeat = signer.storage.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        heartbeat.payRewardsForPreviousEpoch()
    }
}