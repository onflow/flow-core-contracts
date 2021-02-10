var Handlebars = require("handlebars");
var template = Handlebars.template,
	templates = (Handlebars.templates = Handlebars.templates || {});
templates["asset"] = template({
	compiler: [8, ">= 4.3.0"],
	main: function (container, depth0, helpers, partials, data) {
		var helper,
			alias1 = depth0 != null ? depth0 : container.nullContext || {},
			alias2 = container.hooks.helperMissing,
			alias3 = "function",
			alias4 = container.escapeExpression,
			lookupProperty =
				container.lookupProperty ||
				function (parent, propertyName) {
					if (Object.prototype.hasOwnProperty.call(parent, propertyName)) {
						return parent[propertyName];
					}
					return undefined;
				};

		return (
			'import { replaceImportAddresses } from "flow-js-testing/dist/utils/imports";\r\nimport { getEnvironment } from "../../utils/env";\r\nimport { reportMissingImports } from \'../utils\'\r\n\r\nexport const NAME = ' +
			alias4(
				((helper =
					(helper =
						lookupProperty(helpers, "name") ||
						(depth0 != null ? lookupProperty(depth0, "name") : depth0)) != null
						? helper
						: alias2),
				typeof helper === alias3
					? helper.call(alias1, {
							name: "name",
							hash: {},
							data: data,
							loc: { start: { line: 5, column: 20 }, end: { line: 5, column: 28 } },
					  })
					: helper)
			) +
			"\r\nexport const HASH = " +
			alias4(
				((helper =
					(helper =
						lookupProperty(helpers, "hash") ||
						(depth0 != null ? lookupProperty(depth0, "hash") : depth0)) != null
						? helper
						: alias2),
				typeof helper === alias3
					? helper.call(alias1, {
							name: "hash",
							hash: {},
							data: data,
							loc: { start: { line: 6, column: 20 }, end: { line: 6, column: 28 } },
					  })
					: helper)
			) +
			";\r\nexport const CODE = `\r\n    " +
			alias4(
				((helper =
					(helper =
						lookupProperty(helpers, "code") ||
						(depth0 != null ? lookupProperty(depth0, "code") : depth0)) != null
						? helper
						: alias2),
				typeof helper === alias3
					? helper.call(alias1, {
							name: "code",
							hash: {},
							data: data,
							loc: { start: { line: 8, column: 4 }, end: { line: 8, column: 12 } },
					  })
					: helper)
			) +
			'\r\n`;\r\n\r\n/**\r\n* Method to generate cadence code for TestAsset\r\n* @param {Object.<string, string>} addressMap - contract name as a key and address where it\'s deployed as value\r\n* @param {( "emulator" | "testnet" | "mainnet" )} [env] - current working environment, defines default deployed contracts\r\n*/\r\nexport const ' +
			alias4(
				((helper =
					(helper =
						lookupProperty(helpers, "assetName") ||
						(depth0 != null ? lookupProperty(depth0, "assetName") : depth0)) != null
						? helper
						: alias2),
				typeof helper === alias3
					? helper.call(alias1, {
							name: "assetName",
							hash: {},
							data: data,
							loc: { start: { line: 16, column: 13 }, end: { line: 16, column: 26 } },
					  })
					: helper)
			) +
			" = (addressMap, env) => {\r\n    const envMap = getEnvironment(env);\r\n    const fullMap = {\r\n    ...envMap,\r\n    ...addressMap,\r\n    };\r\n\r\n    // If there are any missing imports in fullMap it will be reported via console\r\n    const prefix = `${NAME} =>`\r\n    reportMissingImports(CODE, fullMap, prefix)\r\n\r\n    return replaceImportAddresses(CODE, fullMap);\r\n};\r\n\r\n"
		);
	},
	useData: true,
});
templates["package"] = template({
	compiler: [8, ">= 4.3.0"],
	main: function (container, depth0, helpers, partials, data) {
		var helper,
			alias1 = depth0 != null ? depth0 : container.nullContext || {},
			alias2 = container.hooks.helperMissing,
			alias3 = "function",
			alias4 = container.escapeExpression,
			lookupProperty =
				container.lookupProperty ||
				function (parent, propertyName) {
					if (Object.prototype.hasOwnProperty.call(parent, propertyName)) {
						return parent[propertyName];
					}
					return undefined;
				};

		return (
			'/*\n* Flow Core Contracts\n*\n* Copyright 2021 Dapper Labs, Inc.\n*\n* Licensed under the Apache License, Version 2.0 (the "License");\n* you may not use this file except in compliance with the License.\n* You may obtain a copy of the License at\n*\n*   http://www.apache.org/licenses/LICENSE-2.0\n*\n* Unless required by applicable law or agreed to in writing, software\n* distributed under the License is distributed on an "AS IS" BASIS,\n* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n* See the License for the specific language governing permissions and\n* limitations under the License.\n*/\n\nimport { ' +
			alias4(
				((helper =
					(helper =
						lookupProperty(helpers, "packages") ||
						(depth0 != null ? lookupProperty(depth0, "packages") : depth0)) != null
						? helper
						: alias2),
				typeof helper === alias3
					? helper.call(alias1, {
							name: "packages",
							hash: {},
							data: data,
							loc: { start: { line: 19, column: 9 }, end: { line: 19, column: 23 } },
					  })
					: helper)
			) +
			' } from "' +
			alias4(
				((helper =
					(helper =
						lookupProperty(helpers, "packageLocation") ||
						(depth0 != null ? lookupProperty(depth0, "packageLocation") : depth0)) != null
						? helper
						: alias2),
				typeof helper === alias3
					? helper.call(alias1, {
							name: "packageLocation",
							hash: {},
							data: data,
							loc: { start: { line: 19, column: 32 }, end: { line: 19, column: 53 } },
					  })
					: helper)
			) +
			'"'
		);
	},
	useData: true,
});
templates["version"] = template({
	compiler: [8, ">= 4.3.0"],
	main: function (container, depth0, helpers, partials, data) {
		var helper,
			lookupProperty =
				container.lookupProperty ||
				function (parent, propertyName) {
					if (Object.prototype.hasOwnProperty.call(parent, propertyName)) {
						return parent[propertyName];
					}
					return undefined;
				};

		return (
			"export const VERSION = " +
			container.escapeExpression(
				((helper =
					(helper =
						lookupProperty(helpers, "version") ||
						(depth0 != null ? lookupProperty(depth0, "version") : depth0)) != null
						? helper
						: container.hooks.helperMissing),
				typeof helper === "function"
					? helper.call(depth0 != null ? depth0 : container.nullContext || {}, {
							name: "version",
							hash: {},
							data: data,
							loc: { start: { line: 1, column: 23 }, end: { line: 1, column: 34 } },
					  })
					: helper)
			)
		);
	},
	useData: true,
});
