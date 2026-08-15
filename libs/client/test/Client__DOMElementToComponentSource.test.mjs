import { beforeEach, expect, it, vi } from "vitest";

vi.mock("dom-element-to-component-source", () => ({
	getElementSourceLocation: vi.fn(),
}));

import { getElementSourceLocation as getSource } from "dom-element-to-component-source";
import { getElementSourceLocation } from "../src/Client__DOMElementToComponentSource.res.mjs";

beforeEach(() => {
	getSource.mockReset();
});

it("uses selected JSX definition instead of component invocation", async () => {
	const element = document.createElement("div");
	element.__reactFiber$test = {
		_debugOwner: {
			name: "Avatar",
			debugLocation: {
				stack:
					"Error\n    at fakeJSXCallSite (react-stack-top-frame:1:1)\n    at Avatar (about://React/Server/file:///app/.next/server/avatar.js?9:10:7)",
			},
			debugStack: {
				stack:
					"Error\n    at fakeJSXCallSite (react-stack-top-frame:1:1)\n    at Avatar (about://React/Server/file:///app/.next/server/hero-post.js?12:42:11)",
			},
			owner: {
				name: "HeroPost",
				debugStack: {
					stack:
						"Error\n    at fakeJSXCallSite (react-stack-top-frame:1:1)\n    at HeroPost (about://React/Server/file:///app/.next/server/page.js?4:18:5)",
				},
				owner: {
					name: "Index",
				},
			},
		},
	};

	await expect(getElementSourceLocation(element)).resolves.toMatchObject({
		componentName: "Avatar",
		file: "about://React/Server/file:///app/.next/server/avatar.js",
		line: 10,
		column: 7,
		parent: {
			componentName: "HeroPost",
			file: "about://React/Server/file:///app/.next/server/hero-post.js",
			line: 42,
			column: 11,
			parent: {
				componentName: "Index",
				file: "about://React/Server/file:///app/.next/server/page.js",
				line: 18,
				column: 5,
			},
		},
	});
	expect(getSource).not.toHaveBeenCalled();
});

it("uses fiber JSX stack before owner invocation stack", async () => {
	const element = document.createElement("div");
	element.__reactFiber$test = {
		_debugStack: {
			stack:
				"Error\n    at fakeJSXCallSite (react-stack-top-frame:1:1)\n    at Avatar (about://React/Server/file:///app/.next/server/avatar.js?9:10:7)",
		},
		_debugOwner: {
			name: "Avatar",
			debugStack: {
				stack:
					"Error\n    at fakeJSXCallSite (react-stack-top-frame:1:1)\n    at Avatar (about://React/Server/file:///app/.next/server/hero-post.js?12:42:11)",
			},
		},
	};

	await expect(getElementSourceLocation(element)).resolves.toMatchObject({
		componentName: "Avatar",
		file: "about://React/Server/file:///app/.next/server/avatar.js",
		line: 10,
		column: 7,
	});
	expect(getSource).not.toHaveBeenCalled();
});

it("uses server owner definition when host fiber also has a browser stack", async () => {
	const element = document.createElement("div");
	element.__reactFiber$test = {
		_debugStack: {
			stack:
				"Error\n    at div (http://localhost:3000/_next/static/chunks/app.js:100:3)",
		},
		_debugOwner: {
			name: "Avatar",
			debugLocation: {
				stack:
					"Error\n    at Avatar (about://React/Server/file:///app/.next/server/avatar.js?9:10:7)",
			},
			debugStack: {
				stack:
					"Error\n    at Avatar (about://React/Server/file:///app/.next/server/hero-post.js?12:42:11)",
			},
			owner: {
				name: "HeroPost",
				debugStack: {
					stack:
						"Error\n    at HeroPost (about://React/Server/file:///app/.next/server/page.js?4:18:9)",
				},
				owner: { name: "Index" },
			},
		},
	};

	await expect(getElementSourceLocation(element)).resolves.toMatchObject({
		componentName: "Avatar",
		file: "about://React/Server/file:///app/.next/server/avatar.js",
		line: 10,
		column: 7,
		parent: {
			componentName: "HeroPost",
			file: "about://React/Server/file:///app/.next/server/hero-post.js",
			line: 42,
			column: 11,
			parent: {
				componentName: "Index",
				file: "about://React/Server/file:///app/.next/server/page.js",
				line: 18,
				column: 9,
			},
		},
	});
	expect(getSource).not.toHaveBeenCalled();
});

