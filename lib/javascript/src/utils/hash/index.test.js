import { hashInput } from "./index";

describe("test hashing", () => {
	test("basic hash", () => {
		const input = "test";
		const result = hashInput(input);
		const expected = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08";

		expect(result).toBe(expected);
	});
});
