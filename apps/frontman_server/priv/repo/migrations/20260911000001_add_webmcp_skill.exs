defmodule FrontmanServer.Repo.Migrations.AddWebmcpSkill do
  use Ecto.Migration

  @skill_id "fc5606a3-fe4c-46ab-ab62-6fbf4dca2efd"
  @content ~S"""
  # Implement WebMCP

  WebMCP exposes website actions as structured tools for browser agents. It is an experimental Community Group draft, not a finished W3C standard.

  This skill targets the current draft and Chrome's imperative documentation, last updated September 11, 2026. Browser versions can expose different APIs.

  ## 1. Establish the target

  Before implementation, read the current official references:

  - [WebMCP specification](https://webmachinelearning.github.io/webmcp/)
  - [Chrome setup and availability](https://developer.chrome.com/docs/ai/webmcp)
  - [Chrome imperative API](https://developer.chrome.com/docs/ai/webmcp/imperative-api)
  - [Chrome declarative API](https://developer.chrome.com/docs/ai/webmcp/declarative-api)
  - [Chrome tool security](https://developer.chrome.com/docs/ai/webmcp/secure-tools)
  - [Origin trial announcement](https://developer.chrome.com/blog/ai-webmcp-origin-trial)

  Identify the target browser version and its supported API. Distinguish draft features from implemented features. Do not combine examples from different API versions.

  The origin trial began in Chrome 149. Its start version does not establish support for every feature in the current draft.

  WebMCP requires a secure context. HTTPS and trustworthy localhost development origins can satisfy this requirement. Browser flags or origin-trial enrollment can also be necessary.

  Tools belong to live documents. WebMCP does not provide an always-reachable MCP server or persistence. Tool implementations can still call existing servers and persist application data.

  Userland libraries named `webmcp.js` are separate projects. Do not substitute their APIs for the browser API.

  ## 2. Choose the API

  Read the existing action and its authorization flow before adding a tool.

  - For an action that an existing HTML form completes, prefer the declarative API.
  - For other actions, use the imperative API.
  - For pages with both kinds of actions, combine both APIs.

  Reuse existing application actions, validation, and state management. Do not implement a second business-logic path for agents.

  The website must remain usable without WebMCP.

  ## 3. Annotate forms

  Add these attributes to the `<form>` element:

  | Attribute | Purpose |
  | --- | --- |
  | `toolname` | Required tool name. |
  | `tooldescription` | Required description of the action. |
  | `toolautosubmit` | Optional automatic submission after the agent fills the form. |

  Add `toolparamdescription` to controls that need extra explanation. Otherwise, Chrome uses the associated label, then `aria-description`.

  Use standard control names, labels, types, and constraints. Chrome derives the input schema from the form.

  ```html
  <form toolname="support_request"
        tooldescription="Submit a customer support request."
        action="/support"
        method="post">
    <label for="support-message">Message</label>
    <textarea id="support-message" name="message" required
              toolparamdescription="Describe the problem and the help you need."></textarea>
    <button type="submit">Send request</button>
  </form>
  ```

  Keep existing server-side validation and CSRF protection. The example omits application-specific CSRF fields.

  Without `toolautosubmit`, the user submits the populated form. Use this review step for sensitive actions. Automatic submission can navigate unless the existing submit handler prevents it.

  `toolparamtitle` is not documented in the current Chrome declarative reference. Do not depend on it without evidence for the target browser.

  ### Forms with JavaScript submission

  Integrate with the existing submit handler. Do not add a competing handler that submits the same action twice.

  For agent submissions, `SubmitEvent.agentInvoked` is true. After `preventDefault()`, `respondWith(Promise<any>)` supplies the tool result.

  ```javascript
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    // Existing application function: validate, submit, update UI, and return a result.
    const result = submitThroughExistingApplicationFlow(form);
    if (event.agentInvoked) {
      event.respondWith(result);
    }
  });
  ```

  The application function must return a promise. Its normal UI path must handle failures for human submissions too.

  Call `respondWith` during the submit event handler, not after an `await`. Report success only after the action completes.

  Optional integration points:

  - Window events: `toolactivated` and `toolcancel`, each with `toolName`.
  - CSS states: `:tool-form-active` and `:tool-submit-active`.

  Keep a visible focus indicator when customizing these states.

  ## 4. Register imperative tools

  Use `document.modelContext`, not `navigator.modelContext`.

  Feature-detect before registration. Await registration so failures remain visible to the application's initialization error handler.

  ```javascript
  async function registerTodoTool() {
    if (!('modelContext' in document)) return;

    await document.modelContext.registerTool({
      name: 'add_todo',
      description: 'Add one item to the current user’s to-do list.',
      inputSchema: {
        type: 'object',
        properties: {
          text: { type: 'string', description: 'The to-do item text.' },
        },
        required: ['text'],
        additionalProperties: false,
      },
      execute: async ({ text }, { signal }) => {
        if (typeof text !== 'string' || text.trim() === '') {
          throw new TypeError('Provide nonempty to-do text.');
        }
        signal.throwIfAborted();
        // Existing application action: persist the item and update the visible UI.
        await addTodoThroughExistingApplicationFlow(text.trim(), { signal });
        return `Added "${text.trim()}" to the list.`;
      },
    });
  }
  ```

  Call and await this setup function from the existing application initialization flow. Adapt application helper names to the project.

  ### Tool definition

  | Field | Requirement |
  | --- | --- |
  | `name` | Required. Unique within the registering context. Use 1–128 ASCII letters, digits, `_`, `-`, or `.`. |
  | `description` | Required, nonempty description of the action. |
  | `title` | Optional human-readable label. |
  | `inputSchema` | Optional JSON Schema object. Define an object schema for tools with arguments. |
  | `execute` | Required callback: `async (input, { signal }) => result`. |
  | `annotations` | Optional behavior hints. |

  The callback receives parsed arguments, not a JSON string. Its second argument contains an execution `AbortSignal`, not a confirmation client.

  Return a concise string or another JSON-serializable value. The browser serializes the result for the caller. Do not assume the result preserves JavaScript object identity.

  Use an accurate schema. Validate inputs again in application code and at server trust boundaries.

  ### Lifecycle and cancellation

  Use a registration signal to remove tools when their UI context ends:

  ```javascript
  const registration = new AbortController();
  await document.modelContext.registerTool(checkoutTool, {
    signal: registration.signal,
  });

  // Component cleanup or departure from checkout:
  registration.abort();
  ```

  The registration signal controls tool availability. The callback's signal controls an individual execution.

  Pass execution signals to cancellable operations such as `fetch`. Cancellation does not undo an action that the server already committed.

  Chrome documents independent unregistering without cancellation of in-flight executions from Chrome 153. Do not assume this behavior in older versions.

  ## 5. Protect sensitive actions

  Require explicit approval before payments, messages, deletion, or other consequential actions. Use the application's existing accessible confirmation UI.

  The confirmation flow must return an explicit approval result. A resolved promise alone does not prove approval.

  ```javascript
  // Tool callback fragment. These helpers belong to the existing application.
  execute: async (input, { signal }) => {
    const action = await validateAndDescribeAction(input, { signal });
    const approved = await showActionConfirmation(action, { signal });
    if (approved !== true) return 'Cancelled. No changes were made.';

    signal.throwIfAborted();
    const result = await performAuthorizedAction(action, { signal });
    return result;
  }
  ```

  Bind approval to the exact action and parameters. Await completion before reporting success. For irreversible operations, retain server-side safeguards against duplicate execution.

  Do not call `client.requestUserInteraction()`. It is absent from the current draft callback interface. Chrome's security page still mentions it, unlike the updated imperative reference.

  ### Annotations

  | Annotation | Meaning |
  | --- | --- |
  | `readOnlyHint` | The tool reads data without modifying application state. |
  | `untrustedContentHint` | The output includes untrusted content, such as user reviews. |
  | `consequentialHint` | The tool causes significant, real-world, or non-reversible effects. |
  | `debugging` | Draft annotation for developer tools, not normal user actions. Check browser support before use. |

  These booleans default to false. Chrome's imperative reference documents the first three.

  Annotations are hints, not authorization or confirmation enforcement. Never use them as the only protection.

  ### Authorization and data

  - Permit only actions authorized for the current user.
  - Preserve server-side authentication, authorization, validation, and CSRF protection.
  - Do not restrict all tools to anonymous capabilities. Authenticated tools are valid.
  - Treat tool input and external content as untrusted data.
  - Return only data necessary for the action. Exclude credentials and unrelated private information.
  - Keep the visible UI consistent with the completed action.
  - Preserve human access to every normal application feature.

  ## 6. Discover and execute tools

  `getTools()` returns descriptors that callers can pass to `executeTool()`.

  ```javascript
  const tools = await document.modelContext.getTools();
  const tool = tools.find((candidate) => candidate.name === 'add_todo');
  if (!tool) throw new Error('The add_todo tool is not available.');

  const result = await document.modelContext.executeTool(tool, {
    text: 'Buy milk',
  });
  console.log(result);
  ```

  Pass an argument object, not a JSON string. Execution performs the real action. It is not a dry run.

  `executeTool` accepts an optional third argument, `{ signal }`, for cancellation. Chrome documents a null result when execution triggers navigation.

  Listen for changes when maintaining a tool list:

  ```javascript
  document.modelContext.addEventListener('toolchange', refreshAvailableTools);
  ```

  ### Cross-origin frames

  By default, discovery exposes authorized same-origin tools in the frame tree. Cross-origin access requires explicit configuration.

  1. Delegate registration through the `tools` Permissions Policy:

     ```html
     <iframe src="https://partner.example" allow="tools"></iframe>
     ```

  2. In the tool's document, permit the calling origin:

     ```javascript
     await document.modelContext.registerTool(sharedTool, {
       exposedTo: ['https://app.example'],
     });
     ```

  3. In the caller, request the tool's origin:

     ```javascript
     const tools = await document.modelContext.getTools({
       fromOrigins: ['https://partner.example'],
     });
     ```

  Both origin lists require secure origins. Expose tools only to explicitly trusted origins. Frame access does not replace application authorization.

  ## 7. Verify the implementation

  Use a development account and reversible data for execution tests.

  - Verify that the website works with WebMCP unavailable.
  - Verify registration and discovery in the target browser version.
  - Verify valid inputs, invalid inputs, authorization failures, and server failures.
  - Verify that success appears only after the action completes.
  - Verify that declined confirmation causes no mutation.
  - Verify that approval applies to the exact submitted action.
  - Verify execution cancellation without assuming transaction rollback.
  - Verify tool cleanup across component changes and navigation.
  - Verify that retries do not duplicate consequential actions.
  - Verify cross-origin restrictions if frames expose tools.
  - Verify declarative form review, submission, and result handling.
  - Verify that tool results and visible application state agree.

  Use the project's existing tests for application behavior. Use browser integration checks for the experimental API itself.

  ## Tool-writing rules

  - Give each tool one clear purpose.
  - Distinguish completed actions from workflows that only open a form.
  - Describe inputs with real types and explicit allowed values.
  - Use `enum` as a schema constraint, not as a JSON Schema type.
  - Accept user-oriented input instead of requiring agents to perform unnecessary conversions.
  - Return actionable errors without secrets or invented success claims.
  - Register state-specific tools only while their actions are available.

  ## Migration checklist

  For older examples:

  - Replace `navigator.modelContext` with `document.modelContext`.
  - Move feature detection to `document`.
  - Await `registerTool` and handle rejected registration.
  - Replace JSON-string execution arguments with objects.
  - Replace the callback's confirmation client with `{ signal }`.
  - Replace `requestUserInteraction` with explicit application confirmation.
  - Add `consequentialHint` where appropriate, without removing application safeguards.
  - Remove reliance on undocumented `toolparamtitle` behavior.

  Do not add a compatibility shim unless the user requires older browser versions. Recheck the official references before shipping.
  """

  def up do
    execute("""
    INSERT INTO skills (id, name, description, content, inserted_at, updated_at)
    VALUES (
      '#{@skill_id}',
      'webmcp',
      'Implement WebMCP tools and HTML forms for browser agents, including registration, confirmation, cancellation, testing, and migration to document.modelContext.',
      $skill$#{@content}$skill$,
      NOW(),
      NOW()
    )
    ON CONFLICT (name) DO NOTHING
    """)
  end

  def down do
    execute("DELETE FROM skills WHERE id = '#{@skill_id}'")
  end
end
