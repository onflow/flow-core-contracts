import fs from "fs";
import { resolve, dirname } from "path";
import { underscoreToCamelCase } from "../strings";

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

export const getFileStructure = async (dir) => {
  console.log('---------Processing:', dir)
	const entities = await fs.promises.readdir(dir, { withFileTypes: true });

	const currentFolder = entities.reduce(
		(acc, entity) => {
			if (entity.isDirectory()) {
			  acc.folders.push(entity);
			  acc.folderNames.push(entity.name);
			} else {
				acc.files.push(underscoreToCamelCase(entity.name));
			}
			return acc;
		},
		{ folderNames: [], folders: [], files: [] }
	);

	currentFolder.name = dir
  console.log(currentFolder)

  await Promise.all(
    currentFolder.folders.map((dirent) => {
      const res = resolve(dir, dirent.name);
      return dirent.isDirectory() ? getFileStructure(res) : res;
    })
  );

/*	for (const item of currentFolder.folders) {
    const res = resolve(item, item.name);
		const nextFolder = await getFileStructure(res);
		console.log({ nextFolder });
		result.push(nextFolder);
	}*/

	return currentFolder;
};
