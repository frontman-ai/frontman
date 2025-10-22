open FileAPI
open FetchAPI
open URLAPI

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromString: string => bodyInit = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromArrayBuffer: ArrayBuffer.t => bodyInit = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromTypedArray: TypedArray.t<'t> => bodyInit = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromDataView: DataView.t => bodyInit = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromBlob: blob => bodyInit = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromFile: file => bodyInit = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromURLSearchParams: urlSearchParams => bodyInit = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromFormData: formData => bodyInit = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromReadableStream: readableStream<'t> => bodyInit = "%identity"
