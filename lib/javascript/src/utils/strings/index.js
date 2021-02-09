export const capitalizeFirstLetter = (input) => {
	const [first] = input.split("");
	return first.toUpperCase() + input.slice(1);
};

export const underscoreToCamelCase = (text) => {
	return text
		.split("_")
		.map((word, i) => (i > 0 ? capitalizeFirstLetter(word) : word))
		.join("");
};

export const trimAndSplit = (input, trimWith, splitBy) => {
	return input.replace(trimWith, "").split(splitBy);
};
