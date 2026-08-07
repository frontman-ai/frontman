@@warning("-30")

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

@editor.completeFrom(Headers)
type headers = private {}

@editor.completeFrom(Request)
type request = private {
  method: string,
  url: string,
  headers: headers,
  destination: requestDestination,
  referrer: string,
  referrerPolicy: referrerPolicy,
  mode: requestMode,
  credentials: requestCredentials,
  cache: requestCache,
  redirect: requestRedirect,
  integrity: string,
  keepalive: bool,
  signal: EventTypes.abortSignal,
  body: Null.t<FileTypes.readableStream<array<int>>>,
  bodyUsed: bool,
}

@editor.completeFrom(Response)
type response = private {
  @as("type")
  type_: responseType,
  url: string,
  redirected: bool,
  status: int,
  ok: bool,
  statusText: string,
  headers: headers,
  body: Null.t<FileTypes.readableStream<array<int>>>,
  bodyUsed: bool,
}

@editor.completeFrom(FormData)
type formData = private {}

@editor.completeFrom(HeadersInit) type headersInit

@editor.completeFrom(BodyInit) type bodyInit

type requestInfo = unknown

@editor.completeFrom(FormDataEntryValue) @unboxed
type formDataEntryValue =
  | String(string)
  | File(FileTypes.file)

type requestInit = {
  mutable method?: string,
  mutable headers?: headersInit,
  mutable body?: bodyInit,
  mutable referrer?: string,
  mutable referrerPolicy?: referrerPolicy,
  mutable mode?: requestMode,
  mutable credentials?: requestCredentials,
  mutable cache?: requestCache,
  mutable redirect?: requestRedirect,
  mutable integrity?: string,
  mutable keepalive?: bool,
  mutable signal?: Null.t<EventTypes.abortSignal>,
  mutable priority?: requestPriority,
  mutable window?: Null.t<unit>,
}

type responseInit = {
  mutable status?: int,
  mutable statusText?: string,
  mutable headers?: headersInit,
}
