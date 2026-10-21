import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const directory = dirname(fileURLToPath(import.meta.url));
const validatorRoot = process.env.MENTOR_M1_VALIDATOR_ROOT;
assert(validatorRoot, "Run with bash docs/contracts/mentor-m1/validate.sh.");
const require = createRequire(join(validatorRoot, "package.json"));
const Ajv2020 = require("ajv/dist/2020.js").default;
const addFormats = require("ajv-formats").default;
const ajv = new Ajv2020({ strict: true, allErrors: true });
addFormats(ajv);

const readJSON = (name) => JSON.parse(readFileSync(join(directory, name), "utf8"));
const validators = Object.fromEntries(
  ["lesson-pack", "turn", "understanding"].map((name) => [
    name,
    ajv.compile(readJSON(`${name}.schema.json`)),
  ]),
);
const turn = readJSON("fixtures/turn.valid.json");
const understanding = readJSON("fixtures/understanding.valid.json");
const lessonTemplate = readJSON("fixtures/lesson.template.json");
const themes = ["observation", "evidence", "tradeoff", "communication", "iteration", "attention"];

// These 24 in-memory copies exercise cardinality, not editorial delivery.
const pack = {
  schema_version: "1.0.0",
  pack_id: "schema-fixture-not-for-release",
  version: "0.0.0",
  lessons: Array.from({ length: 24 }, (_, index) => ({
    ...structuredClone(lessonTemplate),
    id: `L${String(index + 1).padStart(2, "0")}`,
    editorial_order: index + 1,
    theme: themes[Math.floor(index / 4)],
  })),
};

let positive = 0;
let negative = 0;
let boundaries = 0;

function check(name, schema, base, expected, mutate = () => {}, boundary = false) {
  const value = structuredClone(base);
  mutate(value);
  const validate = validators[schema];
  const actual = validate(value);
  assert.equal(actual, expected, `${name}: ${JSON.stringify(validate.errors)}`);
  if (boundary) boundaries += 1;
  else if (expected) positive += 1;
  else negative += 1;
  console.log(`${boundary ? "SCHEMA-ONLY" : "PASS"} ${name}`);
}

check("turn/material-question", "turn", turn, true);
check("turn/explain-without-question", "turn", turn, true, (v) => {
  v.action = "explain"; v.material_status = "not_needed";
  v.question = null; v.question_purpose = null;
  v.lesson_ref = { id: "L01", version: "1.0" };
  v.source_refs = ["lesson:L01@1.0"];
});
check("turn/reflection-question", "turn", turn, true, (v) => {
  v.action = "compare"; v.material_status = "usable"; v.question_purpose = "reflection";
});
check("turn/material-question-on-explain", "turn", turn, true, (v) => { v.action = "explain"; });
check("understanding/draft", "understanding", understanding, true);
check("pack/draft-structure", "lesson-pack", pack, true);
check("pack/optional-observation", "lesson-pack", pack, true, (v) => {
  v.lessons[0].observation = "A synthetic optional paragraph.";
});
check("pack/external-reference-shape", "lesson-pack", pack, true, (v) => {
  v.lessons[0].source_type = "external_reference";
  v.lessons[0].citations = [{ title: "Fixture URL only", url: "https://example.com/fixture" }];
});

