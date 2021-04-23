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
	if (splitBy){
		return input.replace(trimWith, "").split(splitBy);
	}
	return input.replace(trimWith, "").split(getSplitCharacter(input));
};

export const getSplitCharacter = (input) => {
	switch (true){
		case input.indexOf("//") >= 0:
			return "//"
		case input.indexOf("/") >= 0:
			return "/"
		case input.indexOf("\\") >= 0:
			return "\\"
		default:
			return ""
	}
}
