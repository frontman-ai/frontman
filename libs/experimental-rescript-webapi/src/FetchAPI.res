@@warning("-30")

open Prelude
open EventAPI
open FileAPI

type responseType =
  | @as("basic") Basic
  | @as("cors") Cors
  | @as("default") Default
  | @as("error") Error
  | @as("opaque") Opaque
  | @as("opaqueredirect") Opaqueredirect

type requestDestination =
  | @as("audio") Audio
  | @as("audioworklet") Audioworklet
  | @as("document") Document
  | @as("embed") Embed
  | @as("font") Font
  | @as("frame") Frame
  | @as("iframe") Iframe
  | @as("image") Image
  | @as("manifest") Manifest
  | @as("object") Object
  | @as("paintworklet") Paintworklet
  | @as("report") Report
  | @as("script") Script
  | @as("sharedworker") Sharedworker
  | @as("style") Style
  | @as("track") Track
  | @as("video") Video
  | @as("worker") Worker
  | @as("xslt") Xslt

type referrerPolicy =
  | @as("no-referrer") NoReferrer
  | @as("no-referrer-when-downgrade") NoReferrerWhenDowngrade
  | @as("origin") Origin
  | @as("origin-when-cross-origin") OriginWhenCrossOrigin
  | @as("same-origin") SameOrigin
  | @as("strict-origin") StrictOrigin
  | @as("strict-origin-when-cross-origin") StrictOriginWhenCrossOrigin
  | @as("unsafe-url") UnsafeUrl

type requestMode =
  | @as("cors") Cors
  | @as("navigate") Navigate
  | @as("no-cors") NoCors
  | @as("same-origin") SameOrigin

type requestCredentials =
  | @as("include") Include
  | @as("omit") Omit
  | @as("same-origin") SameOrigin

type requestCache =
  | @as("default") Default
  | @as("force-cache") ForceCache
  | @as("no-cache") NoCache
  | @as("no-store") NoStore
  | @as("only-if-cached") OnlyIfCached
  | @as("reload") Reload

type requestRedirect =
  | @as("error") Error
  | @as("follow") Follow
  | @as("manual") Manual

type requestPriority =
  | @as("auto") Auto
  | @as("high") High
  | @as("low") Low

/**
@editor.completeFrom(Response) This Fetch API interface allows you to perform various actions on HTTP request and response headers. These actions include retrieving, setting, adding to, and removing. A Headers object has an associated header list, which is initially empty and consists of zero or more name and value pairs.  You can add to this using methods like append() (see Examples.) In all methods of this interface, header names are matched by case-insensitive byte sequence.
[See Headers on MDN](https://developer.mozilla.org/docs/Web/API/Headers)
*/
@editor.completeFrom(Headers)
type headers = {}

/**
This Fetch API interface represents a resource request.
[See Request on MDN](https://developer.mozilla.org/docs/Web/API/Request)
*/
@editor.completeFrom(Request)
type request = {
  /**
    Returns request's HTTP method, which is "GET" by default.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/method)
    */
  method: string,
  /**
    Returns the URL of request as a string.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/url)
    */
  url: string,
  /**
    Returns a Headers object consisting of the headers associated with request. Note that headers added in the network layer by the user agent will not be accounted for in this object, e.g., the "Host" header.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/headers)
    */
  headers: headers,
  /**
    Returns the kind of resource requested by request, e.g., "document" or "script".
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/destination)
    */
  destination: requestDestination,
  /**
    Returns the referrer of request. Its value can be a same-origin URL if explicitly set in init, the empty string to indicate no referrer, and "about:client" when defaulting to the global's default. This is used during fetching to determine the value of the `Referer` header of the request being made.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/referrer)
    */
  referrer: string,
  /**
    Returns the referrer policy associated with request. This is used during fetching to compute the value of the request's referrer.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/referrerPolicy)
    */
  referrerPolicy: referrerPolicy,
  /**
    Returns the mode associated with request, which is a string indicating whether the request will use CORS, or will be restricted to same-origin URLs.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/mode)
    */
  mode: requestMode,
  /**
    Returns the credentials mode associated with request, which is a string indicating whether credentials will be sent with the request always, never, or only when sent to a same-origin URL.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/credentials)
    */
  credentials: requestCredentials,
  /**
    Returns the cache mode associated with request, which is a string indicating how the request will interact with the browser's cache when fetching.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/cache)
    */
  cache: requestCache,
  /**
    Returns the redirect mode associated with request, which is a string indicating how redirects for the request will be handled during fetching. A request will follow redirects by default.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/redirect)
    */
  redirect: requestRedirect,
  /**
    Returns request's subresource integrity metadata, which is a cryptographic hash of the resource being fetched. Its value consists of multiple hashes separated by whitespace. [SRI]
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/integrity)
    */
  integrity: string,
  /**
    Returns a boolean indicating whether or not request can outlive the global in which it was created.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/keepalive)
    */
  keepalive: bool,
  /**
    Returns the signal associated with request, which is an AbortSignal object indicating whether or not request has been aborted, and its abort event handler.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/signal)
    */
  signal: abortSignal,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/body)
    */
  body: Null.t<readableStream<array<int>>>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/bodyUsed)
    */
  bodyUsed: bool,
}

