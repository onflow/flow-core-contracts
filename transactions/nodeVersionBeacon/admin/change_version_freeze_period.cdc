import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Transaction that allows NodeVersionAdmin to change
/// the defined versionUpdateBuffer

transaction(newFreezePeriod: UInt64) {

  let NodeVersionBeaconAdminRef: &NodeVersionBeacon.Admin

  prepare(acct: AuthAccount) {
    // Borrow a reference to the NodeVersionAdmin implementing resource
    self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.Admin>
      (from: NodeVersionBeacon.AdminStoragePath)
      ?? panic("Couldn't borrow NodeVersionBeacon.Admin Resource")
  }

  execute {
    self.NodeVersionBeaconAdminRef.setVersionBoundaryFreezePeriod(newFreezePeriod: newFreezePeriod)
  }

  post{
    NodeVersionBeacon.getVersionBoundaryFreezePeriod() == newFreezePeriod : "Freeze period was not updated"
  }
}
