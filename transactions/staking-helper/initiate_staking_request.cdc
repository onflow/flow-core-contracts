// Initiate the staking request via StakingHelper

import FlowIDTableStaking from 0xFLOW_TABLE_STAKING
import StakingHelper from 0xSTAKING_HELPER_ADDRESS

transaction(id:String){
    let operator: AuthAccount
    let adminRef: &FlowIDTableStaking.StakingAdmin
    let admintPath: Path

    prepare(acct: AuthAccount){
        self.operator = acct
        let adminPath = FlowIDTableStaking.StakingAdminStoragePath

    // TODO:    
    // - Get Admin capability to StakingAdmin
    }

    execute {
        
    }

    post {

    }

}