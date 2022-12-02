import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Transaction that allows ExecutionNodeVersionAdmin to change
/// the defined versionUpdateBuffer

transaction(newVersionUpdateBuffer: UInt64) {

  let ExecutionNodeVersionBeaconAdminRef: &ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin

  prepare(acct: AuthAccount) {
    // Borrow a reference to the ExecutionNodeVersionAdmin implementing resource
    self.ExecutionNodeVersionBeaconAdminRef = acct.borrow<&ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin>
      (from: ExecutionNodeVersionBeacon.ExecutionNodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow ExecutionNodeVersionBeaconAdmin Resource")
  }

  execute {
    self.ExecutionNodeVersionBeaconAdminRef.changeVersionUpdateBuffer(newUpdateBufferInBlocks: newVersionUpdateBuffer)
  }

  post{
    ExecutionNodeVersionBeacon.getVersionUpdateBuffer() == newVersionUpdateBuffer : "Buffer was not updated"
  }
}
