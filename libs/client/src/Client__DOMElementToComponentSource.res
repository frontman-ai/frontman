@@live
type getElementSourceLocationResult = {
  success: bool,
  data: Client__Types.SourceLocation.t,
  error: option<string>,
}

type reactServerSourceResult = {
  location: Nullable.t<Client__Types.SourceLocation.t>,
  hasClientDefinition: bool,
}
@module("dom-element-to-component-source")
external getElementSourceLocationRaw: (
  ~element: WebAPI.DOMAPI.element,
) => promise<getElementSourceLocationResult> = "getElementSourceLocation"

let getReactServerSourceLocation: WebAPI.DOMAPI.element => reactServerSourceResult = %raw(`function(element) {
  function debugSource(node) {
    return node && (node._debugStack || node.debugStack || node._debugSource);
  }

  function componentName(node) {
    if (!node) return undefined;
    var type = node.type;
    return node.name || (type && (type.displayName || type.name)) || undefined;
  }

  function findFiber() {
    var direct = element._reactInternals || element._reactInternalFiber ||
      element.__reactInternalInstance || element._reactInternalInstance;
    if (direct) return direct;

    var key = Object.keys(element).find(function(key) {
      return key.startsWith("__reactFiber$") || key.startsWith("_reactFiber$");
    });
    return key ? element[key] : null;
  }

  function parseStack(stack) {
    var line = stack.split("\n").find(function(line) {
      return line.includes("about://React/Server/file:///");
    });
    if (!line) return null;

    var source = line.slice(line.indexOf("about://React/Server/")).replace(/\)?$/, "");
    var match = source.match(/^(about:\/\/React\/Server\/file:\/\/\/.*?)(?:\?[^:]*)?:(\d+):(\d+)$/);
    if (!match) return null;

    return {
      file: match[1],
      line: Number(match[2]),
      column: Number(match[3])
    };
  }

  function locationFromDebug(debug, name, tagName) {
    if (!debug || typeof debug.stack !== "string") return null;
    var location = parseStack(debug.stack);
    if (!location) return null;
    location.componentName = name;
    location.tagName = tagName;
    location.parent = undefined;
    location.componentProps = undefined;
    return location;
  }

  function hasBrowserSource(debug) {
    return !!(debug && typeof debug.stack === "string" && debug.stack.split("\n").some(function(line) {
      return !line.includes("about://React/") && /(?:https?:\/\/|webpack:\/\/|file:\/\/\/)/.test(line);
    }));
  }

  function invocationChain(owner) {
    var head = null;
    var tail = null;
    var current = owner;
    for (var depth = 0; current && depth < 10; depth++) {
      var enclosing = current.owner;
      var location = locationFromDebug(
        debugSource(current),
        componentName(enclosing),
        "unknown"
      );
      if (location) {
        if (tail) tail.parent = location;
        else head = location;
        tail = location;
      }
      current = enclosing;
    }
    return head;
  }

  var current = findFiber();
  for (var depth = 0; current && depth < 10; depth++) {
    var owner = current._debugOwner;
    var currentDebug = debugSource(current);
    var location = locationFromDebug(
      currentDebug,
      componentName(owner || current),
      element.tagName
    );
    if (!location) {
      location = locationFromDebug(
        owner && owner.debugLocation,
        componentName(owner || current),
        element.tagName
      );
    }
    if (location) {
      location.parent = invocationChain(owner);
      return {location: location, hasClientDefinition: false};
    }

    if (depth === 0 && hasBrowserSource(currentDebug)) {
      return {
        location: invocationChain(owner),
        hasClientDefinition: true
      };
    }

    var invocation = locationFromDebug(
      debugSource(owner),
      componentName(owner),
      element.tagName
    );
    if (invocation) {
      invocation.parent = invocationChain(owner && owner.owner);
      return {location: invocation, hasClientDefinition: false};
    }
    current = current.return;
  }

  return {location: null, hasClientDefinition: false};
}`)

let rec appendParent = (
  sourceLocation: Client__Types.SourceLocation.t,
  parent: option<Client__Types.SourceLocation.t>,
): Client__Types.SourceLocation.t => {
  switch sourceLocation.parent {
  | Some(existingParent) => {
      ...sourceLocation,
      parent: Some(appendParent(existingParent, parent)),
    }
  | None => {...sourceLocation, parent}
  }
}

let getElementSourceLocation = async (~element: WebAPI.DOMAPI.element) => {
  let reactServerSource = getReactServerSourceLocation(element)
  switch reactServerSource.hasClientDefinition {
  | true =>
    let result = await getElementSourceLocationRaw(~element)
    switch result.success {
    | true => Some(appendParent(result.data, reactServerSource.location->Nullable.toOption))
    | false => reactServerSource.location->Nullable.toOption
    }
  | false =>
    switch reactServerSource.location->Nullable.toOption {
    | Some(location) => Some(location)
    | None =>
      let result = await getElementSourceLocationRaw(~element)
      switch result.success {
      | true => Some(result.data)
      | false => None
      }
    }
  }
}
