// export type Options = {
//     /** The root element to start the search from. */
//     root: Element;
//     /** Function that determines if an id name may be used in a selector. */
//     idName: (name: string) => boolean;
//     /** Function that determines if a class name may be used in a selector. */
//     className: (name: string) => boolean;
//     /** Function that determines if a tag name may be used in a selector. */
//     tagName: (name: string) => boolean;
//     /** Function that determines if an attribute may be used in a selector. */
//     attr: (name: string, value: string) => boolean;
//     /** Timeout to search for a selector. */
//     timeoutMs: number;
//     /** Minimum length of levels in fining selector. */
//     seedMinLength: number;
//     /** Minimum length for optimising selector. */
//     optimizedMinLength: number;
//     /** Maximum number of path checks. */
//     maxNumberOfPathChecks: number;
// };

type finderOptions = {
  root: WebAPI.DOMAPI.element,
  idName: (~name: string) => bool,
  className: (~name: string) => bool,
  tagName: (~name: string) => bool,
  attr: (~name: string, ~value: string) => bool,
  timeoutMs?: int,
  seedMinLength?: int,
  optimizedMinLength?: int,
  maxNumberOfPathChecks?: int,
}
@module("@medv/finder")
external finder: (~element: WebAPI.DOMAPI.element, ~options: finderOptions) => string = "finder"
