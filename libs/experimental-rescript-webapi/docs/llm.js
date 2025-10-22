import * as path from "node:path";
import { exec } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs/promises";

const execAsync = promisify(exec);

const bins = await import(
    path.join(import.meta.dirname, "../node_modules/rescript/cli/common/bins.js")
);
const rescriptTools = bins["rescript_tools_exe"];

if (!rescriptTools) {
    throw new Error("rescript-tools not found");
}

async function getDocJson(filePath) {
    try {
        const command = `${rescriptTools} doc "${filePath}"`;
        const options = { maxBuffer: 10 * 1024 * 1024 };
        const { stdout, stderr } = await execAsync(command, options);

        if (stderr) {
            throw new Error(`Error executing command for ${filePath}: ${stderr}`);
        }

        return JSON.parse(stdout);
    } catch (error) {
        throw new Error(`Failed to get documentation JSON for ${filePath}:`, error);
    }
}

async function processFile(filePath) {
    const json = await getDocJson(filePath);

    const moduleName = "WebAPI." + json.name.replace("-WebAPI", "");

    const types = [];
    const functions = [];

    function mkType(item) {
        let description = "";
        if (item.docstrings.length > 0) {
            description = "\n  Description: " + item.docstrings.join("\n");
        }
        let fields = "";
        if (item.detail && item.detail.kind === "record") {
            fields =
                "\n  Fields:\n" +
                item.detail.items
                    .map((field) => {
                        let fieldDoc = "";
                        if (field.docstrings.length > 0) {
                            fieldDoc = " - " + field.docstrings.join(" ");
                        }
                        return `  - ${field.name}: ${field.signature}${fieldDoc}`;
                    })
                    .join("\n");
        }
        return `- ${item.signature}${description}${fields}`;
    }

    function mkFunction(item) {
        let description = "";
        if (item.docstrings.length > 0) {
            description = "\n  Description: " + item.docstrings.join("\n");
        }
        return `- ${item.signature}${description}`;
    }

    for (const item of json.items) {
        switch (item.kind) {
            case "type":
                types.push(mkType(item));
                break;
            case "value":
                functions.push(mkFunction(item));
                break;
        }
    }

    let typeString = "";
    if (types.length > 0) {
        typeString = "\n\nTypes:\n\n" + types.join("\n\n");
    }

    let functionString = "";
    if (functions.length > 0) {
        functionString = "\n\nFunctions:\n\n" + functions.join("\n\n");
    }

    return `File: ${json.source.filepath}
Module: ${moduleName}${typeString}${functionString}
`;
}

const pattern = "../src/**/*.res"
const files = [];
for await (const file of  fs.glob(pattern, { recursive: true, cwd: import.meta.dirname })) {
    files.push(path.join(import.meta.dirname, file));
}
files.sort();

const pages = await Promise.all(files.map(processFile))
const packageJson = await fs.readFile(path.join(import.meta.dirname, "../package.json"), "utf-8");
let version = JSON.parse(packageJson).version;
const sha = await execAsync("git rev-parse --short HEAD").then(({ stdout }) => stdout.trim());
const fullVersion = `${version}-experimental-${sha}`;
const header = `Experimental Rescript WebAPI Documentation ${fullVersion}

This is the API documentation for the experimental WebAPI module version ${fullVersion}.
More information can be found on https://rescript-lang.github.io/experimental-rescript-webapi/

`
const content = pages.join("\n---\n\n");
await fs.writeFile(path.join(import.meta.dirname, "public/llm.txt"), header + content);
console.log("Generated llm.txt");