import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction {
  prepare(owner: AuthAccount, receiver: AuthAccount) {

    // Link the staking admin capability to a private place
    owner.link<&FlowIDTableStaking.Admin>(/private/flowStakingAdmin, target: FlowIDTableStaking.StakingAdminStoragePath)
    let flowStakingAdmin = owner.getCapability<&FlowIDTableStaking.Admin>(/private/flowStakingAdmin)

    let capability <- receiver.load<@FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)

    log(capability.getType())

    destroy capability

    // Save the capability to the receiver's account storage
    receiver.save(flowStakingAdmin, to: FlowIDTableStaking.StakingAdminStoragePath)
  }
}
 
