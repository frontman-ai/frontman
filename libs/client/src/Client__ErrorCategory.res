type t = [
  | #auth
  | #billing
  | #quota
  | #rate_limit
  | #payload_too_large
  | #output_truncated
  | #unknown
  | #other(string)
]

let fromAcpCategory = (category: option<string>): t =>
  switch category {
  | Some("auth") => #auth
  | Some("billing") => #billing
  | Some("quota") => #quota
  | Some("rate_limit") => #rate_limit
  | Some("payload_too_large") => #payload_too_large
  | Some("output_truncated") => #output_truncated
  | Some("unknown") | None => #unknown
  | Some(category) => #other(category)
  }
