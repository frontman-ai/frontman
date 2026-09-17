import * as S from "sury";
import Ajv from "ajv";
import standaloneCode from "ajv/dist/standalone/index.js";

const textInput = (field, maxLength, description) => S.strict(S.schema({
  [field]: S.string
    .with(S.min, 1)
    .with(S.max, maxLength)
    .with(S.pattern, /\S/)
    .with(S.meta, { description }),
}));

const feedbackPrefix = "[Feedback]\n\n";
const schemas = {
  validateInput: S.strict(S.schema({})),
  validateQuestion: textInput("question", 4000, "Your question and relevant non-sensitive project context."),
  validateFeedback: textInput("feedback", 4000 - feedbackPrefix.length, "The capability gap or blocker, its impact, and what would help."),
  validateQueuedQuestion: S.schema({
    status: S.literal("queued"),
    submitted: S.literal(true),
    submission_id: S.uuid,
  }),
  validateUnavailableQuestion: S.schema({
    status: S.literal("unavailable"),
    submitted: S.literal(false),
  }),
};
const jsonSchemas = Object.fromEntries(
  Object.entries(schemas).map(([name, schema]) => [name, S.toJSONSchema(schema)]),
);

export default function webmcpValidators() {
  const id = "virtual:webmcp-validators";
  return {
    name: "webmcp-validators",
    resolveId(source) {
      if (source === id) return `\0${id}`;
    },
    load(source) {
      if (source !== `\0${id}`) return;
      const ajv = new Ajv({
        code: { source: true, esm: true },
        unicode: false,
        unicodeRegExp: false,
      });
      ajv.addFormat("uuid", /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
      for (const [name, schema] of Object.entries(jsonSchemas)) ajv.addSchema(schema, name);
      return standaloneCode(ajv, Object.fromEntries(Object.keys(schemas).map(name => [name, name]))) + `
        export const inputSchema = ${JSON.stringify(jsonSchemas.validateInput)};
        export const questionInputSchema = ${JSON.stringify(jsonSchemas.validateQuestion)};
        export const feedbackInputSchema = ${JSON.stringify(jsonSchemas.validateFeedback)};
        export const feedbackPrefix = ${JSON.stringify(feedbackPrefix)};
      `;
    },
  };
}
