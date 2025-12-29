module Bindings = FrontmanNextjs__OpenTelemetry__Bindings

let makeLogRecordProcessor = FrontmanNextjs__LogRecordProcessor.make
let makeSpanProcessor = FrontmanNextjs__SpanProcessor.make

let makeProcessors = () => (makeLogRecordProcessor(), makeSpanProcessor())
