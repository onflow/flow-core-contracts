import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Transaction that simulates NodeVersionBeacon contract call from the service chunk
transaction() {

  let NodeVersionBeaconAdminRef: &NodeVersionBeacon.NodeVersionAdmin

  prepare(acct: AuthAccount) {

    // Borrow a reference to the NodeVersionAdmin resource
    self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.NodeVersionAdmin>
      (from: NodeVersionBeacon.NodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow NodeVersionBeaconAdmin Resource")
  }

  execute {
    self.NodeVersionBeaconAdminRef.checkVersionTableChanges()
  }

}