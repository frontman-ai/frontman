// Max 7680px per dimension (Anthropic hard-rejects >8000; server gate enforces 7680 for all providers).

type limits = {
  maxDimension: int,
  quality: float,
}

let conservative: limits = {maxDimension: 7680, quality: 0.8}

let forProvider = (_provider: option<string>): limits => conservative

@new external makeImage: unit => WebAPI.DOMAPI.htmlImageElement = "Image"

let computeScale = (element: WebAPI.DOMAPI.element, maxDimension: int): float => {
  switch maxDimension <= 0 {
  | true => 1.0
  | false =>
    let dpr = WebAPI.Global.devicePixelRatio
    let rect = element->WebAPI.Element.getBoundingClientRect
    let maxSide = Math.max(rect.width *. dpr, rect.height *. dpr)
    switch maxSide <= 0.0 || maxSide <= maxDimension->Int.toFloat {
    | true => 1.0
    | false => maxDimension->Int.toFloat /. maxSide
    }
  }
}

let constrainDataUrl = async (dataUrl: string, limits: limits): string => {
  switch !(dataUrl->String.startsWith("data:image/")) {
  | true => dataUrl
  | false =>
    let maxDim = limits.maxDimension
    let img = makeImage()
    img.src = dataUrl
    let decoded = try {
      await img->WebAPI.HTMLImageElement.decode
      true
    } catch {
    | _ => false
    }
    switch decoded {
    | false => dataUrl
    | true =>
      let w = img.naturalWidth
      let h = img.naturalHeight
      switch w <= maxDim && h <= maxDim {
      | true => dataUrl
      | false =>
        let scale = Math.min(maxDim->Int.toFloat /. w->Int.toFloat, maxDim->Int.toFloat /. h->Int.toFloat)
        let nw = Math.round(w->Int.toFloat *. scale)->Float.toInt
        let nh = Math.round(h->Int.toFloat *. scale)->Float.toInt
        let canvas = WebAPI.Global.document->WebAPI.Document.createCanvasElement
        canvas.width = nw
        canvas.height = nh
        let ctx = canvas->WebAPI.HTMLCanvasElement.getContext_2D
        ctx->WebAPI.CanvasRenderingContext2D.drawImageWithDimensions(
          ~image=img,
          ~dx=0.0,
          ~dy=0.0,
          ~dw=nw->Int.toFloat,
          ~dh=nh->Int.toFloat,
        )
        canvas->WebAPI.HTMLCanvasElement.toDataURL(~type_="image/jpeg", ~quality=limits.quality->Obj.magic)
      }
    }
  }
}