it("preserves a client definition beneath React Server invocations", async () => {
	const element = document.createElement("div");
	element.__reactFiber$test = {
		_debugStack: {
			stack:
				"Error\n    at Avatar (http://localhost:3000/_next/static/chunks/avatar.js:10:7)",
		},
		_debugOwner: {
			name: "Avatar",
			debugStack: {
				stack:
					"Error\n    at Avatar (about://React/Server/file:///app/.next/server/hero-post.js?12:42:11)",
			},
			owner: {
				name: "HeroPost",
				debugStack: {
					stack:
						"Error\n    at HeroPost (about://React/Server/file:///app/.next/server/page.js?4:18:5)",
				},
				owner: { name: "Index" },
			},
		},
	};
	getSource.mockResolvedValue({
		success: true,
		data: {
			componentName: "Avatar",
			tagName: "DIV",
			file: "src/app/_components/avatar.tsx",
			line: 10,
			column: 7,
		},
	});

	await expect(getElementSourceLocation(element)).resolves.toMatchObject({
		componentName: "Avatar",
		file: "src/app/_components/avatar.tsx",
		line: 10,
		column: 7,
		parent: {
			componentName: "HeroPost",
			file: "about://React/Server/file:///app/.next/server/hero-post.js",
			line: 42,
			column: 11,
			parent: {
				componentName: "Index",
				file: "about://React/Server/file:///app/.next/server/page.js",
				line: 18,
				column: 5,
			},
		},
	});
	expect(getSource).toHaveBeenCalledOnce();
});

it("falls back to component invocation when JSX definition is unavailable", async () => {
	const element = document.createElement("div");
	element.__reactFiber$test = {
		_debugOwner: {
			name: "Post",
			debugStack: {
				stack:
					"Error\n    at fakeJSXCallSite (react-stack-top-frame:1:1)\n    at Post (about://React/Server/file:///app/.next/server/chunk.js?17:42:7)",
			},
		},
	};

	await expect(getElementSourceLocation(element)).resolves.toMatchObject({
		componentName: "Post",
		file: "about://React/Server/file:///app/.next/server/chunk.js",
		line: 42,
		column: 7,
	});
	expect(getSource).not.toHaveBeenCalled();
});

it("preserves encoded generated paths while removing React query counters", async () => {
	const element = document.createElement("div");
	element.__reactFiber$test = {
		_debugStack: {
			stack:
				"Error\n    at Avatar (about://React/Server/file:///app/.next/server/%5Broot%5D.js?54:100:3)",
		},
		_debugOwner: { name: "Avatar" },
	};

	await expect(getElementSourceLocation(element)).resolves.toMatchObject({
		file: "about://React/Server/file:///app/.next/server/%5Broot%5D.js",
		line: 100,
		column: 3,
	});
});

it("delegates detection when only a DOM parent has a React Server frame", async () => {
	const parent = document.createElement("section");
	const element = document.createElement("button");
	parent.appendChild(element);
	parent.__reactFiber$test = {
		_debugOwner: {
			_debugStack: {
				stack:
					"Error\n    at Layout (about://React/Server/file:///app/.next/server/layout.js?4:1:1)",
			},
		},
	};
	element.__reactFiber$test = {
		_debugOwner: {
			_debugStack: {
				stack:
					"Error\n    at Button (http://localhost:3000/_next/static/chunk.js:10:2)",
			},
		},
	};
	getSource.mockResolvedValue({
		success: true,
		data: {
			file: "src/Button.tsx",
			line: 10,
			column: 2,
		},
	});

	await expect(getElementSourceLocation(element)).resolves.toMatchObject({
		file: "src/Button.tsx",
		line: 10,
	});
	expect(getSource).toHaveBeenCalledOnce();
});

it("delegates browser-fetchable React frames", async () => {
	const element = document.createElement("button");
	element.__reactFiber$test = {
		_debugOwner: {
			_debugStack: {
				stack:
					"Error\n    at Button (http://localhost:3000/_next/static/chunk.js:10:2)",
			},
		},
	};
	getSource.mockResolvedValue({
		success: true,
		data: {
			file: "src/Button.tsx",
			line: 10,
			column: 2,
		},
	});

	await expect(getElementSourceLocation(element)).resolves.toMatchObject({
		file: "src/Button.tsx",
		line: 10,
	});
	expect(getSource).toHaveBeenCalledOnce();
});

it("returns no location when React detection fails", async () => {
	const element = document.createElement("div");
	getSource.mockResolvedValue({
		success: false,
		error: "No source location found",
	});

	await expect(getElementSourceLocation(element)).resolves.toBeUndefined();
});
