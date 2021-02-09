import fs from "fs";
import { resolve } from "path";

export const readFile = (path) => {
	return fs.readFileSync(path, "utf8");
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