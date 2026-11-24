---
name: python-unit-tests
description: propose and implement concise, readable, maintainable python unit tests from a git diff, using repository code and existing tests as context. use when asked to test changed python code, plan unit test cases, or reduce repetitive test code and excessive mocking or fixture setup, especially for data transformations, api-related logic, and database-related logic. propose cases and wait for approval before implementation. isolate all external dependencies without real database connections or network calls. suggest refactoring only; require separate explicit approval before changing production code. follow the repository's testing framework and conventions.
---

# Python Unit Tests

## Non-negotiable boundaries

- Write unit tests, not integration tests. Never connect to a real database, including a local or in-memory database, or call a real external API. Mock database sessions, repositories, clients, and other external boundaries as needed.
- Propose test cases first and stop for explicit approval before creating or editing tests. Treat approval as applying only to the proposed scope; obtain approval for material additions.
- Never modify production code without separate, explicit approval. Approval of a test proposal does not authorize refactoring. Present refactoring suggestions separately with their rationale and tradeoffs.
- Keep tests thorough, understandable, maintainable, and concise. Prefer the smallest clear suite covering distinct behaviors, not the fewest lines at any cost.
- Use the repository and supplied context. Require no enterprise connectors or external research by default. Do not invent missing code, contracts, or execution results.

## 1. Inspect the change and existing coverage

1. Read the supplied Git diff and relevant implementation, callers, and nearby tests. If the diff is unavailable, inspect the available working-tree diff read-only; ask for the intended scope if it is ambiguous. Do not assume a base branch or include unrelated changes.
2. Inspect testing configuration and fixtures. Follow the repository's framework, naming, layout, and assertion conventions; do not assume pytest or introduce a new dependency without approval.
3. Identify changed observable behaviors and regression risks. Distinguish intended behavior from incidental implementation. Flag unclear contracts instead of encoding the current implementation as the expected result.
4. Check which cases existing tests already cover. Prefer extending an existing test or parameterization over adding redundant tests.
5. Inspect import-time side effects, autouse fixtures, plugins, and test setup for database or network access before running anything. Do not execute tests or collection that may open connections; isolate safely or report the blocker.

## 2. Propose cases and stop

Provide a brief change summary and a compact proposal with stable case IDs. For each case include:

- Target behavior and representative input or condition.
- Expected result or exception, based on a known contract.
- Distinct risk covered and whether to add, extend, or reuse a test.
- Minimal mock or fixture needs, only where relevant.

Group cases sharing the same behavior and assertion structure. Prioritize changed behavior, meaningful boundaries, and failure paths; do not impose a fixed number of tests or enumerate every possible input. State what existing tests already cover and any important uncertainty.

List optional refactoring suggestions separately. End by asking which case IDs to implement, then stop. Do not generate full test implementations or edit files during this phase.

Example proposal entry:

- **T1: Preserve zero amounts.** Input: a record with amount `0`. Expect: retain the record and numeric zero. Risk: truthiness filtering drops valid data. Extend the existing transformation parameterization; no mocks.

## 3. Implement only approved cases

- Keep production code untouched unless separately authorized. Preserve unrelated work and avoid broad formatting changes.
- Use descriptive behavior-based test names and explicit, small input and expected values. Derive expected results independently; never reproduce the production algorithm to compute the oracle.
- Keep arrange, act, and assert easy to scan without mandatory comments or abstractions. Use one coherent behavior per test; allow multiple assertions when they establish that behavior.
- Parameterize only when cases share setup and assertion structure and remain easy to diagnose. Use meaningful case IDs where supported. Avoid conditional logic inside tests, giant matrices, and tests duplicating the same behavior.
- Reuse simple existing fixtures. Prefer inline setup for one-off data. Add a fixture or helper only when it removes meaningful repetition without hiding intent; avoid deep fixture chains and broad shared-fixture changes.
- Mock external boundaries, not the unit under test or every internal helper. Patch where the dependency is looked up. Prefer explicit return values, small stubs, and autospec/spec where practical over unrestricted mock chains. Scope patches to prevent leakage.
- Assert outputs and observable effects. Assert dependency calls only when the interaction itself is part of the contract, such as rollback on failure; avoid brittle assertions about incidental call order or private methods.
- Keep tests deterministic. Control time, randomness, and environment only when needed. Do not use sleeps, credentials, live services, or real database connections.
- Do not change production behavior, weaken assertions, or remove meaningful existing tests to make the suite pass. Report suspected bugs and ask for approval before fixing them.

### Apply domain-specific judgment

- **Data transformations:** Select relevant cases for empty inputs, nulls versus zero, types, duplicates, ordering, boundaries, and mutation. Use existing dataframe or array assertion helpers when appropriate; check dtype, index, ordering, or tolerances only where the contract requires them.
- **API-related logic:** Unit-test request construction, response parsing, status handling, and error translation as relevant. Mock the transport/client boundary. Do not start servers or make network requests. Use an in-process client only if it truly isolates the target unit and cannot activate database, network, or application-lifecycle dependencies.
- **Database-related logic:** Mock the repository/session/driver boundary. Test relevant parameter passing, result mapping, missing records, and commit/rollback behavior without executing SQL or opening any database. State explicitly that these tests cannot validate real SQL semantics, schema compatibility, or transaction behavior against a database.

## 4. Validate and report

1. Review the test diff for redundant cases, excessive setup, hidden external access, and unauthorized production changes.
2. Run only relevant isolated unit tests with the repository's existing tooling when safe execution is available. Do not run the full suite blindly or install dependencies without approval.
3. Report exact commands and observed outcomes. Distinguish passed, failed, blocked, and not run; never claim execution that did not occur. Explain environmental blockers and unrelated failures separately.
4. Summarize changed test files, implemented case IDs, and remaining limitations. Keep unapproved refactoring suggestions separate. Do not claim exhaustive coverage from a passing suite.