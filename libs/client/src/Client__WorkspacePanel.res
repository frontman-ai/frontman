type view = Preview | Changes

let availableView = (~view: view, ~fileChangeCount: int): view =>
  switch (view, fileChangeCount) {
  | (Changes, 0) => Preview
  | (view, _) => view
  }

@react.component
let make = (~view: view, ~preview: React.element, ~changes: React.element) =>
  switch view {
  | Preview => preview
  | Changes => changes
  }
