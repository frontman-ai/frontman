import { afterEach, beforeEach, expect, test, vi } from "vitest";
import {
	defaultState,
	handleEffect,
	next,
	Selectors,
} from "../src/state/Client__State__StateReducer.res.mjs";

let tab, fetchRequest, authenticate, state;
const tokenKey = "frontman:embeddedClientToken";
const dispatch = (action) => {
	const [updated, effects] = next(state, action);
	state = updated;
	effects.forEach((effect) => handleEffect(effect, state, dispatch));
};
const request = (value) => dispatch({ TAG: "RequestBilling", _0: value });
const response = (status, body) => ({
	status,
	ok: status < 400,
	json: async () => body,
});

beforeEach(() => {
	localStorage.setItem(tokenKey, "editor-account-a");
	authenticate = vi.fn();
	state = {
		...defaultState,
		acpSession: {
			TAG: "AcpSessionActive",
			apiBaseUrl: "https://api.example",
			requireAuthentication: authenticate,
		},
	};
	tab = { closed: false, close: vi.fn(), location: { assign: vi.fn() } };
	vi.spyOn(window, "open").mockReturnValue(tab);
	fetchRequest = vi.fn();
	vi.stubGlobal("fetch", fetchRequest);
});
afterEach(() => {
	vi.restoreAllMocks();
	vi.unstubAllGlobals();
	localStorage.clear();
});

test.each([
	[{ TAG: "Checkout", _0: "monthly" }, "checkout", { interval: "monthly" }],
	[{ TAG: "Checkout", _0: "yearly" }, "checkout", { interval: "yearly" }],
	["CustomerPortal", "customer-portal", undefined],
])(
	"opens synchronously, then requests a bearer-owned %s URL",
	async (operation, path, body) => {
		let resolve;
		fetchRequest.mockImplementation(
			() =>
				new Promise((done) => {
					resolve = done;
				}),
		);
		request(operation);
		expect(window.open).toHaveBeenCalledWith("about:blank", "_blank");
		expect(window.open.mock.invocationCallOrder[0]).toBeLessThan(
			fetchRequest.mock.invocationCallOrder[0],
		);
		expect(tab.opener).toBeNull();
		expect(state.billingFlow).toBe("Opening");
		request(operation);
		expect(fetchRequest).toHaveBeenCalledOnce();
		const [url, init] = fetchRequest.mock.calls[0];
		expect(url).toBe(`https://api.example/api/billing/${path}`);
		expect(init.method).toBe("POST");
		expect(init.credentials).toBe("omit");
		expect(new Headers(init.headers).get("Authorization")).toBe(
			"Bearer editor-account-a",
		);
		expect(init.body && JSON.parse(init.body)).toEqual(body);
		resolve(response(200, { url: "https://checkout.stripe.test/session" }));
		await vi.waitFor(() =>
			expect(tab.location.assign).toHaveBeenLastCalledWith(
				"https://checkout.stripe.test/session",
			),
		);
		expect(state.billingFlow).toBe("Idle");
	},
);

test("blocked popups do not create an unused checkout", () => {
	window.open.mockReturnValue(null);
	request("CustomerPortal");
	expect(fetchRequest).not.toHaveBeenCalled();
	expect(state.billingFlow).toEqual({
		TAG: "Failed",
		_0: "Allow popups, then try again.",
	});
});

test.each(["missing", "expired"])(
	"%s authorization uses embedded login, never cookies",
	async (mode) => {
		if (mode === "missing") localStorage.clear();
		fetchRequest.mockResolvedValue(
			response(401, { error: "authentication_required" }),
		);
		request("CustomerPortal");
		await vi.waitFor(() => expect(authenticate).toHaveBeenCalledOnce());
		expect(localStorage.getItem(tokenKey)).toBeNull();
		if (mode === "expired") expect(tab.close).toHaveBeenCalledOnce();
		else expect(fetchRequest).not.toHaveBeenCalled();
	},
);

test.each([409, 502])(
	"HTTP %s closes the blank tab and displays the server error",
	async (status) => {
		fetchRequest.mockResolvedValue(
			response(status, {
				error: "Billing rejected the request",
				request_id: "ref-test",
			}),
		);
		request("CustomerPortal");
		await vi.waitFor(() =>
			expect(state.billingFlow).toEqual({
				TAG: "Failed",
				_0: "Billing rejected the request Request reference: ref-test",
			}),
		);
		expect(tab.close).toHaveBeenCalledOnce();
	},
);

test.each(["network failure", "unsafe URL"])(
	"%s closes the tab and allows retry",
	async (failure) => {
		fetchRequest.mockImplementation(() =>
			failure === "network failure"
				? Promise.reject(new TypeError("offline"))
				: Promise.resolve(response(200, { url: "javascript:void(0)" })),
		);
		request("CustomerPortal");
		await vi.waitFor(() => expect(state.billingFlow.TAG).toBe("Failed"));
		expect(tab.close).toHaveBeenCalledOnce();
	},
);

test("an account switch discards an in-flight billing URL", async () => {
	let resolve;
	fetchRequest.mockImplementation(
		() =>
			new Promise((done) => {
				resolve = done;
			}),
	);
	request("CustomerPortal");
	dispatch("ClearAcpSession");
	localStorage.setItem(tokenKey, "other-account");
	resolve(response(200, { url: "https://billing.stripe.test/session" }));
	await vi.waitFor(() => expect(tab.close).toHaveBeenCalledOnce());
	expect(tab.location.assign.mock.calls).toEqual([["about:blank"]]);
	expect(state.billingFlow).toBe("Idle");
});

test("status refresh uses the same bearer without opening a tab", async () => {
	fetchRequest.mockResolvedValue(
		response(200, {
			status: "trialing",
			access_allowed: true,
			has_billing_customer: true,
			interval: "monthly",
			current_period_end: null,
			trial_end: null,
			cancel_at: null,
			canceled_at: null,
		}),
	);
	request("Status");
	await vi.waitFor(() => expect(state.billingStatus.TAG).toBe("Loaded"));
	expect(Selectors.billingAccessAllowed(state)).toBe(true);
	expect(window.open).not.toHaveBeenCalled();
	expect(fetchRequest.mock.calls[0][0]).toBe(
		"https://api.example/api/billing/status",
	);
	expect(fetchRequest.mock.calls[0][1].method).toBe("GET");
});
