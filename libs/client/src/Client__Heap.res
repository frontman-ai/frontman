@@live
let envId = if Client__Env.isDev {
  "349428408"
} else {
  "218974947"
}

let init = () => {
  let _: unit = %raw(`
    (function(envId) {
      window.heapReadyCb=window.heapReadyCb||[];
      window.heap=window.heap||[];
      heap.load=function(e,t){
        window.heap.envId=e;
        window.heap.clientConfig=t=t||{};
        window.heap.clientConfig.shouldFetchServerConfig=false;
        var a=document.createElement("script");
        a.type="text/javascript";
        a.async=true;
        a.src="https://cdn.us.heap-api.com/config/"+e+"/heap_config.js";
        var r=document.getElementsByTagName("script")[0];
        r.parentNode.insertBefore(a,r);
        var n=["init","startTracking","stopTracking","track","resetIdentity","identify","getSessionId","getUserId","getIdentity","addUserProperties","addEventProperties","removeEventProperty","clearEventProperties","addAccountProperties","addAdapter","addTransformer","addTransformerFn","onReady","addPageviewProperties","removePageviewProperty","clearPageviewProperties","trackPageview"];
        var i=function(e){return function(){var t=Array.prototype.slice.call(arguments,0);window.heapReadyCb.push({name:e,fn:function(){heap[e]&&heap[e].apply(heap,t)}})}};
        for(var p=0;p<n.length;p++) heap[n[p]]=i(n[p]);
      };
      heap.load(envId);
    })(envId)
  `)
}

type heapApi = {identify: string => unit, track: (string, JSON.t) => unit}
@scope("window") @val external heap: heapApi = "heap"

type relayFailureReason = HttpError | InvalidResponse | NetworkError
type relayOutcome = Success | Failure(relayFailureReason)

let failureReasonToString = reason =>
  switch reason {
  | HttpError => "http_error"
  | InvalidResponse => "invalid_response"
  | NetworkError => "network_error"
  }

let trackRelayConnection = outcome => {
  let framework = Client__RuntimeConfig.read().framework->Client__RuntimeConfig.frameworkIdToString
  let properties = Dict.fromArray([("framework", JSON.Encode.string(framework))])
  switch outcome {
  | Success => properties->Dict.set("outcome", JSON.Encode.string("success"))
  | Failure(reason) =>
    properties->Dict.set("outcome", JSON.Encode.string("failure"))
    properties->Dict.set("reason_code", JSON.Encode.string(failureReasonToString(reason)))
  }
  heap.track("relay_connection_completed", JSON.Encode.object(properties))
}
