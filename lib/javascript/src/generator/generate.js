import { resolve } from "path";
import { getFilesList, readFile, trimAndSplit } from "../utils";
import Handlebars from "handlebars";
import "./compiled";

// Handlebars template gist
// https://gist.github.com/utsengar/2287070

const main = async () => {
	const basePath = "../../transactions";
	const templatePath = "../";
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
	const code = Handlebars.templates.asset({
    hash: "12345",
    name: "TestAsset",
    assetName: "generateTestAsset",
    code: `pub fun main(){ log("Hello, Cadence") }`
  });
	console.log(code);
};

main();
