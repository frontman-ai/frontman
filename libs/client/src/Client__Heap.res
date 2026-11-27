@@live
let configuredId: unit => string = %raw(`() => import.meta.env?.VITE_HEAP_APP_ID?.trim() || ""`)

let load: string => unit = %raw(`function(envId) {
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
    }`)

let init = () => {
  let id = configuredId()
  if id != "" {
    load(id)
  }
}

type heapApi = {identify: string => unit, track: (string, JSON.t) => unit}
@scope("window") @val external heap: Nullable.t<heapApi> = "heap"

let getHeap = () => if configuredId() == "" { None } else { heap->Nullable.toOption }

let identify = userId => getHeap()->Option.forEach(api => api.identify(userId))

let track = (eventName, properties) => getHeap()->Option.forEach(api => api.track(eventName, properties))
