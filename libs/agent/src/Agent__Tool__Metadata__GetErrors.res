// Metadata-only definition for get_page_title client tool
// This defines the tool's schema for the agent without execution logic
// The actual execution happens in libs/client/src/tools/Client__Tool__GetPageTitle.res

let name = "get_errors"
let description = "Retrieves any client or server side errors from the last run"

@schema
type input = {@s.optional _unused: option<string>}

// NO execute function - this tool executes in the browser with client state
