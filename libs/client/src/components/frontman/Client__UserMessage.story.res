open Bindings__Storybook

type args = {text: string}

module Samples = {
  open Client__Message.MessageAnnotation

  let buttonAnnotation: Client__Message.MessageAnnotation.t = {
    id: "ann-1",
    selector: Ok(Some(".btn-submit")),
    tagName: "button",
    cssClasses: Some("btn-submit primary"),
    comment: Some("This button should be blue"),
    screenshot: Ok(None),
    sourceLocation: Ok(None),
    boundingBox: None,
    nearbyText: Some("Submit"),
  }

  let headerAnnotation: t = {
    id: "ann-2",
    selector: Ok(Some("h1.page-title")),
    tagName: "h1",
    cssClasses: Some("page-title text-lg"),
    comment: None,
    screenshot: Ok(None),
    sourceLocation: Ok(None),
    boundingBox: None,
    nearbyText: Some("Welcome to the App"),
  }

  let inputAnnotation: t = {
    id: "ann-3",
    selector: Ok(Some("input#email")),
    tagName: "input",
    cssClasses: Some("form-input"),
    comment: Some("Email field needs validation"),
    screenshot: Ok(None),
    sourceLocation: Ok(None),
    boundingBox: None,
    nearbyText: Some("Enter your email"),
  }

  let divAnnotation: t = {
    id: "ann-4",
    selector: Ok(None),
    tagName: "div",
    cssClasses: None,
    comment: None,
    screenshot: Ok(None),
    sourceLocation: Ok(None),
    boundingBox: None,
    nearbyText: None,
  }
}

let default: Meta.t<args> = {
  title: "Components/Frontman/UserMessage",
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
  render: args =>
    <Client__UserMessage
      content={switch args.text {
      | "" => []
      | text => [Client__State__Types.UserContentPart.Text({text: text})]
      }}
      messageId="story-msg-1"
    />,
}

let textOnly: Story.t<args> = {
  name: "Text Only",
  args: {text: "Make the header font size larger"},
}

let textWithAnnotations: Story.t<args> = {
  name: "Text + Annotations",
  args: {text: "Fix these elements please"},
  render: args =>
    <Client__UserMessage
      content=[Client__State__Types.UserContentPart.Text({text: args.text})]
      annotations=[Samples.buttonAnnotation, Samples.headerAnnotation]
      messageId="story-msg-2"
    />,
}

let annotationsOnly: Story.t<args> = {
  name: "Annotations Only (No Text)",
  args: {text: ""},
  render: _args =>
    <Client__UserMessage
      content=[]
      annotations=[Samples.buttonAnnotation, Samples.headerAnnotation, Samples.inputAnnotation]
      messageId="story-msg-3"
    />,
}

let singleAnnotationWithComment: Story.t<args> = {
  name: "Single Annotation with Comment",
  args: {text: ""},
  render: _args =>
    <Client__UserMessage
      content=[]
      annotations=[Samples.buttonAnnotation]
      messageId="story-msg-4"
    />,
}

let annotationWithoutCssClass: Story.t<args> = {
  name: "Annotation Without CSS Class",
  args: {text: "Check this div"},
  render: args =>
    <Client__UserMessage
      content=[Client__State__Types.UserContentPart.Text({text: args.text})]
      annotations=[Samples.divAnnotation]
      messageId="story-msg-5"
    />,
}

let manyAnnotations: Story.t<args> = {
  name: "Many Annotations",
  args: {text: ""},
  render: _args =>
    <Client__UserMessage
      content=[]
      annotations=[
        Samples.buttonAnnotation,
        Samples.headerAnnotation,
        Samples.inputAnnotation,
        Samples.divAnnotation,
      ]
      messageId="story-msg-6"
    />,
}
