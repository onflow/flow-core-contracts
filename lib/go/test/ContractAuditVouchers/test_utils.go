package main

import (
	"fmt"
	"testing"

	"github.com/bjartek/overflow/overflow"
	"github.com/onflow/cadence"
)

const (
	TestContractCode     = "contract CodyCode {}"
	TestContractCodeSHA3 = "cd1057bd9f593dab406b0a09ffcc7f7468d3ef85021884c4b07430933d94fec0"

	TransactionBasePath = "../../../../transactions/contractAudits/"
	ScriptBasePath      = "../../../../transactions/contractAudits/scripts/"

	AuditorInitTx                 = "auditor/init"
	AuditorNewAuditTx             = "auditor/new_audit"
	AuditorDeleteAuditTx          = "auditor/delete_audit"
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

func authorizeAuditor(g *overflow.Overflow, t *testing.T) {
	// auditor init proxy
	g.TransactionFromFile(AuditorInitTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAs(AuditorAccount).
		Test(t).
		AssertSuccess()

	// admin authorizes auditor
	g.TransactionFromFile(AdminAuthorizeAuditorTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAsService().
		Args(g.Arguments().Account(AuditorAccount)).
		Test(t).
		AssertSuccess().
		AssertEmitEventName(AuditorCreatedEventName)
}

func deployAndFail(g *overflow.Overflow, t *testing.T, account string) {
	g.TransactionFromFile(DeveloperDeployContractTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAsService().
		Args(g.Arguments().
			Account(account).
			String(TestContractCode)).
		Test(t).
		AssertFailure(ErrorNoVoucher)
}

func auditContract(g *overflow.Overflow, t *testing.T, anyAccount bool, recurrent bool, expiryOffset int, expiryBlockHeight int) {
	builder := g.TransactionFromFile(AuditorNewAuditTx).
		TransactionPath(TransactionBasePath)

	var argBuilder *overflow.FlowArgumentsBuilder
	var address string
	if anyAccount {
		argBuilder = g.Arguments().Argument(cadence.NewOptional(nil))
	} else {
		address = "0x" + g.Account(DeveloperAccount).Address().String()
		acc := g.Account(DeveloperAccount)
		argBuilder = g.Arguments().Argument(cadence.NewOptional(cadence.NewAddress(acc.Address())))
	}

	argBuilder = argBuilder.
		String(TestContractCode).
		Booolean(recurrent)

	var expiryHeight string
	if expiryOffset > 0 {
		expiryHeight = fmt.Sprintf("%d", expiryBlockHeight)
		argBuilder = argBuilder.Argument(cadence.NewOptional(cadence.NewUInt64(uint64(expiryOffset))))
	} else {
		argBuilder = argBuilder.Argument(cadence.NewOptional(nil))
	}

	builder.SignProposeAndPayAs(AuditorAccount).
		Args(argBuilder).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent(VoucherCreatedEventName, map[string]interface{}{
			"address":           address,
			"codeHash":          TestContractCodeSHA3,
			"expiryBlockHeight": expiryHeight,
			"recurrent":         fmt.Sprintf("%t", recurrent),
		}))
}

func deploy(g *overflow.Overflow, t *testing.T, account string, recurrent bool, expiryBlockHeight int, anyAccountVoucher bool) {
	key := fmt.Sprintf("0x%s-%s", g.Account(account).Address().String(), TestContractCodeSHA3)
	if anyAccountVoucher {
		key = fmt.Sprintf("any-%s", TestContractCodeSHA3)
	}

	expiryBlockHeightStr := ""
	if expiryBlockHeight > 0 {
		expiryBlockHeightStr = fmt.Sprintf("%d", expiryBlockHeight)
	}

	recurrentStr := fmt.Sprintf("%t", recurrent)

	result := g.TransactionFromFile(DeveloperDeployContractTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAsService().
		Args(g.Arguments().
			Account(account).
			String(TestContractCode)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent(VoucherUsedEventName, map[string]interface{}{
			"address":           "0x" + g.Account(account).Address().String(),
			"key":               key,
			"expiryBlockHeight": expiryBlockHeightStr,
			"recurrent":         recurrentStr,
		}))

	if !recurrent {
		result.AssertEmitEvent(overflow.NewTestEvent(VoucherRemovedEventName, map[string]interface{}{
			"key":               key,
			"expiryBlockHeight": expiryBlockHeightStr,
			"recurrent":         recurrentStr,
		}))
	}
}

func getVouchersCount(g *overflow.Overflow, t *testing.T) int {
	countVouchers, err := g.ScriptFromFile(GetVouchersScript).ScriptPath(ScriptBasePath).RunReturns()
	if err != nil {
		fmt.Println(err)
		t.Fail()
	}
	c := countVouchers.(cadence.Int)
	return c.Int()
}
