import data from "./dom-dump.json";

// const callback =
//     Object.entries(data.callbackFunctions.callbackFunction)
//         .find(([name, cf]) => {
//             if (Array.isArray(cf.signature)) {
//                 return cf.signature.some(s => {
//                     s.param.some(p => p.isOptional);
//                 });
//             }

//             return false;
//         });

// console.log(callback);

// Sanity check if there are any duplicate external declarations in the generated ReScript files
import { Glob } from "bun";

const glob = new Glob("**/*.res");
const dir = "/home/nojaf/projects/experimental-rescript-webapi/src";

for await (const fileName of glob.scan(dir)) {
  const file = await Bun.file(`${dir}/${fileName}`).text();
  const lines = file.split("\n");
  const seen = new Set();
  for (const line of lines) {
    if (line.startsWith("external ")) {
      const parts = line.split(":");
      const name = parts[0];
      if (seen.has(name)) {
        console.log(`Duplicate in ${fileName}: ${name}`);
      } else {
        seen.add(name);
      }
    }
  }
}
