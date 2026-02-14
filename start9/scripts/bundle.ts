#!/usr/bin/env -S deno run --allow-read --allow-write --allow-net --allow-env

// Bundle embassy.ts into a single JavaScript file for the Start9 package.
// Usage: deno run --allow-read --allow-write --allow-net --allow-env bundle.ts

import { bundle } from "https://deno.land/x/emit@0.40.0/mod.ts";

const result = await bundle(new URL("./embassy.ts", import.meta.url));
const { code } = result;

await Deno.writeTextFile("embassy.js", code);
console.log("Bundled embassy.ts -> embassy.js");
