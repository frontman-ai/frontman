// UI Tabs component bindings
// Usage:
// <Tabs defaultValue="tab1">
//   <TabsList>
//     <TabsTrigger value="tab1">{React.string("First Tab")}</TabsTrigger>
//     <TabsTrigger value="tab2">{React.string("Second Tab")}</TabsTrigger>
//   </TabsList>
//   <TabsContent value="tab1">
//     {React.string("First tab content")}
//   </TabsContent>
//   <TabsContent value="tab2">
//     {React.string("Second tab content")}
//   </TabsContent>
// </Tabs>

module Tabs = {
  @module("@/components/ui/tabs") @react.component
  external make: (
    ~className: string=?,
    ~defaultValue: string=?,
    ~value: string=?,
    ~onValueChange: string => unit=?,
    ~children: React.element=?,
  ) => React.element = "Tabs"
}

module TabsList = {
  @module("@/components/ui/tabs") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element = "TabsList"
}

module TabsTrigger = {
  @module("@/components/ui/tabs") @react.component
  external make: (
    ~className: string=?,
    ~value: string,
    ~disabled: bool=?,
    ~children: React.element=?,
  ) => React.element = "TabsTrigger"
}

module TabsContent = {
  @module("@/components/ui/tabs") @react.component
  external make: (
    ~className: string=?,
    ~value: string,
    ~children: React.element=?,
  ) => React.element = "TabsContent"
}
