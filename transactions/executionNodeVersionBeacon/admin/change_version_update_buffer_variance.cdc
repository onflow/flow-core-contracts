import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Transaction that allows ExecutionNodeVersionAdmin to change
/// the defined versionUpdateBufferVariance

transaction(newUpdateBufferVariance: UFix64) {

  let ExecutionNodeVersionBeaconAdminRef: &ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin

  prepare(acct: AuthAccount) {
    // Borrow a reference to the ExecutionNodeVersionAdmin implementing resource
    self.ExecutionNodeVersionBeaconAdminRef = acct.borrow<&ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin>
      (from: ExecutionNodeVersionBeacon.ExecutionNodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow ExecutionNodeVersionBeaconAdmin Resource")
  }

  execute {
    self.ExecutionNodeVersionBeaconAdminRef.changeVersionUpdateBufferVariance(newUpdateBufferVariance)
  }

  post{
    ExecutionNodeVersionBeacon.getVersionUpdateBufferVariance() == newUpdateBufferVariance : "Buffer Variance was not updated"
  }
}
