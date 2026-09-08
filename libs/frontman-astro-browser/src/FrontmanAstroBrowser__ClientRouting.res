@schema
type t =
  | @as("enabled") Enabled
  | @as("disabled") Disabled
  | @as("unavailable") Unavailable

/// Matches Astro 5–7's transitionEnabledOnThisPage: marker presence means
/// routing opt-in, not browser animation support or completed navigation.
let read = (document: option<WebAPI.DomTypes.document>): t => {
  switch document {
  | None => Unavailable
  | Some(document) =>
    switch document
    ->WebAPI.Document.querySelector("[name=\"astro-view-transitions-enabled\"]")
    ->Null.toOption {
    | Some(_) => Enabled
    | None => Disabled
    }
  }
}
