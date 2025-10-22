import * as Browser from "./types.js";
import { mapToArray } from "./helpers.js";
import { promises as fs } from "fs";
import { execSync } from "child_process";
import { fileURLToPath } from "url";
import * as path from "path";

/// Decide which members of a function to emit
enum EmitScope {
  StaticOnly,
  InstanceOnly,
  All,
}

const tsKeywords = new Set(["default", "delete", "continue"]);
const extendConflictsBaseTypes: Record<
  string,
  { extendType: string[]; memberNames: Set<string> }
> = {
  HTMLCollection: {
    extendType: ["HTMLFormControlsCollection"],
    memberNames: new Set(["namedItem"]),
  },
};

// Namespaces that have been in form of interfaces for years
// and can't be converted to namespaces without breaking type packages
const namespacesAsInterfaces = ["console"];

// Used to decide if a member should be emitted given its static property and
// the intended scope level.
function matchScope(scope: EmitScope, x: { static?: boolean }) {
  return (
    scope === EmitScope.All || (scope === EmitScope.StaticOnly) === !!x.static
  );
}

/// Parameter cannot be named "default" in JavaScript/Typescript so we need to rename it.
function adjustParamName(name: string) {
  return tsKeywords.has(name) ? `_${name}` : name;
}

function getElements<K extends string, T>(
  a: Record<K, Record<string, T>> | undefined,
  k: K,
): T[] {
  return a ? mapToArray(a[k]) : [];
}

function createTextWriter(newLine: string) {
  let output: string;
  let indent: number;
  let lineStart: boolean;
  /** print declarations conflicting with base interface to a side list to write them under a different name later */
  let stack: { content: string; indent: number }[] = [];

  function getIndentString(level: number) {
    return "    ".repeat(level);
  }

  function write(s: string) {
    if (s && lineStart) {
      output += getIndentString(indent);
      lineStart = false;
    }
    output += s;
  }

  function reset(): void {
    output = "";
    indent = 0;
    lineStart = true;
    stack = [];
  }

  function endLine() {
    output += newLine;
    lineStart = true;
  }

  reset();

  return {
    reset,

    increaseIndent() {
      indent++;
    },
    decreaseIndent() {
      indent--;
    },

    endLine,
    print: write,
    printLine(c: string) {
      write(c);
      endLine();
    },

    clearStack() {
      stack = [];
    },
    stackIsEmpty() {
      return stack.length === 0;
    },
    printLineToStack(content: string) {
      stack.push({ content, indent });
    },
    printStackContent() {
      stack.forEach((e) => {
        const oldIndent = indent;
        indent = e.indent;
        this.printLine(e.content);
        indent = oldIndent;
      });
    },

    getResult() {
      return output;
    },
  };
}

function isEventHandler(p: Browser.Property) {
  return typeof p.eventHandler === "string";
}

function toCamelCase(input: string) {
  try {
    let i = 0;

    // Count uppercase letters at the start
    while (i < input.length && input[i] === input[i].toUpperCase()) {
      i++;
    }

    // If only one capital, lowercase it
    if (i === 1) return input[0].toLowerCase() + input.slice(1);

    // If more than one capital, lowercase until the last one in the sequence
    return input.slice(0, i - 1).toLowerCase() + input.slice(i - 1);
  } catch (ex) {
    console.error(
      `FAILED TO CAMELIZE: ${input}, typeof input = ${typeof input}`,
      ex,
    );
    return input;
  }
}

const reservedRescriptWords = [
  "type",
  "open",
  "as",
  "constraint",
  "external",
  "module",
  "when",
];
const validVariantConstructorNameRegexp = /[^a-zA-Z0-9_]/g;

function getFieldName(property: Browser.Property): string {
  const fieldName = property.name;
  const mutable = property.readonly ? "" : " mutable ";
  if (reservedRescriptWords.includes(fieldName)) {
    return `@as("${fieldName}")${mutable} ${fieldName}_`;
  } else if (fieldName && fieldName[0] !== fieldName[0].toLowerCase()) {
    return `@as("${fieldName}")${mutable} ${fieldName[0].toLowerCase()}${fieldName.slice(1)}`;
  }

  return `${mutable}${fieldName}`;
}

function getVariantName(variantRawName: string): string {
  let legalName = `${variantRawName[0].toUpperCase()}${variantRawName.slice(1)}`;
  let firstChar = legalName[0];

  if (!isNaN(parseFloat(firstChar))) {
    legalName = `V${legalName}`;
  }

  legalName = legalName
    .split("-")
    .map((s) => s[0].toUpperCase() + s.slice(1))
    .join("");

  legalName = legalName.replace(validVariantConstructorNameRegexp, "");

  if (variantRawName !== legalName) {
    return `@as("${variantRawName}") ${legalName}`;
  }

  return variantRawName;
}

// Extend clauses can look like `Sometype<SomeOtherType>`. We need to extract `SomeOtherType` from the string.
function parseExtendsClause(extendsClause: string): string[] {
  // Match base type and any type parameters
  const match = extendsClause.match(/^([a-zA-Z0-9_]+)(<([a-zA-Z0-9_<>]+)>)?/);
  if (match) {
    const baseType = match[1];
    const typeParams = match[3] ? match[3].split(/,\s*/) : [];
    return [baseType, ...typeParams];
  }
  return [extendsClause];
}

interface Dictionary {
  name: string;
  extends?: string;
}

type DictionaryMap<T extends Dictionary> = { [name: string]: T };

function topologicalSortDictionaries<T extends Dictionary>(
  dictionaries: T[],
): T[] {
  const sorted: T[] = [];
  const visited: Set<string> = new Set();
  const tempMarked: Set<string> = new Set();
  const dictMap: DictionaryMap<T> = Object.fromEntries(
    dictionaries.map((d) => [d.name, d]),
  );

  function visit(dictName: string) {
    if (visited.has(dictName)) return;
    if (tempMarked.has(dictName)) {
      throw new Error(`Cyclic dependency detected with ${dictName}`);
    }

    tempMarked.add(dictName);
    const dict = dictMap[dictName];
    if (dict?.extends) {
      const dependencies = parseExtendsClause(dict.extends);
      dependencies.forEach((dep) => {
        if (dictMap[dep]) {
          visit(dep);
        }
      });
    }
    tempMarked.delete(dictName);
    visited.add(dictName);
    sorted.push(dict);
  }

  dictionaries.forEach((dict) => {
    if (!visited.has(dict.name)) {
      visit(dict.name);
    }
  });

  return sorted;
}

type interfaceSettings = {
  allowSpreading: boolean;
  typeKeywords: "type" | "type rec" | "and";
};

const currentFileName = fileURLToPath(import.meta.url);
const currentDir = path.dirname(currentFileName);
const repoRoot = path.resolve(currentDir, "..", "..", "..", "..");
const outputFolder = path.join(repoRoot, "tmp");

