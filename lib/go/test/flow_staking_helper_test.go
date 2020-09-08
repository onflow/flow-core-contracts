package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	sdk "github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	ft_templates "github.com/onflow/flow-ft/lib/go/templates"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestStakingHelper(t *testing.T) {
	b := newEmulator()
	accountKeys := test.AccountKeyGenerator()

	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	IDTableCode := contracts.FlowIDTableStaking(FTAddress, FlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)
	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	t.Run("Should be able to read empty table fields and initialized fields", func(t *testing.T) {

	})
}
