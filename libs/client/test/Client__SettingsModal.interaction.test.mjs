import * as StateStore from "@frontman-ai/react-statestore/src/StateStore.res.mjs";
import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, expect, test, vi } from "vitest";
import {
	CustomProviderCard,
	CustomProvidersSection,
	requestSettingsOpenChange,
} from "../src/Client__SettingsModal.res.mjs";
import { defaultState } from "../src/state/Client__State__StateReducer.res.mjs";
import { store } from "../src/state/Client__State__Store.res.mjs";

globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const saved = {
	id: "provider-1",
	name: "Unsaved provider",
	base_url: "https://old.example.com/v1",
	has_api_key: false,
	models: ["old-model"],
	lock_version: 1,
};
const latest = { ...saved, name: "Latest provider", lock_version: 3 };
const conflictError = { TAG: "CustomProviderConflict", _0: latest };
const Card = CustomProviderCard.make;
const valueSetter = Object.getOwnPropertyDescriptor(
	HTMLInputElement.prototype,
	"value",
).set;
let root, container;

const button = (text) =>
	[...container.querySelectorAll("button")].find((element) =>
		element.textContent.includes(text),
	);
const input = (hint) => container.querySelector(`input[placeholder="${hint}"]`);
const mutation = () => StateStore.getState(store).customProviderMutation;
const body = (fetch, i) => JSON.parse(fetch.mock.calls[i][1].body);
const setState = (state = {}) =>
	StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(store, {
		...defaultState,
		acpSession: { TAG: "AcpSessionActive", apiBaseUrl: "/api" },
		customProviders: [],
		...state,
	});

function fail(TAG, id = "provider-1") {
	setState({
		customProviderMutation: {
			TAG: "CustomProviderMutationFailed",
			operation: { TAG, _0: id ?? undefined },
			error: id === null ? "CustomProviderNotFound" : conflictError,
		},
	});
}

const successTag = "CustomProviderMutationSucceeded";
const succeed = (TAG, id) => {
	const customProviderMutation = { TAG: successTag, _0: { TAG, _0: id } };
	act(() => setState({ customProviderMutation }));
};

async function render(component = Card, props = { provider: saved }) {
	container = document.createElement("div");
	root = createRoot(container);
	await act(async () => root.render(React.createElement(component, props)));
}

async function fill(placeholder, value) {
	await act(async () => {
		valueSetter.call(input(placeholder), value);
		input(placeholder).dispatchEvent(new Event("input", { bubbles: true }));
	});
}

afterEach(() => {
	act(() => root?.unmount());
	vi.restoreAllMocks();
});

test("saving reconciles draft and resets API-key state", async () => {
	const updated = { ...saved, name: "Saved provider", lock_version: 2 };
	const fetch = vi
		.spyOn(globalThis, "fetch")
		.mockResolvedValue(new Response(JSON.stringify({ data: updated })));
	setState();
	await render();
	await fill("Optional API key", "replacement-key");
	await act(async () => button("Save").click());
	act(() => root.render(React.createElement(Card, { provider: updated })));
	expect(input("Provider name").value).toBe(updated.name);
	expect(container.querySelector('input[type="password"]').value).toBe("");
	fetch.mockImplementationOnce(() => new Promise(() => {}));
	await fill("Provider name", "Saved provider again");
	await act(async () => button("Save").click());
	expect(body(fetch, 1).lock_version).toBe(2);
	expect(body(fetch, 1).api_key_change.action).toBe("keep");
});

test("provider actions share hierarchy and follow dirty state", async () => {
	setState();
	await render();

	expect(button("Save").parentElement).toBe(button("Cancel").parentElement);
	expect(button("Delete").parentElement).toBe(button("Cancel").parentElement);
	expect(button("Save").disabled).toBe(true);
	expect(button("Cancel").disabled).toBe(true);

	await fill("Provider name", "Changed provider");
	expect(button("Save").disabled).toBe(false);
	expect(button("Cancel").disabled).toBe(false);

	await act(async () => button("Cancel").click());
	expect(input("Provider name").value).toBe(saved.name);
	expect(button("Save").disabled).toBe(true);
	expect(button("Cancel").disabled).toBe(true);
});

