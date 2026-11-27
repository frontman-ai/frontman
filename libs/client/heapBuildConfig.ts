import { loadEnv } from "vite";

export function requireHeapAppId(mode: string) {
	const id = loadEnv(mode, process.cwd(), "VITE_").VITE_HEAP_APP_ID?.trim();
	if (!id) throw new Error("VITE_HEAP_APP_ID is required to build or serve the Frontman client");
	return { "import.meta.env.VITE_HEAP_APP_ID": JSON.stringify(id) };
}