/**
This Fetch API interface represents the response to a request.
[See Response on MDN](https://developer.mozilla.org/docs/Web/API/Response)
*/
@editor.completeFrom(Response)
type response = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Response/type)
    */
  @as("type")
  type_: responseType,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Response/url)
    */
  url: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Response/redirected)
    */
  redirected: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Response/status)
    */
  status: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Response/ok)
    */
  ok: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Response/statusText)
    */
  statusText: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Response/headers)
    */
  headers: headers,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/body)
    */
  body: Null.t<readableStream<array<int>>>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Request/bodyUsed)
    */
  bodyUsed: bool,
}

/**
Provides a way to easily construct a set of key/value pairs representing form fields and their values, which can then be easily sent using the XMLHttpRequest.send() method. It uses the same format a form would use if the encoding type were set to "multipart/form-data".
[See FormData on MDN](https://developer.mozilla.org/docs/Web/API/FormData)
*/
@editor.completeFrom(FormData)
type formData = {}

@editor.completeFrom(HeadersInit) type headersInit

@editor.completeFrom(BodyInit) type bodyInit

type requestInfo = any

type formDataEntryValue = any

type requestInit = {
  /**
    A string to set request's method.
    */
  mutable method?: string,
  /**
    A Headers object, an object literal, or an array of two-item arrays to set request's headers.
    */
  mutable headers?: headersInit,
  /**
    A BodyInit object or null to set request's body.
    */
  mutable body?: bodyInit,
  /**
    A string whose value is a same-origin URL, "about:client", or the empty string, to set request's referrer.
    */
  mutable referrer?: string,
  /**
    A referrer policy to set request's referrerPolicy.
    */
  mutable referrerPolicy?: referrerPolicy,
  /**
    A string to indicate whether the request will use CORS, or will be restricted to same-origin URLs. Sets request's mode.
    */
  mutable mode?: requestMode,
  /**
    A string indicating whether credentials will be sent with the request always, never, or only when sent to a same-origin URL. Sets request's credentials.
    */
  mutable credentials?: requestCredentials,
  /**
    A string indicating how the request will interact with the browser's cache to set request's cache.
    */
  mutable cache?: requestCache,
  /**
    A string indicating whether request follows redirects, results in an error upon encountering a redirect, or returns the redirect (in an opaque fashion). Sets request's redirect.
    */
  mutable redirect?: requestRedirect,
  /**
    A cryptographic hash of the resource to be fetched by request. Sets request's integrity.
    */
  mutable integrity?: string,
  /**
    A boolean to set request's keepalive.
    */
  mutable keepalive?: bool,
  /**
    An AbortSignal to set request's signal.
    */
  mutable signal?: Null.t<abortSignal>,
  mutable priority?: requestPriority,
  /**
    Can only be null. Used to disassociate request from any Window.
    */
  mutable window?: Null.t<unit>,
}

type responseInit = {
  mutable status?: int,
  mutable statusText?: string,
  mutable headers?: headersInit,
}
