# Reference: Language — JavaScript / Node.js

Consult during Phase 3 when the project is written in JavaScript or TypeScript running on Node.js,
regardless of framework (Express, Fastify, NestJS, etc.).

---

## Module System

- Detect which module system the project uses before writing any import/export:
  - `"type": "module"` in `package.json` → ESM (`import`/`export`)
  - No `"type"` or `"type": "commonjs"` → CJS (`require`/`module.exports`)
  - TypeScript project → follow `tsconfig.json` `module` and `moduleResolution` settings
- Never mix ESM and CJS in the same file. Never use `require()` in an ESM file.
- Named exports over default exports (except React components and Next.js pages/routes).

---

## Async Patterns

- `async/await` over `.then()/.catch()` chains — always.
- Wrap the top-level entry point in an async IIFE or use `--experimental-vm-modules` for ESM:
  ```js
  // ESM top-level await is fine in .mjs or "type":"module" packages
  const result = await fetchData();
  ```
- For concurrent independent operations, use `Promise.all([...])` rather than sequential awaits:
  ```js
  // prefer
  const [user, orders] = await Promise.all([getUser(id), getOrders(id)]);
  // over two sequential awaits
  ```
- Never `await` inside a loop unless iterations are intentionally sequential. Use `Promise.all(arr.map(...))` for parallel work.
- Unhandled promise rejections crash the process in modern Node. Always `await` or `.catch()` every promise.

---

## Error Handling

- `throw` only for genuinely unexpected states. For expected failures, return a typed result or use
  a `Result`-style pattern.
- Always handle rejected promises — attach `.catch()` to fire-and-forget promises, or `await` them inside a `try/catch`.
- Custom error classes carry context:
  ```js
  class PaymentError extends Error {
    constructor(message, { code, provider } = {}) {
      super(message);
      this.name = "PaymentError";
      this.code = code;
      this.provider = provider;
    }
  }
  ```
- In Node.js servers, use a centralised error-handling middleware (Express: `app.use((err, req, res, next) => {...})`)
  rather than catching in every route handler.

---

## Node.js Runtime Patterns

- Use `process.env` for configuration. Validate required env vars at startup — fail fast with a
  clear message rather than crashing later with `undefined` reference errors.
- `process.on('uncaughtException', ...)` and `process.on('unhandledRejection', ...)` are last
  resorts for logging — not a substitute for proper error handling.
- Prefer `node:fs/promises` (async) over synchronous `fs` methods in server code. Use sync only
  for startup/init paths.
- Use `node:path` and `node:url` (`import.meta.url`, `fileURLToPath`) for portable path resolution
  — never hardcode `/` or `\` separators.
- `node:worker_threads` for CPU-bound work; `node:child_process` for shelling out.
  Don't block the event loop with synchronous CPU work in a request handler.

---

## Package & Dependency Management

- Detect the package manager before running any install command:
  - `pnpm-lock.yaml` → `pnpm`
  - `yarn.lock` → `yarn`
  - `package-lock.json` or neither → `npm`
- Never mix package managers in one repo.
- Prefer `devDependencies` for tooling (linters, test runners, type definitions). Only `dependencies`
  for what the production runtime actually needs.
- Check `engines` field in `package.json` for the required Node version. Use `nvm use` or `fnm use`
  if `.nvmrc` / `.node-version` is present.

---

## Code Style

- `const` by default. `let` only when reassignment is required. Never `var`.
- `===` always. Never `==`.
- Destructure early: `const { id, name } = user` over repeated `user.id`, `user.name`.
- Template literals over string concatenation.
- Optional chaining (`?.`) and nullish coalescing (`??`) over manual null guards.

---

## Testing (Node.js)

- Detect the test runner before writing tests:
  - `vitest` in `package.json` → use `vitest` APIs
  - `jest` → use `jest` APIs
  - built-in `node:test` → use `test`/`assert` from stdlib
- Co-locate tests with source: `src/payments/processor.js` → `src/payments/processor.test.js`
  (or `.spec.js` — mirror existing convention).
- Mock only at system boundaries (HTTP clients, DB drivers). Do not mock your own modules — test
  the real implementation.
- Use `--experimental-vm-modules` flag for Jest with ESM projects.
