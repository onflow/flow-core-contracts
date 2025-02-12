import "FlowIDTableStaking"

transaction {
  prepare(owner: auth(Capabilities) &Account, receiver: auth(Storage) &Account) {

    // Get a staking admin capability
    let flowStakingAdmin = owner.capabilities.storage.issue<&FlowIDTableStaking.Admin>(FlowIDTableStaking.StakingAdminStoragePath)

    let capability <- receiver.storage.load<@FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)

    log(capability.getType())

    destroy capability

    // Save the capability to the receiver's account storage
    receiver.storage.save(flowStakingAdmin, to: FlowIDTableStaking.StakingAdminStoragePath)
  }
}
 
