// Writes a Rojo-style sourcemap of studio/ so luau-lsp can resolve `script.Parent` requires in CI.
//   node tests/sourcemap.mjs > sourcemap.json
import path from "node:path";
import { studioNodes } from "../tools/rbxkit.mjs";

const root = { name: "Game", className: "DataModel", children: [] };
const byPath = new Map([["", root]]);
for (const node of studioNodes()) {
	const entry = { name: node.name, className: node.className, children: [] };
	if (node.file) entry.filePaths = [path.relative(process.cwd(), node.file).split(path.sep).join("/")];
	byPath.get(node.segments.slice(0, -1).join("/")).children.push(entry);
	byPath.set(node.segments.join("/"), entry);
}
process.stdout.write(JSON.stringify(root, null, 2) + "\n");
