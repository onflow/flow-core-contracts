package main

import (
	"fmt"
	"testing"

	. "github.com/bjartek/overflow"
	"github.com/onflow/cadence"
)

const (
	TestContractCode     = "contract CodyCode {}"
	TestContractCodeSHA3 = "cd1057bd9f593dab406b0a09ffcc7f7468d3ef85021884c4b07430933d94fec0"

	BasePath            = "../../../../transactions"
	TransactionBasePath = "../../../../transactions/contractAudits"
	ScriptBasePath      = "../../../../transactions/contractAudits/scripts/"

	TransactionFolderName = "contractAudits"
	ScriptFolderName      = "contractAudits/scripts"

	AuditorInitTx                 = "auditor/init"
	AuditorNewAuditTx             = "auditor/new_audit"
	AuditorNewAuditHashedTx       = "auditor/new_audit_hashed"
	AuditorDeleteAuditTx          = "auditor/remove_audit"
	AdminAuthorizeAuditorTx       = "admin/authorize_auditor"
	AdminCleanupExpiredVouchersTx = "admin/cleanup_expired"
	DeveloperDeployContractTx     = "fvm/deploy_contract"

	GetVouchersScript = "get_vouchers"

	AuditorAccount    = "auditor"
	DeveloperAccount  = "developer"
	DeveloperAccount2 = "developer2"
	DeveloperAccount3 = "developer3"

	AuditorCreatedEventName = "A.f8d6e0586b0a20c7.FlowContractAudits.AuditorCreated"
	VoucherCreatedEventName = "A.f8d6e0586b0a20c7.FlowContractAudits.VoucherCreated"
	VoucherUsedEventName    = "A.f8d6e0586b0a20c7.FlowContractAudits.VoucherUsed"
	VoucherRemovedEventName = "A.f8d6e0586b0a20c7.FlowContractAudits.VoucherRemoved"

	ErrorNoVoucher = "invalid voucher"
)

// authorizeAuditor initializes the auditor account and deposits the needed capability by admin.
func authorizeAuditor(g *OverflowState, t *testing.T) {
	// auditor init proxy
	g.Tx(AuditorInitTx, WithSigner(AuditorAccount)).AssertSuccess(t)

	// admin authorizes auditor
	g.Tx(AdminAuthorizeAuditorTx,
		WithSignerServiceAccount(),
		WithArg("auditorAddress", AuditorAccount),
	).AssertSuccess(t).
		AssertEmitEventName(t, AuditorCreatedEventName)
}

// deployAndFail deploys the test contract to the provided account and assert failure.
func deployAndFail(g *OverflowState, t *testing.T, account string) {
	g.Tx(DeveloperDeployContractTx,
		WithSignerServiceAccount(),
		WithArg("address", account),
		WithArg("code", TestContractCode),
	).AssertFailure(t, ErrorNoVoucher)
}

// auditContract creates new audit voucher.
// If `anyAccount` is false, the voucher will be created for DeveloperAccount.
// If `expiryOffset` is <= 0, expiryOffset? will be nil.
func auditContract(g *OverflowState, t *testing.T, anyAccount bool, recurrent bool, expiryOffset int, expiryBlockHeight int, hashed bool) {

	eventFields := map[string]interface{}{
		"recurrent": recurrent,
		"codeHash":  TestContractCodeSHA3,
	}

	expiryArg := WithArg("expiryOffset", expiryOffset)
	eventFields["expiryBlockHeight"] = expiryBlockHeight
	if expiryOffset == 0 {
		expiryArg = WithArg("expiryOffset", cadence.NewOptional(nil))
		eventFields["expiryBlockHeight"] = nil
	}
	recurrentArg := WithArg("recurrent", recurrent)

	acc := g.Account(DeveloperAccount)
	optAcc := cadence.NewAddress(acc.Address())
	addressArg := WithArg("address", optAcc)
	eventFields["address"] = g.Address(DeveloperAccount)
	if anyAccount {
		addressArg = WithArg("address", cadence.NewOptional(nil))
		eventFields["address"] = nil
	}

	code := WithArg("codeHash", TestContractCodeSHA3)
	name := AuditorNewAuditHashedTx

	if !hashed {
		name = AuditorNewAuditTx
		code = WithArg("code", TestContractCode)
	}

	g.Tx(name, WithSigner(AuditorAccount),
		code, addressArg, recurrentArg, expiryArg,
	).AssertSuccess(t).
		AssertEvent(t, VoucherCreatedEventName, eventFields)

}

// deploys the test contract to the provided account.
// The initial voucher creation arguments are passed to check against the resulting events.
func deploy(g *OverflowState, t *testing.T, account string, recurrent bool, expiryBlockHeight int, anyAccountVoucher bool) {
	key := fmt.Sprintf("%s-%s", g.Address(account), TestContractCodeSHA3)
	if anyAccountVoucher {
		key = fmt.Sprintf("any-%s", TestContractCodeSHA3)
	}

	var expiry interface{} = expiryBlockHeight
	if expiryBlockHeight == 0 {
		expiry = nil
	}

	result := g.Tx(DeveloperDeployContractTx,
		WithSignerServiceAccount(),
		WithArg("address", account),
		WithArg("code", TestContractCode),
	).AssertSuccess(t).
		AssertEvent(t, VoucherUsedEventName, map[string]interface{}{
			"address":           g.Address(account),
			"key":               key,
			"expiryBlockHeight": expiry,
			"recurrent":         recurrent,
		})

	if !recurrent {
		result.AssertEvent(t, VoucherRemovedEventName, map[string]interface{}{
			"key":               key,
			"expiryBlockHeight": expiry,
			"recurrent":         recurrent,
		})
	}
}

// getVouchersCount returns the count of current vouchers.
func getVouchersCount(g *OverflowState, t *testing.T) int {
	countVouchers, err := g.Script(GetVouchersScript).GetAsInterface()
	if err != nil {
		fmt.Println(err)
		t.Fail()
	}
	return countVouchers.(int)
}
