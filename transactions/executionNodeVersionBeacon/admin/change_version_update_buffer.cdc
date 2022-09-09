import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Transaction that allows ExecutionNodeVersionAdmin to change
/// the defined versionUpdateBuffer

transaction(newVersionUpdateBuffer: UInt64) {

  let ExecutionNodeVersionBeaconAdminRef: &AnyResource{ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin}

  prepare(acct: AuthAccount) {
    // Borrow a reference to the ExecutionNodeVersionAdmin implementing resource
    self.ExecutionNodeVersionBeaconAdminRef = acct.borrow<&AnyResource{ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin}>
      (from: ExecutionNodeVersionBeacon.ExecutionNodeVersionKeeperStoragePath)
      ?? panic("Couldn't borrow ExecutionNodeVersionBeaconAdmin Resource")
  }

  execute {
    // Add the new version to the version table
    self.ExecutionNodeVersionBeaconAdminRef.changeVersionUpdateBuffer(newUpdateBufferInBlocks: newVersionUpdateBuffer)
  }

  post{
    ExecutionNodeVersionBeacon.getVersionUpdateBuffer() == newVersionUpdateBuffer : "Buffer was not updated"
  }
}
