import fs from "fs";
import { resolve, dirname } from "path";
import prettier from 'prettier';
import parserBabel from 'prettier/parser-babel';
import { underscoreToCamelCase } from "utils/strings";

/**
 * Syntax sugar for file reading
 * @param {string} path - path to file to be read
 */
export const readFile = (path) => {
	return fs.readFileSync(path, "utf8");
};

/**
 * Syntax sugar for file writing
 * @param {string} path - path to file to be read
 * @param {string} data - data to write into file
 */
export const writeFile = (path, data) => {
	const targetDir = dirname(path);
	fs.mkdirSync(targetDir, { recursive: true });
	return fs.writeFileSync(path, data, { encoding: "utf8" });
};

/**
 * Syntax sugar for removing directory and all it's contents
 * @param {string} path - path to directory to delete
 */
export const clearPath = (path) => {
	fs.rmdirSync(path, { recursive: true });
};

export const getFilesList = async (dir) => {
	const dirents = await fs.promises.readdir(dir, { withFileTypes: true });
	const files = await Promise.all(
		dirents.map((dirent) => {
			const res = resolve(dir, dirent.name);
			return dirent.isDirectory() ? getFilesList(res) : res;
		})
	);
	return files.flat();
};

export const sansExtension = (fileName) => {
	return fileName.replace(/\..*/, "");
};

export const prettify = (code) => {
  return prettier.format(code, { parser: 'babel', plugins: [parserBabel] });
};

export const generateExports = async (dir, template) => {
	const entities = await fs.promises.readdir(dir, { withFileTypes: true });

	const currentFolder = entities.reduce(
		(acc, entity) => {
			if (entity.isDirectory()) {
				acc.folders.push(entity);
				acc.folderNames.push(entity.name);
			} else {
			  const camelCased = underscoreToCamelCase(entity.name)
			  const fileName = sansExtension(camelCased)
				acc.files.push(fileName);
			}
			return acc;
		},
		{ folderNames: [], folders: [], files: [] }
	);

	currentFolder.name = dir;

	const packageData = template({
		folders: currentFolder.folderNames,
		files: currentFolder.files,
	});
	writeFile(`${dir}/index.js`, prettify(packageData))

	await Promise.all(
		currentFolder.folders.map((dirent) => {
			const res = resolve(dir, dirent.name);
			return dirent.isDirectory() ? generateExports(res, template) : res;
		})
	);

	return currentFolder;
};
