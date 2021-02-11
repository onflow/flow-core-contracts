import Handlebars from "handlebars";
import { resolve, dirname } from "path";
import { getFilesList, readFile, writeFile, trimAndSplit, underscoreToCamelCase } from "../utils";
import { getFileStructure } from "../utils/file";

// Load compiled
import "./compiled";

const main = async () => {
	const basePath = "../../transactions";
	const templatePath = "./src/generated";
	const fullBasePath = `${resolve(basePath)}\\`;
	const fileList = await getFilesList(basePath);

	const list = fileList.map((path) => {
		const packages = trimAndSplit(path, fullBasePath, "\\");
		const pathPackages = packages.slice(0, -1);
		const file = packages.slice(-1)[0];

		const code = readFile(path, "utf8");
		const name = underscoreToCamelCase(file.replace(".cdc", ""));
		const data = Handlebars.templates.asset({ code, name, assetName: name });

		const templateFolder = pathPackages.join(`/`);
		const filePath = `${templatePath}/${templateFolder}/${name}.js`;

		writeFile(filePath, data);
	});
};

const main2 = async () => {
	const basePath = "../../transactions";
	await getFileStructure(basePath);
};

main();
