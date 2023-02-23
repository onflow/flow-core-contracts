import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

// Calls the method that emits the table with the incoming versions
transaction() {

    let NodeVersionBeaconAdminRef: &NodeVersionBeacon.NodeVersionAdmin

    prepare(acct: AuthAccount) {
        // Borrow a reference to the NodeVersionAdmin resource
        self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.NodeVersionAdmin>
          (from: NodeVersionBeacon.NodeVersionAdminStoragePath)
          ?? panic("Couldn't borrow NodeVersionBeaconAdmin Resource")
    }   
    execute {
        self.NodeVersionBeaconAdminRef.emitVersionBeacon()
    }

}