export async function emitRescriptBindings(webidl: Browser.WebIdl) {
  // Global print target
  const printer = createTextWriter("\n");

  const allInterfaces = getElements(webidl.interfaces, "interface").concat(
    getElements(webidl.callbackInterfaces, "interface"),
    getElements(webidl.mixins, "mixin"),
  );

  const allDictionaries = getElements(webidl.dictionaries, "dictionary");

  const allEnums = getElements(webidl.enums, "enum");

  const allCallbacks = getElements(
    webidl.callbackFunctions,
    "callbackFunction",
  );

  const allMixins = getElements(webidl.mixins, "mixin");

  const allTypeDefs = webidl.typedefs?.typedef || [];

  function compareName(c1: { name: string }, c2: { name: string }) {
    return c1.name < c2.name ? -1 : c1.name > c2.name ? 1 : 0;
  }

  function printComment({
    mdnUrl,
    comment,
    name,
  }: {
    mdnUrl?: string;
    comment?: string;
    name?: string;
  }) {
    let linkText = name ? `See ${name} on MDN` : "Read more on MDN";
    if (comment || mdnUrl) {
      printer.printLine(`/**`);
      if (comment) printer.printLine(comment);
      if (mdnUrl) printer.printLine(`[${linkText}](${mdnUrl})`);
      printer.printLine(`*/`);
    }
  }

  // Track all items we've seen so we can look up things from them
  const seenItems = new Map<string, Browser.Interface | Browser.Dictionary>();

  // These are types that take a generic parameter but it could not be mentioned in the type definition.
  // In this case, we need to produce a type with a default generic parameter <unit>.
  const alwaysGenericTypes = new Set<string>([
    "QueuingStrategy",
    "ReadableStream",
    "WritableStream",
    "IDBRequest",
  ]);

  function transformExtends(extds: string) {
    const hasTypeParams = extds.includes("<");
    const entry = seenItems.get(extds);

    // Insert default type parameters
    if (entry?.typeParameters && !hasTypeParams) {
      return (
        toCamelCase(extds) +
        "<" +
        entry.typeParameters
          .map((t) => `${t.default ?? toCamelCase(t.name)}`)
          .join(", ") +
        ">"
      );
    }

    if (alwaysGenericTypes.has(extds)) {
      return toCamelCase(extds) + "<unit>";
    }

    return extds.split("<").map(toCamelCase).join("<");
  }

  function extractExtendsName(
    i: Browser.Interface | Browser.Dictionary,
  ): string | null {
    return i.extends?.split("<")[0] || null;
  }

  function collectExtendsProperties(
    current: Browser.Interface,
  ): Record<string, Browser.Property[]> {
    function collectExtendsPropertiesFrom(
      entry: Browser.Interface,
    ): Browser.Property[] {
      const props = (<any>entry).properties?.property || {};
      const currentProps = Object.keys(props).map((p) => props[p]);
      return currentProps;
    }

    function findBaseInterfaces(name: string): Browser.Interface[] {
      const entry = allInterfaces.find((i) => i.name === name);
      if (!entry) return [];

      const extendsName = extractExtendsName(entry);

      return [entry, ...(extendsName ? findBaseInterfaces(extendsName) : [])];
    }

    const extendsName = extractExtendsName(current);
    if (!extendsName) return {};

    const interfaces = findBaseInterfaces(extendsName);
    return Object.fromEntries(
      interfaces.map((i) => [i.name, collectExtendsPropertiesFrom(i)]),
    );
  }

  function mapTypeParams(
    typeParameters: Browser.TypeParameter[] | undefined,
  ): string {
    if (!typeParameters) return "";
    return (
      "<" +
      typeParameters.map((tp) => `'${toCamelCase(tp.name)}`).join(", ") +
      ">"
    );
  }

  function mapInterfaceName(i: Browser.Interface) {
    return toCamelCase(i.name) + mapTypeParams(i.typeParameters);
  }

  function printTypeParams(
    typeParameters: Browser.TypeParameter[] | undefined,
  ) {
    let hasTypeParams = false;
    typeParameters?.forEach((t) => {
      if (!hasTypeParams) {
        hasTypeParams = true;
        printer.print("<");
      } else {
        printer.print(", ");
      }
      printer.print(`'${toCamelCase(t.name)}`);
    });
    if (hasTypeParams) {
      printer.print(">");
    }
  }

  // Track field names so we can avoid reprinting fields we've already covered by a spread
  const typeFieldNames = new Map<string, Set<string>>();

  function mapTypeToReScript(typeName: string): string {
    switch (typeName) {
      case "undefined":
        return "unit";
      case "boolean":
      case "ConstrainBoolean":
        return "bool";

      // Not sure if this is correct
      case "number":
      case "unsigned short":
      case "long":
      case "unsigned long long":
      case "unsigned long":
      case "long long":
      case "SVGAnimatedNumber":
      case "EpochTimeStamp":
      case "short":
      // TODO: model https://developer.mozilla.org/en-US/docs/Web/API/FileReader/readyState
      case "typeof FileReader.EMPTY | typeof FileReader.LOADING | typeof FileReader.DONE":
      // TODO: https://developer.mozilla.org/en-US/docs/Web/API/ByteLengthQueuingStrategy/size
      case "QueuingStrategySize":
      case "ConstrainULong":
      case "COSEAlgorithmIdentifier":
        return "int";

      case "double":
      case "CSSNumberish":
      case "GLint":
      case "GLsizei":
      case "DOMHighResTimeStamp":
      case "ConstrainDouble":
      case "unrestricted double":
        return "float";

      // TODO: represent this as a variant type
      case "HTMLOrSVGScriptElement":
        return "htmlElement";

      // TODO: have a better representation for this
      // See https://developer.mozilla.org/en-US/docs/Web/API/ClipboardItem/types
      case "FrozenArray":
      case "ObservableArray":
      case "sequence":
        return "array";

      case "Uint8ClampedArray":
        return "array<int>";

      case "ClipboardItems":
        return "array<clipboardItem>";

      case "Promise":
        return "promise";

      case "ArrayBuffer":
        return "ArrayBuffer.t";

      // TODO: this isn't entirely accurate
      // Could also be https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray
      // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer/isView
      case "ArrayBufferView":
        return "DataView.t";

      case "WindowProxy":
      case "WindowProxy & typeof globalThis":
      case "Window & typeof globalThis":
        return "window";

      // https://developer.mozilla.org/en-US/docs/Web/API/CSSAnimation/animationName
      case "CSSOMString":
      case "ByteString":
      case "GLenum":
      case "DOMString":
      case "ConstrainDOMString":
      case "USVString":
      case "`${string}-${string}-${string}-${string}-${string}`":
        return "string";

      case "record":
        return "any";

      case "Date":
        return "Date.t";

      case "Uint8Array":
        return "array<int>";

      case "ParentNode":
      case "ChildNode":
        return "node";

      // TODO: https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/decoding
      case '"async" | "sync" | "auto"':
        return "string";

      // TODO: https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/loading
      case '"eager" | "lazy"':
        return "string";

      // TODO: https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/preload
      case '"none" | "metadata" | "auto" | ""':
        return "string";

      // TODO: this is wrong
      case "HTMLCollectionOf<HTMLAnchorElement | HTMLAreaElement>":
        return "htmlCollectionOf<htmlElement>";

      // TODO: model better https://developer.mozilla.org/en-US/docs/Web/API/HTMLButtonElement/type
      case '"submit" | "reset" | "button"':
        return "string";

      // TODO: model better https://developer.mozilla.org/en-US/docs/Web/API/HTMLSelectElement/type
      case '"select-one" | "select-multiple"':
        return "string";

      // https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/selectionDirection
      case '"forward" | "backward" | "none"':
        return "string";

      // https://developer.mozilla.org/en-US/docs/Web/API/DataTransfer/dropEffect
      case '"none" | "copy" | "link" | "move"':
        return "string";

      // https://developer.mozilla.org/en-US/docs/Web/API/DataTransfer/effectAllowed
      case '"none" | "copy" | "copyLink" | "copyMove" | "link" | "linkMove" | "move" | "':
        return "string";

      // https://developer.mozilla.org/en-US/docs/Web/API/DataTransfer/effectAllowed
      case '"none" | "copy" | "copyLink" | "copyMove" | "link" | "linkMove" | "move" | "all" | "uninitialized"':
        return "string";

      // "\"attributes\" | \"characterData\" | \"childList\""
      case "MutationRecordType":
        return "string";

      case "string | string[]":
        return "string";

      // https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/autocomplete
      case "AutoFill":
        return "string";

      case "object":
      case "Exports":
        return "Dict.t<string>";

      case "Float32Array":
        return "array<float>";

      case "RTCRtpTransform":
        return "rtcRtpScriptTransform";

      case "null":
        return "Null.t<unit>";

      case "Function":
        return "(unit => unit)";

      case "any":
        return "JSON.t";

      case "EventListenerOrEventListenerObject":
        return "eventListener<'event>";

      default:
        // TODO: some types are a inline variant type
        // Example: "IDBValidKey | IDBKeyRange"
        if (typeName.includes(" | ")) {
          return "any";
        }

        if (typeName.endsWith("[]")) {
          return `array<${mapTypeToReScript(typeName.slice(0, -2))}>`;
        }

        return toCamelCase(typeName);
    }
  }

  function parseGenericType(input: string) {
    const regex = /^(\w+)<(.+)>$/;
    const match = input.match(regex);

    if (!match) return null; // Return null if input doesn't match the expected pattern with < and >

    const typeName = match[1];
    const genericParameters = match[2].split(/\s*,\s*/);

    return {
      typeName,
      genericParameters,
    };
  }

  function transformTyped(typed: Browser.Typed): string {
    if (Array.isArray(typed.type) && typed.type.length === 1) {
      return transformTyped(typed.type[0]);
    }

    if (typeof typed.type !== "string") {
      // console.log("Unknown type", typed.type);
      return "unknown";
    }

    if (typed.overrideType === "T" && typed.type === "any") {
      return "'t";
    }

    if (
      typed.subtype &&
      !Array.isArray(typed.subtype) &&
      typeof typed.subtype.type === "string"
    ) {
      return `${mapTypeToReScript(typed.type)}<${transformTyped(typed.subtype)}>`;
    }

    // Model as Undefined.t<'other>
    if (
      typed.subtype &&
      !Array.isArray(typed.subtype) &&
      Array.isArray(typed.subtype.type) &&
      typed.subtype.type.length === 2 &&
      typed.subtype.type.some((t) => t.type === "undefined")
    ) {
      const otherType = typed.subtype.type.find((t) => t.type !== "undefined")!;
      return `Nullable.t<${transformTyped(otherType)}>`;
    }

    let t = typed.type;
    if (typeof typed.overrideType === "string") {
      t = typed.overrideType;
    }

    if (Array.isArray(typed.overrideType)) {
      t = typed.overrideType[0];
    }

    if (t === "QueuingStrategySize<ArrayBufferView>") {
      return "int";
    }

    if (alwaysGenericTypes.has(t)) {
      return `${mapTypeToReScript(t)}<unit>`;
    }

    const genericType = parseGenericType(t);
    if (genericType) {
      // TODO: exclude is one of those weird TypeScript things were they subtract properties from types.
      if (genericType.typeName === "Exclude") {
        return "any";
      }

      const ps = genericType.genericParameters
        .map((p) => {
          if (p.length === 1) {
            return `'${p.toLocaleLowerCase()}`;
          }
          return mapTypeToReScript(p);
        })
        .join(", ");
      return `${mapTypeToReScript(genericType.typeName)}<${ps}>`;
    }

    return mapTypeToReScript(t);
  }

  function transformPropertyValue(
    i: Browser.Interface | Browser.Dictionary,
    property: Browser.Member,
  ): string {
    if (
      typeof property.type === "string" &&
      i.name === "Event" &&
      property.name === "type"
    ) {
      return "eventType";
    }

    return transformTyped(property);
  }

  function emitProperty(i: Browser.Interface, property: Browser.Property) {
    if (!("mdnUrl" in property)) return;

    printComment({
      mdnUrl: property.mdnUrl,
      comment: property.comment,
    });
    let propertyValue = transformPropertyValue(i, property);
    printer.print(`${getFieldName(property)}`);
    if (property.optional) printer.print(`?`);
    printer.print(`: `);
    if (property.nullable) printer.print(`Null.t<${propertyValue}>`);
    else printer.print(propertyValue);
    printer.printLine(`,`);
  }

  // TODO: This and emitInterfaceRecord should share most of the logic at some point
  function emitDictionaryRecord(i: Browser.Dictionary) {
    seenItems.set(i.name, i);
    const fieldNamesFromExtended = i.extends
      ? Array.from(typeFieldNames.get(i.extends.split("<")[0])?.values() ?? [])
      : [];
    const typename = toCamelCase(i.name);
    printer.print(
      `type ${typename}${reservedRescriptWords.includes(typename) ? "_" : ""}`,
    );
    printTypeParams(i.typeParameters);
    printer.printLine(` = {`);
    printer.increaseIndent();

    if (i.extends) {
      printer.printLine(`...${transformExtends(i.extends)},`);
    }

    if (i.members.member) {
      for (const key of Object.keys(i.members.member)) {
        if (fieldNamesFromExtended.includes(key)) continue;
        let property = i.members.member[key];
        printComment({ comment: property.comment });
        let propertyValue = transformPropertyValue(i, property);
        printer.print(`${getFieldName(property)}`);
        if (!property.required) {
          printer.print(`?`);
        }
        printer.print(`: `);
        if (property.nullable) printer.print(`Null.t<${propertyValue}>`);
        else printer.print(propertyValue);
        printer.printLine(`,`);
      }
    }

    const fieldNames = new Set([
      ...Object.keys(i.members.member ?? []),
      ...fieldNamesFromExtended,
    ]);
    typeFieldNames.set(i.name, fieldNames);

    printer.decreaseIndent();
    printer.printLine("}");
    printer.endLine();
  }

  // TODO: some interface seems to have an "implements" property.
  // These properties and methods should also be included.

  function collectAllProperties(i: Browser.Interface): Browser.Property[] {
    const allProperties: Browser.Property[] = Object.values(
      i.properties?.property ?? {},
    );

    for (const mixinName of i.implements ?? []) {
      const mixin = allMixins.find((m) => m.name === mixinName);
      if (mixin) {
        allProperties.push(...Object.values(mixin.properties?.property ?? {}));
      }
    }

    return allProperties;
  }

  function emitInterfaceRecord(
    options: interfaceSettings,
    i: Browser.Interface,
  ) {
    seenItems.set(i.name, i);
    const fieldNamesFromExtended = i.extends
      ? Array.from(typeFieldNames.get(i.extends.split("<")[0])?.values() ?? [])
      : [];
    const typename = toCamelCase(i.name);
    printComment({ name: i.name, mdnUrl: i.mdnUrl, comment: i.comment });
    printer.print(
      `${options.typeKeywords} ${typename}${reservedRescriptWords.includes(typename) ? "_" : ""}`,
    );
    printTypeParams(i.typeParameters);
    printer.printLine(` = {`);
    printer.increaseIndent();

    // TODO: what to do with error?
    if (i.extends && i.extends !== "Error") {
      if (options.allowSpreading) {
        printer.printLine(`...${transformExtends(i.extends)},`);
      } else {
        const baseProperties = collectExtendsProperties(i);
        Object.entries(baseProperties).forEach(([name, properties]) => {
          if (properties.length !== 0) {
            printer.printLine(`// Base properties from ${name}`);
            properties
              .filter((p) => !p.eventHandler)
              .forEach((p) => {
                emitProperty(i, p);
              });
            printer.printLine(`// End base properties from ${name}`);
            printer.endLine();
          }
        });
      }
    }

    const allProperties: Browser.Property[] = collectAllProperties(i);

    for (const property of allProperties) {
      // I'm curious to know which properties are overwritten in the extended interface
      if (fieldNamesFromExtended.includes(property.name)) {
        console.log(`skipping ${i.name}.${property.name}, mdn: ${i.mdnUrl}`);
      }

      if (
        fieldNamesFromExtended.includes(property.name) ||
        property.deprecated ||
        property.eventHandler
      )
        continue;

      emitProperty(i, property);
    }

    const fieldNames = new Set([
      ...Object.keys(i.properties?.property ?? []),
      ...fieldNamesFromExtended,
    ]);
    typeFieldNames.set(i.name, fieldNames);

    printer.decreaseIndent();
    printer.printLine("}");
    printer.endLine();
  }

  // method is quite empty for the forEach method.
  // This occurs for NodeList and NodeListOf
  function emitForEachMethod(i: Browser.Interface, method: Browser.Method) {
    const itemType = i.typeParameters ? "'tNode" : "node";

    printComment({
      mdnUrl: method.mdnUrl,
      comment: method.comment,
    });
    printer.printLine("@send");
    printer.printLine(
      `external forEach: (${mapInterfaceName(i)}, (${itemType} => int => ${mapInterfaceName(i)} => unit)) => unit = "forEach"`,
    );
    printer.endLine();
  }

  function mapMethodName(method: Browser.Method, suffix: string = "") {
    if (reservedRescriptWords.includes(method.name) && !suffix) {
      return `${method.name}_`;
    }

    return `${method.name}${suffix}`;
  }

  function mapMethodReturnType(signature: Browser.Signature) {
    const genericTypeParams = new Set(
      (signature.typeParameters || []).map((tp) => tp.name),
    );

    if (
      signature.overrideType &&
      genericTypeParams.has(signature.overrideType)
    ) {
      const t = transformTyped(signature);
      return t.startsWith("'") ? t : `'${t}`;
    }

    return transformTyped(signature);
  }

  function isInvalidMethod(method: Browser.Method): boolean {
    if (!method.signature || method.signature.length === 0 || method.deprecated)
      return true;

    const signature = method.signature[0];
    if (typeof signature.type !== "string") return true;

    return false;
  }

  // Some methods like https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView have multiple overloads
  // This is defined as an parameter with multiple type
  /*
      "scrollIntoView": {
              "name": "scrollIntoView",
              "signature": [
                {
                  "type": "undefined",
                  "nullable": false,
                  "param": [
                    {
                      "name": "arg",
                      "type": [
                        {
                          "type": "boolean",
                          "nullable": false
                        },
                        {
                          "type": "ScrollIntoViewOptions",
                          "nullable": false
                        }
                      ],
                      "nullable": false,
                      "optional": true,
                      "variadic": false
                    }
                  ]
                }
              ],
  */

  function dedubeTypeIfTypeDef(typed: Browser.Typed): Browser.Typed[] {
    const typeDef = allTypeDefs.find((td) => {
      return td.name === typed.type;
    });

    if (typeDef && Array.isArray(typeDef.type)) {
      return typeDef.type.flatMap((tdt) => dedubeTypeIfTypeDef(tdt));
    }

    return [typed];
  }

  function dedupeSignature(signature: Browser.Signature): Browser.Signature[] {
    const param = signature.param;

    if (param === undefined) {
      return [signature];
    }

    const parametersWithMultipleTypes = param
      .map((p, idx) => {
        const typedef = allTypeDefs.find((t) => t.name === p.type);
        return { p, idx, typedef };
      })
      .filter(({ p, typedef }) => {
        return (
          (Array.isArray(p.type) && p.type.length > 1) ||
          (typedef && Array.isArray(typedef.type))
        );
      });

    // If a single parameter has multiple types, we need to create a signature for each type.
    // TODO: This could in theory happen for multiple parameters...
    if (parametersWithMultipleTypes.length === 1) {
      const { p, idx, typedef } = parametersWithMultipleTypes[0];
      let types = typedef?.type || p.type;
      if (Array.isArray(types)) {
        // Interestly enough each type could also be a typedef
        types = types.flatMap(dedubeTypeIfTypeDef);

        return types.map((t) => {
          const updatedParams = param.map((p, i) => {
            return i !== idx ? p : { ...p, type: [t] };
          });
          return { ...signature, param: updatedParams };
        });
      }
    }

    // Example case: HTMLCanvasElement->getContext
    const returnTypeWithMultipleTypes = allTypeDefs.find(
      (t) => t.name === signature.type,
    );
    if (
      returnTypeWithMultipleTypes &&
      Array.isArray(returnTypeWithMultipleTypes.type) &&
      !signature.overrideType
    ) {
      return returnTypeWithMultipleTypes.type.map((t) => {
        return { ...signature, type: t.type };
      });
    }

    return [signature];
  }

  function dedupeMethod(method: Browser.Method): Browser.Method[] {
    if (isInvalidMethod(method)) return [];

    if (method.static) {
      return [method];
    }

    return method.signature.flatMap((signature) => {
      return dedupeSignature(signature).map((s) => {
        return { ...method, signature: [s] };
      });
    });
  }

  function dedupeConstructor(
    constructor: Browser.Constructor,
  ): Browser.Constructor[] {
    if (!constructor.signature || !Array.isArray(constructor.signature)) {
      return [];
    }

    return constructor.signature.flatMap((signature) => {
      const dedupeSignatures = dedupeSignature(signature);
      return dedupeSignatures.map((signature) => {
        return { ...constructor, signature: [signature] };
      });
    });
  }

  // TODO: deal with overloads?
  function emitMethod(
    i: Browser.Interface,
    method: Browser.Method,
    suffix: string = "",
  ) {
    if (isInvalidMethod(method)) return;

    const signature = method.signature[0];

    let ps = mapSignatureParameters(method.name, signature);

    printComment({
      mdnUrl: method.mdnUrl,
      comment: method.comment,
    });
    if (method.static) {
      printer.printLine(`@scope("${i.name}")`);
      printer.printLine(
        `external ${mapMethodName(method, suffix)}: (${ps}) => ${mapMethodReturnType(signature)} = "${method.name}"`,
      );
    } else {
      ps = ps.length > 0 ? ", " + ps : "";

      printer.printLine("@send");
      printer.printLine(
        `external ${mapMethodName(method, suffix)}: (${mapInterfaceName(i)}${ps}) => ${mapMethodReturnType(signature)} = "${method.name}"`,
      );
    }

    printer.endLine();
  }

  // TODO: consider dealing with variadic parameters
  function mapSignatureParameters(
    owner: string,
    signature: Browser.Signature,
    join: string = ", ",
    includeParameterNames: boolean = true,
  ): string {
    const genericTypeParams = new Set(
      (signature.typeParameters || []).map((tp) => tp.name),
    );

    // Avoids the additional parameters for setTimeout and setInterval
    const parameters = (signature.param || []).filter(
      (p) => !(p.variadic && p.type === "any"),
    );

    return parameters.length === 0
      ? ""
      : parameters
          .map((p) => {
            if (p.overrideType && genericTypeParams.has(p.overrideType)) {
              return `'${toCamelCase(p.overrideType)}`;
            }

            let t = transformTyped(p);

            if (owner === "addEventListener" && p.name === "type") {
              return "~type_: eventType";
            }

            if (owner === "removeEventListener" && p.name === "type") {
              return "~type_: eventType";
            }

            if (owner.startsWith("roundRect") && p.name === "radii") {
              return "~radii_: array<float>=?";
            }

            if (!includeParameterNames) {
              return t;
            }

            let name = "";
            if (
              (p.name && p.optional) ||
              (p.name !== "arg" && parameters.length > 1)
            ) {
              name = p.name.endsWith("Arg")
                ? p.name.replace("Arg", "")
                : p.name;
              name = reservedRescriptWords.includes(name)
                ? `~${name}_: `
                : `~${name}: `;
            }

            const isOptional = p.optional ? "=?" : "";
            return `${name}${t}${isOptional}`;
          })
          .join(join);
  }

  // TODO: add support for multiple constructors
  /*
        "constructor": {
          "signature": [
            {
              "type": "MediaStream",
              "param": []
            },
            {
              "type": "MediaStream",
              "param": [
                {
                  "name": "stream",
                  "type": "MediaStream",
                  "nullable": false,
                  "optional": false,
                  "variadic": false
                }
              ]
            },
            {
              "type": "MediaStream",
              "param": [
                {
                  "name": "tracks",
                  "type": "sequence",
                  "subtype": {
                    "type": "MediaStreamTrack",
                    "nullable": false
                  },
                  "nullable": false,
                  "optional": false,
                  "variadic": false
                }
              ]
            }
          ]
        },
  */

  function emitConstructor(
    i: Browser.Interface,
    c: Browser.Constructor,
    suffix: string = "",
  ) {
    if (typeof c === "function") {
      return;
    }

    const signature = c.signature[0];
    let ps = mapSignatureParameters(`${i.name} ctor`, signature);

    if (i.name === "ReadableStream") {
      ps = "";
    }

    printComment({
      mdnUrl: i.mdnUrl,
      comment: c.comment,
    });

    printer.printLine(`@new`);
    printer.printLine(
      `external make${suffix}: (${ps}) => ${transformTyped(signature)} = "${i.name}"`,
    );
    printer.endLine();
  }

  type MethodWithSource = Browser.Method & { source: string };

  function extractMethodEntries(i: Browser.Interface): MethodWithSource[] {
    // Own methods
    let methodEntries: MethodWithSource[] =
      i.methods && i.methods.method
        ? Object.values(i.methods.method).map((m) => ({ ...m, source: i.name }))
        : [];

    // Mixin methods
    let mixinMethods = (i.implements || []).flatMap((i) => {
      const method = allMixins.find((m) => m.name === i)?.methods?.method || {};
      return Object.values(method).map((m) => ({ ...m, source: i }));
    });

    // Inherit methods from extended interfaces
    let extendedMethods: MethodWithSource[] = [];
    if (i.extends && typeof i.extends === "string") {
      let entry = allInterfaces.find((j) => j.name === i.extends);
      if (entry) {
        extendedMethods = extractMethodEntries(entry);
      }
    }

    // Combine all methods
    const allMethods: MethodWithSource[] = [
      ...mixinMethods,
      ...extendedMethods,
      ...methodEntries,
    ];

    return allMethods.filter((m) => !m.deprecated && !isInvalidMethod(m));
  }

  // We try and detect which open statements are required for the functions of a nested module.
  function findOpensForNestedModules(
    i: Browser.Interface,
    typesToModule: Map<string, string>,
  ): Set<string> {
    const opens = new Set<string>();

    function addModuleForType(typed: Browser.Typed) {
      function addIfFound(typeName: string) {
        const moduleName = typesToModule.get(typeName);
        if (moduleName) {
          opens.add(moduleName);
        }
      }

      if (typeof typed.type === "string") {
        addIfFound(typed.type);
      } else {
        typed.type.forEach(addModuleForType);
      }

      if (typed.subtype) {
        if (Array.isArray(typed.subtype)) {
          typed.subtype.forEach(addModuleForType);
        } else {
          addModuleForType(typed.subtype);
        }
      }

      // In case of "any"
      addIfFound(transformTyped(typed));
    }

    function verifyTypesFromSignature(
      functionName: string,
      isStatic: boolean,
      signature: Browser.Signature,
    ) {
      if (typeof signature.type !== "string") return;

      addModuleForType(signature);

      (signature.param || []).forEach(addModuleForType);

      if (!isStatic) {
        const moduleName = typesToModule.get(i.name);
        if (moduleName) {
          opens.add(moduleName);
        } else {
          console.log(
            `No module found for sender ${i.name} in ${functionName}`,
          );
        }
      }
    }

    const methodEntries = extractMethodEntries(i);
    for (const method of methodEntries) {
      for (const dedupedMethod of dedupeMethod(method)) {
        const signature = dedupedMethod.signature[0];
        verifyTypesFromSignature(
          dedupedMethod.name,
          dedupedMethod.static || false,
          signature,
        );
      }
    }

    if (
      i.constructor &&
      typeof i.constructor !== "function" &&
      i.constructor.signature.length > 0
    ) {
      for (const dedupedConstructor of dedupeConstructor(i.constructor)) {
        verifyTypesFromSignature(
          "constructor",
          false,
          dedupedConstructor.signature[0],
        );
      }
    }

    // "forEach" edge case
    if (i.name === "NodeListOf") {
      opens.add("DOMAPI");
    }

    return opens;
  }

  /// You can't do something like `new HTMLInputElement()` but TypeScript does include a constructor for these types.
  function isHTMLElement(i: Browser.Interface) {
    return i.name && i.name.startsWith("HTML") && i.name.endsWith("Element");
  }

  function emitCastToBaseInterfaceMethods(
    initialInterface: Browser.Interface,
    currentInterface: Browser.Interface,
  ) {
    if (
      !currentInterface.extends ||
      typeof currentInterface.extends !== "string"
    )
      return;

    const baseInterface = allInterfaces.find(
      (j) => j.name === currentInterface.extends,
    );
    if (!baseInterface) return;

    printer.printLine(
      `external as${baseInterface.name}: ${mapInterfaceName(initialInterface)} => ${mapInterfaceName(
        baseInterface,
      )} = "%identity"`,
    );
    emitCastToBaseInterfaceMethods(initialInterface, baseInterface);
  }

  // TODO: add constructor fn and cast fn
  // TODO: include methods of "implements" mixins

  function emitInterfaceFunctionsModule(
    opens: Set<string>,
    i: Browser.Interface,
  ) {
    const hasMethods = i.methods && Object.keys(i.methods.method).length > 0;
    const hasConstructor = i.constructor || false;
    if (!(hasMethods || hasConstructor)) return;

    if (opens.size > 0) {
      for (const open of opens) {
        printer.printLine(`open ${open}`);
      }
      printer.endLine();
    }

    if (i.constructor && !isHTMLElement(i)) {
      const dedupedConstructors = dedupeConstructor(i.constructor);
      for (const [idx, dedupedConstructor] of dedupedConstructors.entries()) {
        const suffix = idx > 0 ? `${idx + 1}` : "";
        emitConstructor(i, dedupedConstructor, suffix);
      }
    }

    emitCastToBaseInterfaceMethods(i, i);

    let methodEntries: MethodWithSource[] = extractMethodEntries(i);
    const seen = new Set<string>();

    for (const method of methodEntries) {
      // if (!method.name && key === "forEach") {
      //   emitForEachMethod(i, method);
      //   continue;
      // }

      if (method.signature) {
        let suffix = seen.has(method.name)
          ? method.source[0].toUpperCase()
          : "";
        const dedupedMethods = dedupeMethod(method);
        for (const [idx, dedupedMethod] of dedupedMethods.entries()) {
          const methodSuffix = idx > 0 ? `${suffix}${idx + 1}` : suffix;
          emitMethod(i, dedupedMethod, methodSuffix);
        }
        seen.add(method.name);
      }
    }
  }

  function emitEnum(e: Browser.Enum) {
    const values = e.value.slice().sort();
    printer.printLine(`type ${toCamelCase(e.name)} =`);
    values.forEach((v) => {
      if (v !== "") printer.printLine(`  | ${getVariantName(v)}`);
    });
    printer.printLine("");
  }

  function emitCallback(c: Browser.CallbackFunction) {
    if (c.signature.length === 0) return;

    const signature = c.signature[0];

    let ps = mapSignatureParameters(c.name, signature, " => ", false);
    ps = ps && `${ps} => `;

    printer.printLine(
      `type ${toCamelCase(c.name)} = (${ps}${transformTyped(signature)})`,
    );
    printer.endLine();
  }

  function emitEnums() {
    getElements(webidl.enums, "enum")
      .sort(compareName)
      .filter((i) => !i.legacyNamespace)
      .forEach(emitEnum);
  }

  function emitDictionaries() {
    const dicts = getElements(webidl.dictionaries, "dictionary")
      .sort(compareName)
      .filter((i) => !i.legacyNamespace);

    const sortedDicts = topologicalSortDictionaries(dicts);

    sortedDicts.forEach(emitDictionaryRecord);
  }

  function emitEventType() {
    let globalEventHandlers = webidl.mixins?.mixin["GlobalEventHandlers"];
    if (globalEventHandlers) {
      let properties = globalEventHandlers.properties?.property || {};
      const keys = Object.keys(properties);
      if (keys.length > 0) {
        printer.printLine("@unboxed");
        printer.printLine("type eventType =");
        printer.increaseIndent();
        for (const key of Object.keys(properties)) {
          const property = properties[key];
          const eventName = property.eventHandler;
          if (eventName) {
            printer.printLine(`| ${getVariantName(eventName)}`);
          }
        }
        printer.printLine("| Custom(string)");
        printer.decreaseIndent();
        printer.endLine();
      }
    }
  }

  // Make event handlers just generic functions
  function emitEventListener() {
    printer.printLine("type eventListener<'event> = 'event => unit");
    printer.endLine();
  }

  function emitEventPhase() {
    printer.printLine("type eventPhase  =");
    printer.increaseIndent();
    printer.printLine("| @as(0) NONE");
    printer.printLine("| @as(1) CAPTURING_PHASE");
    printer.printLine("| @as(2) AT_TARGET");
    printer.printLine("| @as(3) BUBBLING_PHASE");
    printer.decreaseIndent();
    printer.endLine();
  }

  function emitQueuingStrategy() {
    printer.printLine("type queuingStrategy<'t> = {}");
  }

  function emitIndividualInterfaces(items: Browser.Interface[]) {
    for (const i of items) {
      emitInterfaceRecord({ allowSpreading: true, typeKeywords: "type" }, i);
    }
  }

  function emitInterfaceChain(names: Set<string>, chain: Browser.Interface[]) {
    for (const [idx, i] of chain.entries()) {
      const e = i.extends?.split("<")[0] || "";
      emitInterfaceRecord(
        {
          allowSpreading: !names.has(e),
          typeKeywords: idx === 0 ? "type rec" : "and",
        },
        i,
      );
      // TODO: construct a %identity function to convert to the base interface?
      // Or perhaps this happens in a separate file/module?
    }
  }

  function emitMediaImage() {
    printer.printLine("type mediaImage = {");
    printer.increaseIndent();
    printer.printLine("src: string,");
    printer.printLine("sizes?: string,");
    printer.printLine('@as("type") type_?: string,');
    printer.decreaseIndent();
    printer.printLine("}");
  }

  function emitBlobPart() {
    printer.printLine("@unboxed");
    printer.printLine("type blobPart =");
    printer.increaseIndent();
    printer.printLine("| String(string)");
    printer.printLine("| Blob(blob)");
    printer.printLine("// | ArrayBuffer(ArrayBuffer.t)");
    printer.printLine("// | TypedArray(TypedArray.t<int>)");
    printer.decreaseIndent();
    printer.endLine();
  }

  // TODO: this function is defined in typedefs
  // we should try and parse this similar to callback functions
  // and emit a unboxed type (if it has all primitves of course)

  // the context here is https://developer.mozilla.org/en-US/docs/Web/API/Navigator/vibrate
  // it might also make sense to just emit an overload for Navigator.vibrate
  function emitVibratePattern() {
    printer.printLine("@unboxed");
    printer.printLine("type vibratePattern =");
    printer.increaseIndent();
    printer.printLine("| Int(int)");
    printer.printLine("| IntArray(array<int>)");
    printer.decreaseIndent();
    printer.endLine();
  }

  function emitAny(name: string) {
    return () => {
      printer.printLine(`type ${toCamelCase(name)} = any`);
      printer.endLine();
    };
  }

  function emitOpens(opens: string[]) {
    if (opens.length > 0) {
      printer.endLine();
    }
    for (const o of opens) {
      printer.printLine(`open ${o}`);
    }
    if (opens.length > 0) {
      printer.endLine();
    }
  }

  async function emitGlobalModule() {
    printer.reset();
    const opens = [
      "DOMAPI",
      "HistoryAPI",
      "VisualViewportAPI",
      "WebSpeechAPI",
      "IndexedDBAPI",
      "WebCryptoAPI",
      "PerformanceAPI",
      "ServiceWorkerAPI",
      "WebStorageAPI",
      "CanvasAPI",
      "FileAPI",
      "ChannelMessagingAPI",
      "FetchAPI",
      "EventAPI",
    ];
    for (const o of opens) {
      printer.printLine(`open ${o}`);
    }
    printer.endLine();

    const windowInterface = allInterfaces.find((i) => i.name === "Window");
    if (!windowInterface) throw new Error("Window interface not found");

    const allProperties: Browser.Property[] =
      collectAllProperties(windowInterface);
    for (const property of allProperties) {
      if (property.name.startsWith("on") || property.deprecated) {
        continue;
      }

      const name = reservedRescriptWords.includes(property.name)
        ? `${property.name}_`
        : property.name;

      printComment({
        mdnUrl: property.mdnUrl,
        comment: property.comment,
      });
      printer.printLine(
        `external ${name}: ${transformPropertyValue(windowInterface, property)} = "${property.name}"`,
      );
      printer.endLine();
    }

    printer.endLine();

    const allMethods: MethodWithSource[] =
      extractMethodEntries(windowInterface);

    for (const method of allMethods) {
      const dedupedMethods = dedupeMethod(method);
      for (const [idx, dedupedMethod] of dedupedMethods.entries()) {
        // We don't use emitMethod because do not want to include the @send annotation
        const suffix = idx > 0 ? (idx + 1).toString() : "";
        const signature = dedupedMethod.signature[0];
        let ps = mapSignatureParameters(
          dedupeMethod.name,
          dedupedMethod.signature[0],
        );

        printComment({
          mdnUrl: method.mdnUrl,
          comment: method.comment,
        });
        printer.printLine(
          `external ${mapMethodName(method, suffix)}: (${ps}) => ${mapMethodReturnType(signature)} = "${method.name}"`,
        );
        printer.endLine();
      }
    }

    const contents = printer.getResult();
    await fs.writeFile(path.join(outputFolder, `Global.res`), contents);
  }

  async function emit() {
    printer.reset();
    // printer.printLine('@@warning("-30")');
    // printer.printLine("/** Temporary, to be fixed */");
    // printer.printLine("type error = {}");
    // printer.printLine("type any");
    // printer.printLine("type arrayBufferView = {}");
    // printer.printLine("type domHighResTimeStamp");
    // printer.printLine("type usvString");
    // // TODO: "number | string | Date | BufferSource | IDBValidKey[]"
    // printer.printLine("type idbValidKey = unknown");
    // // TODO: https://developer.mozilla.org/en-US/docs/Web/API/CryptoKey/algorithm
    // printer.printLine("type keyAlgorithm = unknown");
    // printer.printLine("type cssPerspectiveValue = unknown");
    // printer.printLine("type arrayBuffer = unknown");
    // // "MediaProvider", // The object can be a MediaStream, a MediaSource, a Blob, or a File (which inherits from Blob).
    // printer.printLine("type mediaProvider = unknown");
    // // https://developer.mozilla.org/en-US/docs/Web/API/MessageEvent/source
    // printer.printLine("type messageEventSource = unknown");
    // // https://developer.mozilla.org/en-US/docs/Web/API/WebTransport/closed
    // printer.printLine("type webTransportCloseInfo = unknown");
    // printer.printLine("type lineAndPositionSetting = unknown");
    // printer.printLine("/* End temporary */");
    // printer.printLine("");

    // emitDictionaries();

    // prim-types-prelude.res => types that need to exist before anything else.

    // emitEnums();

    // emitEventPhase();
    // emitQueuingStrategy();
    // emitMediaImage();

    type IndividualInterfaces = {
      kind: "individuals";
      interfaces: Browser.Interface[];
    };

    type ChainOfInterfaces = {
      kind: "chain";
      interfaces: Browser.Interface[];
      chain: Set<string>;
    };

    type TypeByHand = {
      kind: "byHand";
      name: string;
      emitInterface: () => void;
    };

    type DictionaryEntries = {
      kind: "dictionary";
      dictionaries: Browser.Dictionary[];
    };

    type EnumEntries = {
      kind: "enum";
      enums: Browser.Enum[];
    };

    type GenerationEntry =
      | IndividualInterfaces
      | ChainOfInterfaces
      | TypeByHand
      | DictionaryEntries
      | EnumEntries;

    type RescriptFile = {
      name: string;
      entries: GenerationEntry[];
      opens: string[];
    };

    function individualInterfaces(names: string[]): GenerationEntry {
      const interfaces = names
        .map((name) => {
          const i = allInterfaces.find((i) => i.name === name);
          return i;
        })
        .filter((i) => i !== undefined) as Browser.Interface[];

      return {
        kind: "individuals",
        interfaces: interfaces,
      };
    }

    function chain(names: string[]): GenerationEntry {
      const interfaces = names
        .map((name) => {
          const i = allInterfaces.find((i) => i.name === name);
          return i;
        })
        .filter((i) => i !== undefined) as Browser.Interface[];

      return {
        kind: "chain",
        interfaces,
        chain: new Set(names),
      };
    }

    function byHand(name: string, emitter: () => void): GenerationEntry {
      return {
        name: name,
        kind: "byHand",
        emitInterface: emitter,
      };
    }

    function dictionaries(names: string[]): GenerationEntry {
      const dictionaries = names
        .map((name) => {
          const d = allDictionaries.find((d) => d.name === name);
          return d;
        })
        .filter((i) => i !== undefined) as Browser.Dictionary[];

      return {
        kind: "dictionary",
        dictionaries,
      };
    }

    function enums(names: string[]): GenerationEntry {
      const enums = names
        .map((name) => {
          const e = allEnums.find((e) => e.name === name);
          return e;
        })
        .filter((i) => i !== undefined) as Browser.Enum[];

      return {
        kind: "enum",
        enums,
      };
    }

    function callbacks(names: string[]): GenerationEntry[] {
      return names
        .map((name) => {
          const c = allCallbacks.find((c) => c.name === name);
          return c;
        })
        .filter((c) => c !== undefined)
        .map((c) => {
          return {
            kind: "byHand",
            name: c.name,
            emitInterface: () => emitCallback(c),
          };
        });
    }

    let interfaceHierarchy: RescriptFile[] = [
      {
        name: "Prelude",
        entries: [
          byHand("any", () => printer.printLine("type any = {}")),
          byHand("unsafeConversion", () => {
            printer.endLine();
            printer.printLine(
              `external unsafeConversation: 'tinput => 'toutput = "%identity"`,
            );
            printer.endLine();
          }),
          byHand("BufferSource", emitAny("BufferSource")),
          byHand("BodyInit", emitAny("BodyInit")),
          // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/SharedArrayBuffer
          byHand("SharedArrayBuffer", emitAny("SharedArrayBuffer")),
          // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Float64Array
          byHand("Float64Array", emitAny("Float64Array")),
          individualInterfaces(["DOMException", "DOMStringList"]),
        ],
        opens: [],
      },

      {
        name: "EventAPI",
        entries: [
          byHand("EventType", emitEventType),
          byHand("EventListener", emitEventListener),
          individualInterfaces([
            "EventTarget",
            "Event",
            "AddEventListenerOptions",
          ]),
          chain(["AbortController", "AbortSignal"]),
          dictionaries([
            "EventListenerOptions",
            "AddEventListenerOptions",
            "EventInit",
          ]),
        ],
        opens: ["Prelude"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Channel_Messaging_API
      {
        name: "ChannelMessagingAPI",
        entries: [
          individualInterfaces(["MessagePort"]),
          dictionaries(["StructuredSerializeOptions"]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/History
      {
        name: "HistoryAPI",
        entries: [
          enums(["ScrollRestoration"]),
          individualInterfaces(["History"]),
        ],
        opens: ["Prelude"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/File_API
      {
        name: "FileAPI",
        entries: [
          enums([
            "EndingType",
            "ReadableStreamReaderMode",
            "FileSystemHandleKind",
            "WriteCommandType",
          ]),
          individualInterfaces([
            "Blob",
            "ReadableStream",
            "WritableStream",
            "WritableStreamDefaultController",
            "File",
            "FileSystemHandle",
            "FileSystemDirectoryHandle",
            "FileSystemFileHandle",
            "FileSystemWritableFileStream",
          ]),
          byHand("BlobPart", emitBlobPart),
          byHand("QueuingStrategy", emitAny("QueuingStrategy<'t>")),
          byHand("UnderlyingSink", emitAny("UnderlyingSink<'t>")),
          byHand("ReadableStreamReader", emitAny("ReadableStreamReader<'t>")),
          byHand(
            "WritableStreamDefaultWriter",
            emitAny("WritableStreamDefaultWriter<'t>"),
          ),
          byHand(
            "FileSystemWriteChunkType",
            emitAny("FileSystemWriteChunkType"),
          ),
          ...callbacks(["UnderlyingSourceCancelCallback"]),
          dictionaries([
            "BlobPropertyBag",
            "UnderlyingByteSource",
            "ReadableStreamGetReaderOptions",
            "ReadableWritablePair",
            "StreamPipeOptions",
            "FilePropertyBag",
            "FileSystemGetFileOptions",
            "FileSystemGetDirectoryOptions",
            "FileSystemRemoveOptions",
            "FileSystemCreateWritableOptions",
            "WriteParams",
          ]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Clipboard
      {
        name: "ClipboardAPI",
        entries: [
          enums(["PresentationStyle"]),
          individualInterfaces(["ClipboardItem", "Clipboard"]),
          dictionaries(["ClipboardItemOptions"]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Credential_Management_API
      {
        name: "CredentialManagementAPI",
        entries: [
          enums([
            "AuthenticatorTransport",
            "CredentialMediationRequirement",
            "PublicKeyCredentialType",
            "UserVerificationRequirement",
            "AuthenticatorAttachment",
            "ResidentKeyRequirement",
            "AttestationConveyancePreference",
          ]),
          individualInterfaces(["CredentialsContainer", "Credential"]),
          dictionaries([
            "PublicKeyCredentialDescriptor",
            "AuthenticationExtensionsPRFValues",
            "AuthenticationExtensionsPRFInputs",
            "AuthenticationExtensionsClientInputs",
            "PublicKeyCredentialRequestOptions",
            "CredentialRequestOptions",
            "PublicKeyCredentialEntity",
            "PublicKeyCredentialRpEntity",
            "PublicKeyCredentialUserEntity",
            "PublicKeyCredentialParameters",
            "AuthenticatorSelectionCriteria",
            "PublicKeyCredentialCreationOptions",
            "CredentialCreationOptions",
          ]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API
      {
        name: "GeolocationAPI",
        entries: [
          individualInterfaces([
            "Geolocation",
            "GeolocationCoordinates",
            "GeolocationPosition",
            "GeolocationPositionError",
          ]),
          dictionaries(["PositionOptions"]),
          ...callbacks(["PositionCallback", "PositionErrorCallback"]),
        ],
        opens: [],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Media_Capabilities_API
      {
        name: "MediaCapabilitiesAPI",
        entries: [
          enums([
            "HdrMetadataType",
            "ColorGamut",
            "TransferFunction",
            "MediaDecodingType",
            "MediaEncodingType",
          ]),
          individualInterfaces(["MediaCapabilities"]),
          dictionaries([
            "AudioConfiguration",
            "VideoConfiguration",
            "MediaConfiguration",
            "MediaDecodingConfiguration",
            "MediaCapabilitiesInfo",
            "MediaCapabilitiesDecodingInfo",
            "MediaEncodingConfiguration",
            "MediaCapabilitiesEncodingInfo",
          ]),
        ],
        opens: [],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Media_Capture_and_Streams_API
      {
        name: "MediaCaptureAndStreamsAPI",
        entries: [
          enums(["MediaDeviceKind", "MediaStreamTrackState"]),
          individualInterfaces([
            "MediaDevices",
            "MediaDeviceInfo",
            "MediaStream",
            "MediaStreamTrack",
          ]),
          dictionaries([
            "MediaTrackSupportedConstraints",
            "MediaStreamConstraints",
            "DisplayMediaStreamOptions",
            "ULongRange",
            "DoubleRange",
            "MediaTrackCapabilities",
            "MediaTrackConstraintSet",
            "MediaTrackConstraints",
            "MediaTrackSettings",
          ]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/MediaSession
      {
        name: "MediaSessionAPI",
        entries: [
          enums(["MediaSessionPlaybackState", "MediaSessionAction"]),
          dictionaries(["MediaImage"]),
          individualInterfaces(["MediaMetadata", "MediaSession"]),
          dictionaries([
            "MediaMetadataInit",
            "MediaSessionActionDetails",
            "MediaPositionState",
          ]),
          ...callbacks(["MediaSessionActionHandler"]),
        ],
        opens: ["Prelude"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API
      {
        name: "PermissionsAPI",
        entries: [
          enums(["PermissionName", "PermissionState"]),
          individualInterfaces(["Permissions", "PermissionStatus"]),
          dictionaries(["PermissionDescriptor"]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Screen_Wake_Lock_API
      {
        name: "ScreenWakeLockAPI",
        entries: [
          enums(["WakeLockType"]),
          individualInterfaces(["WakeLock", "WakeLockSentinel"]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Push_API
      {
        name: "PushManagerAPI",
        entries: [
          enums(["PermissionState", "PushEncryptionKeyName"]),
          individualInterfaces([
            "PushManager",
            "PushSubscriptionOptions",
            "PushSubscription",
          ]),
          dictionaries(["PushSubscriptionOptionsInit", "PushSubscriptionJSON"]),
        ],
        opens: ["Prelude"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API
      {
        name: "NotificationAPI",
        entries: [
          enums(["NotificationDirection", "NotificationPermission"]),
          individualInterfaces(["Notification"]),
          dictionaries(["NotificationOptions", "GetNotificationOptions"]),
          ...callbacks(["NotificationPermissionCallback"]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API
      {
        name: "FetchAPI",
        entries: [
          enums([
            "ResponseType",
            "RequestDestination",
            "ReferrerPolicy",
            "RequestMode",
            "RequestCredentials",
            "RequestCache",
            "RequestRedirect",
            "RequestPriority",
          ]),
          individualInterfaces([
            "Headers",
            "Request",
            "Response",
            "FormData",
            "URLSearchParams",
          ]),
          byHand("HeadersInit", emitAny("HeadersInit")),
          byHand("RequestInfo", emitAny("RequestInfo")),
          byHand("FormDataEntryValue", emitAny("FormDataEntryValue")),
          dictionaries(["RequestInit", "ResponseInit"]),
        ],
        opens: ["Prelude", "EventAPI", "FileAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API
      {
        name: "ServiceWorkerAPI",
        entries: [
          enums([
            "ServiceWorkerState",
            "ServiceWorkerUpdateViaCache",
            "WorkerType",
          ]),
          individualInterfaces([
            "ServiceWorker",
            "NavigationPreloadManager",
            "ServiceWorkerRegistration",
            "ServiceWorkerContainer",
            "CacheStorage",
            "Cache",
          ]),
          dictionaries([
            "NavigationPreloadState",
            "RegistrationOptions",
            "CacheQueryOptions",
            "MultiCacheQueryOptions",
          ]),
          byHand("RequestInfo", emitAny("RequestInfo")),
        ],
        opens: [
          "Prelude",
          "EventAPI",
          "PushManagerAPI",
          "NotificationAPI",
          "FetchAPI",
          "ChannelMessagingAPI",
        ],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Encrypted_Media_Extensions_API
      {
        name: "EncryptedMediaExtensionsAPI",
        entries: [
          enums([
            "MediaKeysRequirement",
            "MediaKeySessionType",
            "MediaKeySessionClosedReason",
            "MediaKeyStatus",
          ]),
          individualInterfaces([
            "MediaKeySystemAccess",
            "MediaKeys",
            "MediaKeyStatusMap",
            "MediaKeySession",
          ]),
          dictionaries([
            "MediaKeySystemMediaCapability",
            "MediaKeySystemConfiguration",
            "MediaKeysPolicy",
          ]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Gamepad_API
      {
        name: "GamepadAPI",
        entries: [
          enums([
            "GamepadMappingType",
            "GamepadHapticEffectType",
            "GamepadHapticsResult",
          ]),
          individualInterfaces([
            "GamepadButton",
            "GamepadHapticActuator",
            "Gamepad",
          ]),
          dictionaries(["GamepadEffectParameters"]),
        ],
        opens: [],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API
      {
        name: "WebMIDIAPI",
        entries: [
          individualInterfaces(["MIDIInputMap", "MIDIOutputMap", "MIDIAccess"]),
          dictionaries(["MIDIOptions"]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/History
      {
        name: "HistoryAPI",
        entries: [
          enums(["ScrollRestoration"]),
          individualInterfaces(["History"]),
        ],
        opens: ["Prelude"],
      },
      //https://developer.mozilla.org/en-US/docs/Web/API/Visual_Viewport_API
      {
        name: "VisualViewportAPI",
        entries: [individualInterfaces(["VisualViewport"])],
        opens: ["EventAPI"],
      },
      //https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API
      {
        name: "WebSpeechAPI",
        entries: [
          individualInterfaces([
            "SpeechSynthesis",
            "SpeechSynthesisVoice",
            "SpeechSynthesisUtterance",
          ]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/View_Transitions_API
      {
        name: "ViewTransitionsAPI",
        entries: [
          individualInterfaces(["ViewTransition"]),
          ...callbacks(["ViewTransitionUpdateCallback"]),
        ],
        opens: ["Prelude"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/File_and_Directory_Entries_API
      {
        name: "FileAndDirectoryEntriesAPI",
        entries: [
          chain(["FileSystemEntry", "FileSystemDirectoryEntry", "FileSystem"]),
          individualInterfaces(["FileSystemDirectoryReader"]),
          dictionaries(["FileSystemFlags"]),
          ...callbacks([
            "FileSystemEntryCallback",
            "ErrorCallback",
            "FileSystemEntriesCallback",
          ]),
        ],
        opens: ["Prelude"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API
      {
        name: "WebVTTAPI",
        entries: [
          enums(["TextTrackKind", "TextTrackMode"]),
          individualInterfaces(["TextTrackCueList"]),
          chain(["TextTrackCue", "TextTrack"]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Remote_Playback_API
      {
        name: "RemotePlaybackAPI",
        entries: [
          enums(["RemotePlaybackState"]),
          individualInterfaces(["RemotePlayback"]),
          ...callbacks(["RemotePlaybackAvailabilityCallback"]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API
      {
        name: "CanvasAPI",
        entries: [
          enums([
            "OffscreenRenderingContextId",
            "GlobalCompositeOperation",
            "ImageSmoothingQuality",
            "CanvasLineCap",
            "CanvasLineJoin",
            "CanvasTextAlign",
            "CanvasTextBaseline",
            "CanvasDirection",
            "CanvasFontKerning",
            "CanvasFontStretch",
            "CanvasFontVariantCaps",
            "CanvasTextRendering",
            "PredefinedColorSpace",
            "CanvasFillRule",
          ]),
          individualInterfaces([
            "OffscreenCanvas",
            "ImageBitmap",
            "OffscreenCanvasRenderingContext2D",
            "ImageBitmapRenderingContext",
            "WebGLRenderingContext",
            "WebGL2RenderingContext",
            "CanvasGradient",
            "CanvasPattern",
            "Path2D",
            "TextMetrics",
          ]),
          byHand(
            "OffscreenRenderingContext",
            emitAny("OffscreenRenderingContext"),
          ),
          dictionaries([
            "ImageEncodeOptions",
            "CanvasRenderingContext2DSettings",
          ]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Picture-in-Picture_API
      {
        name: "PictureInPictureAPI",
        entries: [individualInterfaces(["PictureInPictureWindow"])],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API
      {
        name: "WebStorageAPI",
        entries: [
          individualInterfaces(["Storage", "StorageEvent"]),
          dictionaries(["StorageEventInit"]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Storage_API
      {
        name: "StorageAPI",
        entries: [
          individualInterfaces(["StorageManager"]),
          dictionaries(["StorageEstimate"]),
        ],
        opens: [],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Web_Locks_API
      {
        name: "WebLocksAPI",
        entries: [
          enums(["LockMode"]),
          individualInterfaces(["LockManager", "Lock"]),
          dictionaries(["LockInfo", "LockManagerSnapshot", "LockOptions"]),
          ...callbacks(["LockGrantedCallback"]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/CSS_Font_Loading_API
      {
        name: "CSSFontLoadingAPI",
        entries: [
          enums(["FontDisplay", "FontFaceLoadStatus", "FontFaceSetLoadStatus"]),
          chain(["FontFace"]),
          chain(["FontFaceSet"]),
          dictionaries(["FontFaceDescriptors"]),
        ],
        opens: ["EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API
      {
        name: "IndexedDBAPI",
        entries: [
          enums([
            "IDBTransactionMode",
            "IDBTransactionDurability",
            "IDBRequestReadyState",
            "IDBCursorDirection",
          ]),
          individualInterfaces([
            "IDBFactory",
            "IDBDatabase",
            "IDBTransaction",
            "IDBRequest",
            "IDBOpenDBRequest",
            "IDBObjectStore",
            "IDBIndex",
          ]),
          byHand("IDBValidKey", emitAny("IDBValidKey")),
          dictionaries([
            "IDBDatabaseInfo",
            "IDBTransactionOptions",
            "IDBObjectStoreParameters",
            "IDBIndexParameters",
          ]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API
      {
        name: "WebCryptoAPI",
        entries: [
          enums(["KeyType", "KeyUsage", "KeyFormat"]),
          dictionaries(["KeyAlgorithm"]),
          individualInterfaces(["SubtleCrypto", "Crypto", "CryptoKey"]),
          byHand("AlgorithmIdentifier", emitAny("AlgorithmIdentifier")),
          dictionaries(["Algorithm"]),
        ],
        opens: ["Prelude"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Performance_API
      {
        name: "PerformanceAPI",
        entries: [
          individualInterfaces([
            "EventCounts",
            "Performance",
            "PerformanceEntry",
            "PerformanceMark",
            "PerformanceMeasure",
          ]),
          byHand("PerformanceEntryList", emitAny("PerformanceEntryList")),
          dictionaries(["PerformanceMarkOptions", "PerformanceMeasureOptions"]),
        ],
        opens: ["Prelude", "EventAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model
      // https://developer.mozilla.org/en-US/docs/Web/API/HTML_DOM_API
      {
        name: "DOMAPI",
        entries: [
          enums([
            "ShadowRootMode",
            "SlotAssignmentMode",
            "AutoFillBase",
            "DocumentReadyState",
            "DocumentVisibilityState",
            "OrientationType",
            "InsertPosition",
            "ScrollBehavior",
            "FullscreenNavigationUI",
            "RemotePlaybackState",
            "ReferrerPolicy",
            "CanPlayTypeResult",
            "AnimationPlayState",
            "AnimationReplaceState",
            "FillMode",
            "PlaybackDirection",
            "ImageOrientation",
            "PremultiplyAlpha",
            "ColorSpaceConversion",
            "ResizeQuality",
            "ScrollLogicalPosition",
            "SelectionMode",
            "CompositeOperation",
            "IterationCompositeOperation",
            "VideoPixelFormat",
            "VideoColorPrimaries",
            "VideoTransferCharacteristics",
            "VideoMatrixCoefficients",
            "AlphaOption",
            "PredefinedColorSpace",
          ]),
          // TODO: perhaps move to Web Share API?
          // See https://developer.mozilla.org/en-US/docs/Web/API/Web_Share_API
          // It does not have interfaces and only extends the navigator object
          dictionaries(["ShareData"]),
          individualInterfaces([
            "Location",
            "UserActivation",
            "Navigator",
            "DOMTokenList",
            "NamedNodeMap",
            "FragmentDirective",
            "CustomElementRegistry",
            "BarProp",
            "ScreenOrientation",
            "Screen",
          ]),
          byHand("VibratePattern", emitVibratePattern),
          byHand("RenderingContext", emitAny("RenderingContext")),
          byHand(
            "OffscreenRenderingContext",
            emitAny("OffscreenRenderingContext"),
          ),
          chain(["AnimationTimeline", "DocumentTimeline"]),
          individualInterfaces([
            "MediaList",
            "StylePropertyMapReadOnly",
            "StylePropertyMap",
            "DOMStringMap",
          ]),
          chain([
            "StyleSheetList",
            "StyleSheet",
            "CSSStyleSheet",
            "CSSRule",
            "CSSRuleList",
            "CSSStyleDeclaration",
          ]),
          chain([
            "Node",
            "NodeList",
            "NodeListOf",
            "Element",
            "ShadowRoot",
            "HTMLCollection",
            "HTMLCollectionOf",
            "HTMLFormControlsCollection",
            "HTMLElement",
            "HTMLHeadElement",
            "HTMLFormElement",
            "HTMLImageElement",
            "HTMLEmbedElement",
            "HTMLAnchorElement",
            "HTMLAreaElement",
            "HTMLScriptElement",
            "DOMImplementation",
            "DocumentType",
            "Document",
            "Window",
            "MutationRecord",
            "Attr",
            "CharacterData",
            "DocumentFragment",
            "HTMLSlotElement",
          ]),
          individualInterfaces([
            "DOMRectReadOnly",
            "DOMRect",
            "DOMRectList",
            "ValidityState",
            "CustomStateSet",
            "ElementInternals",
            "XMLDocument",
            "Text",
            "CDATASection",
            "Comment",
            "ProcessingInstruction",
            "AbstractRange",
            "Range",
            "NodeFilter",
            "NodeIterator",
            "TreeWalker",
            "CaretPosition",
            "Selection",
            "MediaQueryList",
            "IdleDeadline",
            "CSSStyleValue",
            "FileList",
            "MediaError",
            "TimeRanges",
            "TextTrackList",
            "VideoPlaybackQuality",
          ]),
          chain([
            "HTMLTableElement",
            "HTMLTableCaptionElement",
            "HTMLTableSectionElement",
            "HTMLTableCellElement",
            "HTMLTableRowElement",
          ]),
          chain([
            "HTMLButtonElement",
            "HTMLLabelElement",
            "HTMLTextAreaElement",
            "HTMLOutputElement",
            "HTMLInputElement",
            "HTMLDataListElement",
            "HTMLSelectElement",
            "HTMLOptionElement",
            "HTMLOptionsCollection",
          ]),
          byHand("MediaProvider", emitAny("MediaProvider")),
          individualInterfaces([
            "HTMLMediaElement",
            "HTMLAudioElement",
            "HTMLBaseElement",
            "HTMLBodyElement",
            "HTMLBRElement",
            "HTMLCanvasElement",
            "HTMLDataElement",
            "HTMLDialogElement",
            "HTMLDivElement",
            "HTMLDListElement",
            "HTMLFieldSetElement",
            "HTMLFrameSetElement",
            "HTMLHeadingElement",
            "HTMLHRElement",
            "HTMLHtmlElement",
            "HTMLIFrameElement",
            "HTMLLegendElement",
            "HTMLLIElement",
            "HTMLLinkElement",
            "HTMLMapElement",
            "HTMLMenuElement",
            "HTMLMetaElement",
            "HTMLMeterElement",
            "HTMLModElement",
            "HTMLObjectElement",
            "HTMLOListElement",
            "HTMLOptGroupElement",
            "HTMLParagraphElement",
            "HTMLPictureElement",
            "HTMLPreElement",
            "HTMLProgressElement",
            "HTMLQuoteElement",
            "HTMLSourceElement",
            "HTMLSpanElement",
            "HTMLStyleElement",
            "HTMLTemplateElement",
            "HTMLTimeElement",
            "HTMLTitleElement",
            "HTMLTrackElement",
            "HTMLUListElement",
            "HTMLUnknownElement",
            "HTMLVideoElement",
            "AnimationEffect",
            "XPathExpression",
            "XPathResult",
            "SVGAnimatedPreserveAspectRatio",
            "SVGLength",
            "SVGAnimatedLength",
            "SVGElement",
            "SVGGraphicsElement",
            "SVGImageElement",
            "DOMMatrixReadOnly",
            "DOMMatrix",
            "VideoColorSpace",
            "VideoFrame",
            "ImageData",
            "DOMPointReadOnly",
            "DOMPoint",
            "CanvasRenderingContext2D",
          ]),
          chain(["Animation"]),
          dictionaries([
            "ElementDefinitionOptions",
            "DocumentTimelineOptions",
            "GetRootNodeOptions",
            "ShadowRootInit",
            "CheckVisibilityOptions",
            "ScrollOptions",
            "ScrollToOptions",
            "FullscreenOptions",
            "GetHTMLOptions",
            "PointerLockOptions",
            "CaretPositionFromPointOptions",
            "IdleRequestOptions",
            "DOMRectInit",
            "ValidityStateFlags",
            "CSSStyleSheetInit",
            "VideoFrameCallbackMetadata",
            "AssignedNodesOptions",
            "FocusOptions",
            "EffectTiming",
            "GetAnimationsOptions",
            "ComputedEffectTiming",
            "OptionalEffectTiming",
            "ImageBitmapOptions",
            "ScrollIntoViewOptions",
            "WindowPostMessageOptions",
            "KeyframeEffectOptions",
            "KeyframeAnimationOptions",
            "ElementCreationOptions",
            "SVGBoundingBoxOptions",
            "DOMMatrix2DInit",
            "DOMMatrixInit",
            "VideoFrameInit",
            "VideoColorSpaceInit",
            "PlaneLayout",
            "VideoFrameBufferInit",
            "ImageDataSettings",
            "VideoFrameCopyToOptions",
            "DOMPointInit",
          ]),
          byHand("XPathNSResolver", emitAny("XPathNSResolver")),
          byHand("TimerHandler", emitAny("TimerHandler")),
          byHand("VoidFunction", () =>
            printer.printLine("type voidFunction = unit => unit"),
          ),
          byHand("ImageBitmapSource", emitAny("ImageBitmapSource")),
          ...callbacks([
            "CustomElementConstructor",
            "IdleRequestCallback",
            "FileSystemEntriesCallback",
            "BlobCallback",
            "VideoFrameRequestCallback",
            "FrameRequestCallback",
          ]),
        ],
        opens: [
          "Prelude",
          "EventAPI",
          "ClipboardAPI",
          "CredentialManagementAPI",
          "GeolocationAPI",
          "MediaCapabilitiesAPI",
          "MediaCaptureAndStreamsAPI",
          "MediaSessionAPI",
          "PermissionsAPI",
          "ScreenWakeLockAPI",
          "ServiceWorkerAPI",
          "EncryptedMediaExtensionsAPI",
          "GamepadAPI",
          "FileAPI",
          "WebMIDIAPI",
          "HistoryAPI",
          "VisualViewportAPI",
          "WebSpeechAPI",
          "ViewTransitionsAPI",
          "FileAndDirectoryEntriesAPI",
          "WebVTTAPI",
          "RemotePlaybackAPI",
          "CanvasAPI",
          "StorageAPI",
          "WebLocksAPI",
          "CSSFontLoadingAPI",
          "IndexedDBAPI",
          "WebCryptoAPI",
          "PerformanceAPI",
          "WebStorageAPI",
          "ChannelMessagingAPI",
        ],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API
      {
        name: "WebAudioAPI",
        entries: [
          enums([
            "AudioContextState",
            "BiquadFilterType",
            "ChannelCountMode",
            "ChannelInterpretation",
            "OscillatorType",
            "PanningModelType",
            "DistanceModelType",
            "OverSampleType",
            "RequestCredentials",
          ]),
          individualInterfaces([
            "AudioBuffer",
            "AudioProcessingEvent",
            "MediaTrackCapabilities",
            "OfflineAudioCompletionEvent",
            "Worklet",
          ]),
          chain([
            "AudioNode",
            "AudioDestinationNode",
            "BaseAudioContext",
            "BiquadFilterNode",
            "AudioListener",
            "AudioWorklet",
            "AudioParam",
            "AudioScheduledSourceNode",
            "AudioBufferSourceNode",
            "ChannelMergerNode",
            "ChannelSplitterNode",
            "ConstantSourceNode",
            "ConvolverNode",
            "DelayNode",
            "DynamicsCompressorNode",
            "GainNode",
            "IIRFilterNode",
            "OscillatorNode",
            "PannerNode",
          ]),
          individualInterfaces([
            "AnalyserNode",
            "PeriodicWave",
            "StereoPannerNode",
            "WaveShaperNode",
            "AudioContext",
            "MediaElementAudioSourceNode",
            "MediaStreamAudioSourceNode",
            "MediaStreamAudioDestinationNode",
            "AudioParamMap",
            "AudioWorkletNode",
            "OfflineAudioContext",
          ]),
          dictionaries([
            "PeriodicWaveConstraints",
            "AudioTimestamp",
            "ULongRange",
            "DoubleRange",
            "MediaTrackCapabilities",
            "MediaTrackConstraintSet",
            "MediaTrackConstraints",
            "MediaTrackSettings",
            "AudioBufferOptions",
            "AudioProcessingEventInit",
            "OfflineAudioCompletionEventInit",
            "AudioNodeOptions",
            "BiquadFilterOptions",
            "AudioBufferSourceOptions",
            "ChannelMergerOptions",
            "ChannelSplitterNode",
            "ChannelSplitterOptions",
            "ConstantSourceOptions",
            "ConvolverOptions",
            "DelayOptions",
            "DynamicsCompressorOptions",
            "GainOptions",
            "IIRFilterOptions",
            "OscillatorOptions",
            "PannerOptions",
            "AnalyserOptions",
            "PeriodicWaveOptions",
            "StereoPannerOptions",
            "WaveShaperOptions",
            "AudioContextOptions",
            "MediaElementAudioSourceOptions",
            "MediaStreamAudioSourceOptions",
            "AudioWorkletNodeOptions",
            "OfflineAudioContextOptions",
            "WorkletOptions",
          ]),
          ...callbacks(["DecodeSuccessCallback", "DecodeErrorCallback"]),
        ],
        opens: [
          "Prelude",
          "ChannelMessagingAPI",
          "EventAPI",
          "DOMAPI",
          "MediaCaptureAndStreamsAPI",
        ],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/Resize_Observer_API
      {
        name: "ResizeObserverAPI",
        entries: [
          enums(["ResizeObserverBoxOptions"]),
          individualInterfaces([
            "ResizeObserverSize",
            "ResizeObserverEntry",
            "ResizeObserver",
          ]),
          dictionaries(["ResizeObserverOptions"]),
          ...callbacks(["ResizeObserverCallback"]),
        ],
        opens: ["Prelude", "DOMAPI"],
      },
      // https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API
      {
        name: "WebSocketsAPI",
        entries: [
          enums(["BinaryType"]),
          byHand("MessageEventSource", emitAny("MessageEventSource")),
          individualInterfaces([
            "WebSocket",
            "WebSocketStream",
            "CloseEvent",
            "MessageEvent",
          ]),
          dictionaries(["CloseEventInit", "MessageEventInit"]),
        ],
        opens: ["Prelude", "EventAPI", "ChannelMessagingAPI"],
      },
    ];

    interfaceHierarchy = [
      {
        name: "Temp",
        entries: [
          enums(["WebGLPowerPreference"]),
          dictionaries(["ImageBitmapRenderingContextSettings", "WebGLContextAttributes"]),
        ],
        opens: [],
      }
    ]

    // Ensure the output folder exists.
    await fs.mkdir(outputFolder, { recursive: true });

    // Keep track of each type present in each module.
    const typesInModuleMap = new Map<string, string>();

    // Write all interfaces (in order) to top level src folder.
    for (const file of interfaceHierarchy) {
      printer.reset();
      printer.printLine('@@warning("-30")');
      emitOpens(file.opens);

      for (const entry of file.entries) {
        switch (entry.kind) {
          case "individuals":
            emitIndividualInterfaces(entry.interfaces);
            break;
          case "chain":
            emitInterfaceChain(entry.chain, entry.interfaces);
            break;
          case "byHand":
            entry.emitInterface();
            break;
          case "dictionary":
            entry.dictionaries.forEach(emitDictionaryRecord);
            break;
          case "enum":
            entry.enums.forEach(emitEnum);
            break;
        }

        file.entries
          .flatMap((entry) => {
            switch (entry.kind) {
              case "individuals":
              case "chain":
                return entry.interfaces.map((i) => i.name);
              case "dictionary":
                return entry.dictionaries.map((d) => d.name);
              case "enum":
                return entry.enums.map((e) => e.name);
              case "byHand":
                return [entry.name];
              default:
                return [];
            }
          })
          .forEach((typeName: string) => {
            typesInModuleMap.set(typeName, file.name);
          });
      }

      const contents = printer.getResult();
      await fs.writeFile(path.join(outputFolder, `${file.name}.res`), contents);
    }

    // Loop all files again to emit the nested modules.
    for (const file of interfaceHierarchy) {
      const moduleFolder = path.join(outputFolder, path.basename(file.name));
      await fs.mkdir(moduleFolder, { recursive: true });

      for (const entry of file.entries) {
        if (
          entry.kind === "byHand" ||
          entry.kind === "dictionary" ||
          entry.kind === "enum"
        ) {
          continue;
        }

        for (const i of entry.interfaces) {
          printer.reset();

          const opens = findOpensForNestedModules(i, typesInModuleMap);

          emitInterfaceFunctionsModule(opens, i);
          const contents = printer.getResult();
          if (contents) {
            let fileName = i.name;

            await fs.writeFile(
              path.join(moduleFolder, `${fileName}.res`),
              contents,
            );
          }
        }
      }
    }

    await emitGlobalModule();

    // execSync("npx rescript format -all", { cwd: repoRoot, stdio: "inherit" });

    // let remainers = allInterfaces.filter((i) => {
    //   return !interfaceHierarchy.some((h) => {
    //     return h.interfaces.some((j) => {
    //       return j.name === i.name;
    //     });
    //   });
    // });
    // remainers = topologicalSortDictionaries(remainers);

    // console.log(`Remainders: ${remainers.length}`);

    // emitIndividualInterfaces(remainers);
  }

  await emit();
}