check("turn/unknown-field", "turn", turn, false, (v) => { v.create_verification = true; });
check("turn/unknown-action", "turn", turn, false, (v) => { v.action = "notify"; });
check("turn/missing-schema-version", "turn", turn, false, (v) => { delete v.schema_version; });
check("turn/unknown-schema-version", "turn", turn, false, (v) => { v.schema_version = "2.0.0"; });
check("turn/unknown-material-status", "turn", turn, false, (v) => { v.material_status = "guessed"; });
check("turn/blank-body", "turn", turn, false, (v) => { v.body = " \n "; });
check("turn/multiple-question-fields", "turn", turn, false, (v) => { v.question = ["One?", "Two?"]; });
check("turn/clarify-without-question", "turn", turn, false, (v) => { v.question = null; v.question_purpose = null; });
check("turn/question-without-purpose", "turn", turn, false, (v) => { v.question_purpose = null; });
check("turn/purpose-without-question", "turn", turn, false, (v) => { v.action = "close"; v.question = null; });
check("turn/missing-material-labeled-reflection", "turn", turn, false, (v) => {
  v.action = "explain"; v.question_purpose = "reflection";
});
check("turn/malformed-source", "turn", turn, false, (v) => { v.source_refs = ["item:not-a-uuid"]; });
check("turn/duplicate-source", "turn", turn, false, (v) => { v.source_refs.push(v.source_refs[0]); });
check("turn/unversioned-lesson", "turn", turn, false, (v) => { v.lesson_ref = { id: "L01" }; });
check("turn/unknown-lesson-field", "turn", turn, false, (v) => {
  v.lesson_ref = { id: "L01", version: "1.0", generated_text: "Not approved content." };
});
check("turn/forbidden-suggestion", "turn", turn, false, (v) => { v.suggested_actions = ["create_quest"]; });
check("turn/duplicate-suggestion", "turn", turn, false, (v) => { v.suggested_actions = ["finish", "finish"]; });
check("understanding/empty-sources", "understanding", understanding, false, (v) => { v.source_refs = []; });
check("understanding/lesson-only-evidence", "understanding", understanding, false, (v) => { v.source_refs = ["lesson:L01@1.0"]; });
check("understanding/implicit-confirmation", "understanding", understanding, false, (v) => { v.confirmed = true; });
check("understanding/blank-draft", "understanding", understanding, false, (v) => { v.text = "  "; });
check("pack/too-few-lessons", "lesson-pack", pack, false, (v) => { v.lessons.pop(); });
check("pack/too-many-lessons", "lesson-pack", pack, false, (v) => { v.lessons.push(v.lessons[0]); });
check("pack/missing-boundary", "lesson-pack", pack, false, (v) => { delete v.lessons[0].boundary; });
check("pack/unknown-theme", "lesson-pack", pack, false, (v) => { v.lessons[0].theme = "career_diagnosis"; });
check("pack/invalid-editorial-order", "lesson-pack", pack, false, (v) => { v.lessons[0].editorial_order = 0; });
check("pack/malformed-hash", "lesson-pack", pack, false, (v) => { v.lessons[0].content_hash = "not-a-hash"; });
check("pack/external-reference-without-citation", "lesson-pack", pack, false, (v) => { v.lessons[0].source_type = "external_reference"; });
check("pack/teaching-example-with-external-citation", "lesson-pack", pack, false, (v) => {
  v.lessons[0].citations = [{ title: "Fixture", url: "https://example.com/fixture" }];
});
check("pack/non-web-citation", "lesson-pack", pack, false, (v) => {
  v.lessons[0].source_type = "external_reference";
  v.lessons[0].citations = [{ title: "Fixture", url: "file:///private/local-note" }];
});
check("pack/approval-without-reviewer", "lesson-pack", pack, false, (v) => { v.lessons[0].review.status = "approved"; });
check("pack/invalid-review-time", "lesson-pack", pack, false, (v) => {
  v.lessons[0].review = { status: "approved", reviewed_by: "fixture", reviewed_at: "not-a-time" };
});

// These pass Schema intentionally. They are requirements for later dynamic,
// content-pack and editorial checks, not evidence that those checks exist.
check("boundary/source-may-not-exist-in-request", "turn", turn, true, (v) => {
  v.source_refs = ["item:99999999-9999-4999-8999-999999999999"];
}, true);
check("boundary/lesson-may-not-be-eligible", "turn", turn, true, (v) => {
  v.lesson_ref = { id: "L99", version: "99.0" };
}, true);
check("boundary/recall-budget-needs-session-state", "turn", turn, true, () => {}, true);
check("boundary/direct-teaching-intent-needs-request", "turn", turn, true, () => {}, true);
check("boundary/prose-may-hide-extra-questions", "turn", turn, true, (v) => {
  v.body = "What happened? Why did it happen? What else could explain it?";
}, true);
check("boundary/source-role-and-user-authorship-unknown", "understanding", understanding, true, () => {}, true);
check("boundary/draft-meaning-may-not-match-user", "understanding", understanding, true, (v) => {
  v.text = "This synthetic sentence deliberately asserts an unsupported conclusion.";
}, true);
check("boundary/duplicate-logical-lesson-id", "lesson-pack", pack, true, (v) => { v.lessons[1].id = v.lessons[0].id; }, true);
check("boundary/duplicate-editorial-order", "lesson-pack", pack, true, (v) => { v.lessons[1].editorial_order = v.lessons[0].editorial_order; }, true);
check("boundary/unbalanced-theme-distribution", "lesson-pack", pack, true, (v) => { v.lessons[0].theme = "attention"; }, true);
check("boundary/missing-required-logical-lessons", "lesson-pack", pack, true, (v) => {
  v.lessons[0].id = "L98"; v.lessons[1].id = "L99";
}, true);
check("boundary/hash-not-recomputed", "lesson-pack", pack, true, () => {}, true);
check("boundary/draft-is-not-release-approved", "lesson-pack", pack, true, () => {}, true);
check("boundary/copied-fixtures-are-not-24-lessons", "lesson-pack", pack, true, () => {}, true);

console.log(`Validated 3 schemas with Ajv ${require("ajv/package.json").version} + ajv-formats ${require("ajv-formats/package.json").version}.`);
console.log(`PASS: ${positive} positive, ${negative} negative, ${boundaries} explicit Schema-only boundary cases.`);
console.log("No reviewed lesson pack, runtime validator, or application behavior was validated.");
