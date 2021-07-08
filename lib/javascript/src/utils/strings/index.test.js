import { trimAndSplit, underscoreToCamelCase } from "./index";

describe("string unit tests - convert to camelCase", () => {
	test("convert single word", () => {
		const input = "single";
		const result = underscoreToCamelCase(input);
		const expected = "single";

		expect(result).toBe(expected);
	});

	test("convert two words", () => {
		const input = "two_words";
		const result = underscoreToCamelCase(input);
		const expected = "twoWords";

		expect(result).toBe(expected);
	});

	test("convert multiple words", () => {
		const input = "multiple_words_combined";
		const result = underscoreToCamelCase(input);
		const expected = "multipleWordsCombined";

		expect(result).toBe(expected);
	});
});

describe("string unit tests - split", () => {
	test("convert single word", () => {
		const input = "testFolder\\firstPackage\\secondPackage\\file.cdc";
		const trimWith = "testFolder\\";
		const splitBy = "\\";
		const result = trimAndSplit(input, trimWith, splitBy);
		const [first, second, third] = result;

		expect(result.length).toBe(3);
		expect(first).toBe("firstPackage");
		expect(second).toBe("secondPackage");
		expect(third).toBe("file.cdc");
	});
});
