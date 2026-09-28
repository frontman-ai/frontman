external toHTMLCanvasElement: null<DomTypes.element> => DomTypes.htmlCanvasElement = "%identity"
@set
external setFillStyle: (DomTypes.canvasRenderingContext2D, CanvasTypes.fillStyle) => unit =
  "fillStyle"
@get
external getFillStyle: DomTypes.canvasRenderingContext2D => CanvasTypes.fillStyle = "fillStyle"
@set
external setFont: (DomTypes.canvasRenderingContext2D, string) => unit = "font"
@set
external setTextBaseline: (
  DomTypes.canvasRenderingContext2D,
  CanvasTypes.canvasTextBaseline,
) => unit = "textBaseline"

let myCanvas: DomTypes.htmlCanvasElement =
  DomGlobal.document->Document.getElementById("myCanvas")->toHTMLCanvasElement
let ctx = myCanvas->HTMLCanvasElement.getContext2D

ctx->setFillStyle(FillStyle.fromString("red"))
ctx->CanvasRenderingContext2D.fillRect(~x=50., ~y=50., ~w=200., ~h=200.)

ctx->setFillStyle(FillStyle.fromString("black"))
ctx->setFont("2px Tahoma")
ctx->setTextBaseline(CanvasTypes.Top)
ctx->CanvasRenderingContext2D.fillText(~text="MY TEXT", ~x=60., ~y=60.)

switch ctx->getFillStyle->FillStyle.decode {
| FillStyle.String(color) => Console.log(`Color: ${color}`)
| FillStyle.CanvasGradient(_) => Console.log("CanvasGradient")
| FillStyle.CanvasPattern(_) => Console.log("CanvasPattern")
}

let img: DomTypes.htmlImageElement = DomGlobal.document->Document.createElement("img")->Obj.magic
ctx->CanvasRenderingContext2D.drawImageWithDimensions(
  ~image=img,
  ~dx=0.,
  ~dy=0.,
  ~dw=200.,
  ~dh=200.,
)
