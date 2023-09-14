import FlowIDTableStaking from "FlowIDTableStaking"
import LockedTokens from 0xLOCKEDTOKENADDRESS

// Returns an array of DelegatorInfo objects that the account controls
// in its normal account and shared account

access(all) fun main(account: Address): [FlowIDTableStaking.DelegatorInfo] {

    let delegatorInfoArray: [FlowIDTableStaking.DelegatorInfo] = []

    let pubAccount = getAccount(account)

    let optionalDelegatorRef = pubAccount
        .capabilities.borrow<&{FlowIDTableStaking.NodeDelegatorPublic}>(
            /public/flowStakingDelegator
        )

    if let delegatorRef = optionalDelegatorRef {
        let info = FlowIDTableStaking.DelegatorInfo(
            nodeID: delegatorRef.nodeID,
            delegatorID: delegatorRef.id
        )
        delegatorInfoArray.append(info)
    }

    let optionalLockedAccountInfoRef = pubAccount
        .capabilities.borrow<&LockedTokens.TokenHolder>(
            LockedTokens.LockedAccountInfoPublicPath
        )

    if let lockedAccountInfoRef = optionalLockedAccountInfoRef {
        let nodeID = lockedAccountInfoRef.getDelegatorNodeID()
        let delegatorID = lockedAccountInfoRef.getDelegatorID()

        if nodeID != nil && delegatorID != nil {
            let info = FlowIDTableStaking.DelegatorInfo(
                nodeID: nodeID!,
                delegatorID: delegatorID!
            )
            delegatorInfoArray.append(info)
        }
    }

    return delegatorInfoArray
}
