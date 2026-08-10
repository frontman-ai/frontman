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

let identify: string => unit = %raw(`
  function(userId) {
    if (typeof window !== 'undefined' && window.heap && window.heap.identify) {
      window.heap.identify(userId);
    }
  }
`)

let addUserProperties: {..} => unit = %raw(`
  function(properties) {
    if (typeof window !== 'undefined' && window.heap && window.heap.addUserProperties) {
      window.heap.addUserProperties(properties);
    }
  }
`)

type relayFailureReason = HttpError | InvalidResponse | NetworkError
type relayOutcome = Success | Failure(relayFailureReason)

type event =
  | AuthenticatedClientIdentified
  | LocalRelayDiscoveryCompleted({outcome: relayOutcome})
  | ProviderSetupBlockerShown
  | PromptSubmissionInitiated
  | TaskCreationRequested
  | PromptRequestSent

let _track: (string, JSON.t) => unit = %raw(`
  function(name, properties) {
    if (typeof window !== 'undefined' && window.heap && window.heap.track) {
      window.heap.track(name, properties);
    }
  }
`)

let failureReasonToString = reason =>
  switch reason {
  | HttpError => "http_error"
  | InvalidResponse => "invalid_response"
  | NetworkError => "network_error"
  }

let encodeEvent = (~framework, event) => {
  let properties = Dict.fromArray([("framework", JSON.Encode.string(framework))])
  let name = switch event {
  | AuthenticatedClientIdentified => "authenticated_client_identified"
  | LocalRelayDiscoveryCompleted({outcome}) => {
      switch outcome {
      | Success => properties->Dict.set("outcome", JSON.Encode.string("success"))
      | Failure(reason) =>
        properties->Dict.set("outcome", JSON.Encode.string("failure"))
        properties->Dict.set("reason_code", JSON.Encode.string(failureReasonToString(reason)))
      }
      "local_relay_discovery_completed"
    }
  | ProviderSetupBlockerShown => "provider_setup_blocker_shown"
  | PromptSubmissionInitiated => "prompt_submission_initiated"
  | TaskCreationRequested => "task_creation_requested"
  | PromptRequestSent => "prompt_request_sent"
  }
  (name, properties)
}

let track = event => {
  let framework = Client__RuntimeConfig.read().framework->Client__RuntimeConfig.frameworkIdToString
  let (name, properties) = encodeEvent(~framework, event)
  _track(name, JSON.Encode.object(properties))
}
