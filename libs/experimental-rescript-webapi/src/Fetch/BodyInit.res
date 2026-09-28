type t = FetchTypes.bodyInit

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromString: string => t = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromArrayBuffer: ArrayBuffer.t => t = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromTypedArray: TypedArray.t<'t> => t = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromDataView: DataView.t => t = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromBlob: Blob.t => t = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromFile: File.t => t = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromURLSearchParams: URLSearchParams.t => t = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromFormData: FormData.t => t = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_a_body)
 */
external fromReadableStream: ReadableStream.t<'t> => t = "%identity"
