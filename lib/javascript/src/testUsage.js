import flowToken  from "./generated/transactions/flowToken";

const main = async () => {
  const code = flowToken.burnTokens()
	console.log({ code });
};

main();
