module MessageAnnotation = Client__Message.MessageAnnotation

let annotations: array<MessageAnnotation.t> = [
  {
    id: "ann-1",
    selector: Ok(Some(".btn-submit")),
    elementContext: Ok(None),
    tagName: "button",
    cssClasses: Some("btn-submit primary"),
    comment: Some("This button is broken"),
    screenshot: Ok(None),
    sourceLocation: Ok(None),
    boundingBox: None,
    nearbyText: Some("Submit"),
    elementorContext: None,
  },
  {
    id: "ann-2",
    selector: Ok(Some("div.header")),
    elementContext: Ok(None),
    tagName: "div",
    cssClasses: Some("header"),
    comment: None,
    screenshot: Ok(None),
    sourceLocation: Ok(None),
    boundingBox: None,
    nearbyText: Some("Welcome"),
    elementorContext: None,
  },
]
