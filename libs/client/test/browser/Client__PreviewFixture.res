let location = WebAPI.Window.current->WebAPI.Window.location
let url = WebAPI.URL.make(~url=location.href)
switch url.search {
| "?redirect" =>
  url.hostname = url.hostname == "localhost" ? "127.0.0.1" : "localhost"
  url.search = ""
  location->WebAPI.Location.replace(url.href)
| _ => ()
}
