import test from "node:test";
import assert from "node:assert/strict";
import {
  rewriteSourceText,
  rewriteTestText,
} from "../../scripts/unmonorepo/rewrite-references.mjs";

test("rewrites same-feature references to local modules and external namespaces to dotted names", () => {
  const specs = [
    { publicModule: "DOM", legacyNamespace: "WebApiDOM", internalPrefix: "Dom" },
    { publicModule: "Event", legacyNamespace: "WebApiEvent", internalPrefix: "Event" },
    { publicModule: "URL", legacyNamespace: "WebApiURL", internalPrefix: "Url" },
  ];
  const leavesByFeature = new Map([
    ["DOM", ["Document", "DomGlobal", "DomTypes"]],
    ["Event", ["Event", "EventTarget", "EventTypes"]],
    ["URL", ["URL", "URLSearchParams", "UrlTypes"]],
  ]);

  assert.equal(
    rewriteSourceText(
      "let target: Types.element = Global.document->WebApiEvent.EventTarget.asEventTarget",
      { currentFeature: "DOM", specs, localLeaves: ["Document", "DomGlobal", "DomTypes"], leavesByFeature },
    ),
    "let target: DomTypes.element = DomGlobal.document->EventTarget.asEventTarget",
  );

  assert.equal(
    rewriteSourceText(
      "let target: WebAPI.DOM.Types.element = WebAPI.DOM.Global.document->WebAPI.Event.EventTarget.asEventTarget",
      { currentFeature: "DOM", specs, localLeaves: ["Document", "DomGlobal", "DomTypes"], leavesByFeature },
    ),
    "let target: DomTypes.element = DomGlobal.document->EventTarget.asEventTarget",
  );

  assert.equal(
    rewriteSourceText(
      "type t = UrlTypes.urlSearchParams = private {...Types.urlSearchParams}",
      {
        currentFeature: "URL",
        specs,
        localLeaves: ["URLSearchParams", "UrlTypes"],
        leavesByFeature,
      },
    ),
    "type t = UrlTypes.urlSearchParams = private {...UrlTypes.urlSearchParams}",
  );

  assert.equal(
    rewriteTestText("let x = WebApiDOM.Global.document", specs, leavesByFeature),
    "let x = DomGlobal.document",
  );
});

test("rewrites legacy global module references to simplified public modules", () => {
  const specs = [
    { publicModule: "Fetch", legacyNamespace: "WebApiFetch", internalPrefix: "Fetch" },
    { publicModule: "Canvas", legacyNamespace: "WebApiCanvas", internalPrefix: "Canvas" },
    { publicModule: "WebWorkers", legacyNamespace: "WebApiWebWorkers", internalPrefix: "WebWorkers" },
    {
      publicModule: "ServiceWorker",
      legacyNamespace: "WebApiServiceWorker",
      internalPrefix: "ServiceWorker",
    },
  ];
  const leavesByFeature = new Map([
    ["Fetch", ["Fetch", "FetchTypes"]],
    ["Canvas", ["Canvas", "CanvasTypes"]],
    ["WebWorkers", ["Worker", "SharedWorkerScope", "SharedWorker", "WebWorkersTypes"]],
    ["ServiceWorker", ["ServiceWorker", "ServiceWorkerScope", "ServiceWorkerTypes"]],
  ]);

  assert.equal(
    rewriteTestText(
      "let response = WebApiFetch.Global.fetch(url)",
      specs,
      leavesByFeature,
    ),
    "let response = Fetch.fetch(url)",
  );
  assert.equal(
    rewriteTestText(
      "let bitmap = WebAPI.Canvas.Global.createImageBitmap(image)",
      specs,
      leavesByFeature,
    ),
    "let bitmap = Canvas.createImageBitmap(image)",
  );
  assert.equal(
    rewriteTestText(
      "let self = WebAPI.WebWorkers.WorkerGlobalScope.current",
      specs,
      leavesByFeature,
    ),
    "let self = Worker.current",
  );
  assert.equal(
    rewriteTestText(
      "let self = WebAPI.WebWorkers.SharedWorkerGlobalScope.current",
      specs,
      leavesByFeature,
    ),
    "let self = SharedWorkerScope.current",
  );
  assert.equal(
    rewriteTestText(
      "let self = WebAPI.ServiceWorker.ServiceWorkerGlobalScope.current",
      specs,
      leavesByFeature,
    ),
    "let self = ServiceWorkerScope.current",
  );
});
