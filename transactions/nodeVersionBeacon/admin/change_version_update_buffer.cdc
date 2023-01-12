import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Transaction that allows NodeVersionAdmin to change
/// the defined versionUpdateBuffer

transaction(newVersionUpdateBuffer: UInt64) {

  let NodeVersionBeaconAdminRef: &NodeVersionBeacon.NodeVersionAdmin

  prepare(acct: AuthAccount) {
    // Borrow a reference to the NodeVersionAdmin implementing resource
    self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.NodeVersionAdmin>
      (from: NodeVersionBeacon.NodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow NodeVersionBeaconAdmin Resource")
  }

  execute {
    self.NodeVersionBeaconAdminRef.changeVersionUpdateBuffer(newUpdateBufferInBlocks: newVersionUpdateBuffer)
  }

  post{
    NodeVersionBeacon.getVersionUpdateBuffer() == newVersionUpdateBuffer : "Buffer was not updated"
  }
}
