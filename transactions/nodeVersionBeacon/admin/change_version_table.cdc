import NodeVersionBeacon from "./../../../contracts/NodeVersionBeacon.cdc"

// Calling this transaction without passing any parameters will make the 
// NodeVersionUpdated event to be emitted, incrementing its sequence number
// even if no update was made to the table

transaction(newVersions: {UInt64: [UInt8]}?, deprecatedVersionsBlocks: [UInt64]?) {

    let NodeVersionBeaconAdminRef: &NodeVersionBeacon.NodeVersionAdmin
    let newVersions: {UInt64: NodeVersionBeacon.Semver}
    
    prepare(acct: AuthAccount) {
        self.newVersions = {}
        if let newVersionsRaw = newVersions {
            for newVersionBlock in newVersionsRaw.keys{
                // Create the new version from the passed parameters
                self.newVersions[newVersionBlock] = NodeVersionBeacon.Semver(
                    major: newVersionsRaw[newVersionBlock]![0], 
                    minor: newVersionsRaw[newVersionBlock]![1], 
                    patch: newVersionsRaw[newVersionBlock]![2], 
                    preRelease: nil, 
                    isBackwardsCompatible: true
                )        
            }
        }
        // Borrow a reference to the NodeVersionAdmin resource
        self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.NodeVersionAdmin>
          (from: NodeVersionBeacon.NodeVersionAdminStoragePath)
          ?? panic("Couldn't borrow NodeVersionBeaconAdmin Resource")
    }   
    execute {
        for height in self.newVersions.keys {
            self.NodeVersionBeaconAdminRef.addVersionBoundaryToTable(targetBlockHeight: height, newVersion: self.newVersions[height]!)
        }
        if let deprecatedBlocks = deprecatedVersionsBlocks {
            for height in deprecatedBlocks {
                // Delete the version from the version table at the specified block height boundary
                self.NodeVersionBeaconAdminRef.deleteUpcomingVersionBoundary(blockHeight: height)
            }
        }
        self.NodeVersionBeaconAdminRef.emitNodeVersionTableUpdated()
    }

}
