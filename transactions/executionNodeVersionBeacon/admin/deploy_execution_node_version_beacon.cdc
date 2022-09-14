// Deploys ExecutionNodeVersionBeacon contract passed as bytecode

transaction(envbName: String, envbCode: [UInt8], initialVersionUpdateBuffer: UInt64, initialVersionUpdateBufferVariance: UFix64) {

    prepare(signer: AuthAccount) {

        signer.contracts.add(
            name: envbName,
            code: envbCode,
            versionUpdateBuffer: initialVersionUpdateBuffer,
            versionUpdateBufferVariance: initialVersionUpdateBufferVariance
        )
    }
}