import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

// Calls the method that emits the table with the incoming versions
transaction() {

    let NodeVersionBeaconHeartbeatRef: &NodeVersionBeacon.Heartbeat

    prepare(acct: AuthAccount) {
        // Borrow a reference to the NodeVersionAdmin resource
        self.NodeVersionBeaconHeartbeatRef = acct.borrow<&NodeVersionBeacon.Heartbeat>
          (from: NodeVersionBeacon.HeartbeatStoragePath)
          ?? panic("Couldn't borrow NodeVersionBeacon.Heartbeat Resource")
    }   
    execute {
        self.NodeVersionBeaconHeartbeatRef.heartbeat()
    }
}