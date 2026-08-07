@new
external fromString: (
  ~family: string,
  ~source: string,
  ~descriptors: CssFontLoadingTypes.fontFaceDescriptors=?,
) => CssFontLoadingTypes.fontFace = "FontFace"

@new
external fromDataView: (
  ~family: string,
  ~source: DataView.t,
  ~descriptors: CssFontLoadingTypes.fontFaceDescriptors=?,
) => CssFontLoadingTypes.fontFace = "FontFace"

@new
external fromArrayBuffer: (
  ~family: string,
  ~source: ArrayBuffer.t,
  ~descriptors: CssFontLoadingTypes.fontFaceDescriptors=?,
) => CssFontLoadingTypes.fontFace = "FontFace"

@send
external load: CssFontLoadingTypes.fontFace => promise<CssFontLoadingTypes.fontFace> = "load"