test("provider card reports unsaved changes", async () => {
	const onDirtyChange = vi.fn();
	setState();
	await render(Card, { provider: saved, onDirtyChange });
	expect(onDirtyChange).toHaveBeenLastCalledWith(false);

	await fill("Provider name", "Changed provider");
	expect(onDirtyChange).toHaveBeenLastCalledWith(true);

	await act(async () => button("Cancel").click());
	expect(onDirtyChange).toHaveBeenLastCalledWith(false);
});

test("settings close requires confirmation when changes are unsaved", () => {
	const confirm = vi.spyOn(globalThis, "confirm").mockReturnValue(false);
	const onOpenChange = vi.fn();

	requestSettingsOpenChange(false, true, onOpenChange);
	expect(confirm).toHaveBeenCalledWith(
		"You have unsaved changes. Discard them and close?",
	);
	expect(onOpenChange).not.toHaveBeenCalled();

	confirm.mockReturnValue(true);
	requestSettingsOpenChange(false, true, onOpenChange);
	expect(onOpenChange).toHaveBeenLastCalledWith(false);

	confirm.mockClear();
	requestSettingsOpenChange(false, false, onOpenChange);
	expect(confirm).not.toHaveBeenCalled();
	expect(onOpenChange).toHaveBeenLastCalledWith(false);
});

test("editing a model name updates the provider draft", async () => {
	const fetch = vi
		.spyOn(globalThis, "fetch")
		.mockImplementation(() => new Promise(() => {}));
	setState();
	await render();
	const modelInput = [...container.querySelectorAll("input")].find(
		(element) => element.value === "old-model",
	);

	expect(modelInput).toBeDefined();
	await act(async () => {
		valueSetter.call(modelInput, "renamed-model");
		modelInput.dispatchEvent(new Event("input", { bubbles: true }));
	});
	expect(button("Save").disabled).toBe(false);

	await act(async () => button("Save").click());
	expect(body(fetch, 0).models).toEqual(["renamed-model"]);
});

test("conflicts require confirmation and use latest versions", async () => {
	const confirm = vi.spyOn(globalThis, "confirm").mockReturnValue(true);
	const fetch = vi
		.spyOn(globalThis, "fetch")
		.mockImplementation(() => new Promise(() => {}));
	setState();
	await render();
	await fill("Optional API key", "replacement-key");
	await act(async () => fail("SavingCustomProvider"));

	confirm.mockReturnValueOnce(false);
	await act(async () => button("Overwrite latest").click());
	expect(fetch).not.toHaveBeenCalled();
	await act(async () => button("Overwrite latest").click());
	const request = body(fetch, 0);
	expect([request.name, request.lock_version]).toEqual([saved.name, 3]);

	await act(async () => fail("DeletingCustomProvider"));
	await act(async () => button("Cancel delete").click());
	expect(input("Provider name").value).toBe(saved.name);
	expect(mutation()).toBe("CustomProviderMutationIdle");

	await act(async () => fail("DeletingCustomProvider"));
	await act(async () => button("Delete latest").click());
	expect(fetch.mock.calls[1][0]).toContain("lock_version=3");

	await act(async () => fail("SavingCustomProvider"));
	await act(async () => button("Load latest").click());
	expect(input("Provider name").value).toBe(latest.name);
	expect(input("Optional API key").value).toBe("");
	await act(async () => button("Save").click());
	expect(body(fetch, 2).api_key_change.action).toBe("keep");
});

test("section recovers and acknowledges terminal mutations", async () => {
	fail("SavingCustomProvider", null);
	await render(CustomProvidersSection.make, {});
	await act(async () => button("Dismiss").click());
	expect(button("Add Additional Provider").disabled).toBe(false);
	await act(async () => button("Add Additional Provider").click());
	succeed("SavingCustomProvider");
	expect(button("Add Additional Provider").disabled).toBe(false);
	succeed("DeletingCustomProvider", "provider-1");
	expect(mutation()).toBe("CustomProviderMutationIdle");
});

test("section aggregates unsaved provider changes", async () => {
	const onDirtyChange = vi.fn();
	setState({ customProviders: [saved] });
	await render(CustomProvidersSection.make, { onDirtyChange });
	expect(onDirtyChange).toHaveBeenLastCalledWith(false);

	await fill("Provider name", "Changed provider");
	expect(onDirtyChange).toHaveBeenLastCalledWith(true);
});
