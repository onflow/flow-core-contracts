const ENVIRONMENTS = {
	emulator: {
		FlowToken: "0xee82856bf20e2aa6",
		FungibleToken: "0x0ae53cb6e3f42a79",
	},
	testnet: {
		FlowToken: "0x7e60df042a9c0868",
		FungibleToken: "0x9a0766d93b6608b7",
		LockedTokens: "0x95e019a17d0e23d7",
		StakingProxy: "0x7aad92e5a0715d21",
	},
	mainnet: {
		FlowToken: "0x1654653399040a61",
		FungibleToken: "0xf233dcee88fe0abe",
		LockedTokens: "0x8d0e87b65159ae63",
		StakingProxy: "0x62430cf28c26d095",
	},
};

export const getEnvironment = (env) => {
	return ENVIRONMENTS[env] || ENVIRONMENTS.emulator;
};
