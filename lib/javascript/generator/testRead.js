import { resolve } from "path";
import { getFilesList, readFile } from "../src/utils/file";
import { trimAndSplit } from "../src/utils/strings";

// Handlebars template gist
// https://gist.github.com/utsengar/2287070

const main = async () => {
	const basePath = "../../transactions";
	const fullBasePath = resolve(basePath);
	const fileList = await getFilesList(basePath);
	const list = fileList.map((path) => {
		const code = readFile(path, "utf8");
		return {
			code,
			path,
			packages: trimAndSplit(path, fullBasePath, "\\").slice(0, -1),
		};
	});
	console.log(list[0]);
};

main();
