---
name: refactoring-patterns
description: >
  Comprehensive catalog of code smells and refactoring patterns. Covers structural,
  complexity, duplication, design principle, and naming smells with detection criteria,
  impact analysis, and actionable refactoring strategies. Load this when analyzing
  code for refactoring opportunities during review.
---

# Refactoring Patterns -- Code Smells & Fixes

---

## Structural Smells

### Extract Function

**Detect:** Function >30 LOC, nesting >3 levels, or inline comments labeling blocks.

**Problem:** Hard to test, name, and reason about. Multiple hidden responsibilities.

**Refactor:** Extract cohesive blocks into named functions. The name replaces the comment.

```
// BEFORE
function processOrder(order) {
  // validate ... (15 lines)
  // calculate total ... (12 lines)
  // persist ... (10 lines)
}

// AFTER
function processOrder(order) {
  validateOrder(order);
  const total = calculateTotal(order.items);
  persistOrder(order, total);
}
```

### Extract Component

**Detect:** JSX >80 LOC, multiple UI sections, or state used by only one section.

**Problem:** Can't reuse, test in isolation, or optimize re-render boundaries.

**Refactor:** Split by visual section. Colocate state with its owning component.

```
// BEFORE — one component, three jobs, 200+ lines
function UserDashboard({ user }) { /* profile + orders + notifications */ }

// AFTER
function UserDashboard({ user }) {
  return (<>
    <UserProfile user={user} />
    <UserOrders userId={user.id} />
    <UserNotifications userId={user.id} />
  </>);
}
```

### God Class / God Module

**Detect:** >300 LOC, >5 responsibilities, or imported by >10 modules.

**Problem:** One change risks breaking unrelated features. High coupling radiates outward.

**Refactor:** Group by responsibility, extract each cluster into its own module.

```
// BEFORE — utils.ts (500 LOC, imported everywhere)
export { formatDate, formatCurrency, validateEmail, validatePhone, slugify, debounce }

// AFTER — split by domain
// formatters/date.ts, formatters/currency.ts
// validators/email.ts, validators/phone.ts
// strings/slugify.ts, async/debounce.ts
```

### Feature Envy

**Detect:** Method reads/writes more fields from another object than its own.

**Problem:** Logic in the wrong place. Data and behavior separated.

**Refactor:** Move the method to the class that owns the data.

```
// BEFORE — Invoice reaches into Customer internals
class Invoice {
  discount(c) { return c.tier === 'gold' && c.years > 5 ? c.base * 1.5 : c.base; }
}

// AFTER — Customer owns its own logic
class Customer {
  effectiveDiscount() { return this.tier === 'gold' && this.years > 5 ? this.base * 1.5 : this.base; }
}
```

### Shotgun Surgery

**Detect:** One logical change requires edits in >3 files. Same literal scattered everywhere.

**Problem:** Easy to miss one spot. Every change is a regression minefield.

**Refactor:** Centralize with a registry, config object, or strategy pattern.

```
// BEFORE — adding a role means editing auth.ts, sidebar.ts, api.ts, middleware.ts...

// AFTER — single config
const ROLES = {
  admin:  { permissions: ['*'],            nav: ['dashboard', 'settings'] },
  editor: { permissions: ['read', 'write'], nav: ['dashboard'] },
};
// All consumers read from ROLES. Add a role = edit one object.
```

---

## Complexity Smells

### High Cyclomatic Complexity

**Detect:** >10 branches (if/else, switch, ternaries, catch, logical operators).

**Problem:** Exponential test cases. Hard to trace execution mentally.

**Refactor:** Replace conditionals with lookup tables or polymorphism.

```
// BEFORE — 12 branches
function price(type, size) {
  if (type === 'pizza') { if (size === 'large') ... else if ... }
  else if (type === 'pasta') { ... }
}

// AFTER
const PRICES = { pizza: { large: 15, medium: 12 }, pasta: { large: 13, medium: 10 } };
function price(type, size) { return PRICES[type]?.[size] ?? throwUnknown(type, size); }
```

### Deep Nesting

**Detect:** Indentation >4 levels. Nested if/for/try blocks.

**Problem:** Readers lose track of context. Testing inner branches requires all outer conditions.

**Refactor:** Guard clauses (early returns), extract inner blocks, invert conditions.

```
// BEFORE — 5 levels deep
function process(req) {
  if (req.user) { if (req.user.isActive) { if (req.body) { if (req.body.items.length > 0) {
    // actual logic
  }}}}
}

// AFTER
function process(req) {
  if (!req.user) return;
  if (!req.user.isActive) return;
  if (!req.body?.items?.length) return;
  // actual logic at top level
}
```

### Long Parameter List

**Detect:** >4 function params, >5 constructor params.

**Problem:** Unreadable call sites. Easy to swap same-type arguments.

**Refactor:** Parameter object or builder pattern.

```
// BEFORE
createUser(name, email, role, team, startDate, manager, location);

// AFTER
createUser({ name, email, role, team, startDate, manager, location });
```

### Boolean Blindness

**Detect:** >2 boolean params, or call sites like `doThing(true, false, true)`.

**Problem:** Callers can't tell what each boolean means without checking the signature.

**Refactor:** Options object with named fields.

```
// BEFORE
renderChart(data, true, false, true);

// AFTER
renderChart(data, { showLegend: true, animate: false, interactive: true });
```

### Complex Conditionals

**Detect:** Nested ternaries (>1 level), if-else chains >4 branches, multi-line booleans.

**Problem:** Cognitive overhead. Easy to introduce logic errors.

**Refactor:** Named booleans, lookup tables, or polymorphism.

```
// BEFORE
const label = status === 'active' ? 'Active' : status === 'pending' ? 'Pending' : 'Unknown';

// AFTER
const STATUS_LABELS = { active: 'Active', pending: 'Pending', expired: 'Expired' };
const label = STATUS_LABELS[status] ?? 'Unknown';
```

---

## Duplication Smells

### Code Clones

**Detect:** >5 lines with >80% structural similarity. Tools: jscpd, PMD CPD, Semgrep.

**Problem:** Bug fixed in one clone but not the other. Maintenance multiplies.

**Refactor:** Extract shared logic, parameterize differences.

```
// BEFORE — handleCreateUser and handleCreateAdmin are 90% identical

// AFTER
function handleCreateAccount(req, overrides = {}, auditEvent = 'user.created') {
  validate(req.body);
  const entity = { ...mapToEntity(req.body), createdAt: new Date(), ...overrides };
  await db.insert('users', entity);
  audit.log(auditEvent, entity.id);
  return { status: 201, data: entity };
}
```

### Duplicate SQL CTEs

**Detect:** Same CTE copy-pasted across multiple queries.

**Problem:** Schema change breaks N queries. Copies diverge silently.

**Refactor:** Extract into a view or shared query builder.

```
-- BEFORE — same CTE in 4 queries
WITH active_users AS (SELECT id, name FROM users WHERE status = 'active' AND deleted_at IS NULL)

-- AFTER
CREATE VIEW active_users AS SELECT id, name FROM users WHERE status = 'active' AND deleted_at IS NULL;
```

### Copy-Paste Components

**Detect:** Two components with >70% similar markup but minor prop/style differences.

**Problem:** UI inconsistency as copies diverge. Design updates require N edits.

**Refactor:** Single configurable component with variants.

```
// BEFORE — SuccessAlert and ErrorAlert nearly identical
// AFTER
function Alert({ message, variant }) {
  const icons = { success: 'check', error: 'x', warning: 'exclamation' };
  return <div className={`alert alert-${variant}`}><Icon name={icons[variant]} /> {message}</div>;
}
```

### Repeated Error Handling

**Detect:** Same try/catch pattern in >3 functions.

**Problem:** Inconsistent responses when one copy is updated. Boilerplate drowns logic.

**Refactor:** Centralize in middleware, decorator, or wrapper function.

```
// BEFORE — every handler: try { ... } catch { if NotFound 404; if Validation 400; else 500 }

// AFTER — handlers just throw; errorMiddleware maps error type -> status code globally
async function getUser(req, res) {
  res.json(await userService.find(req.params.id));
}
```

---

## Design Principle Smells

### SRP Violation

**Detect:** Module has >2 unrelated reasons to change. Imports from different domains
(e.g., `fs` + `http` + `crypto`).

**Problem:** Changes for one concern risk breaking another. Tests require unrelated mocks.

**Refactor:** Split into focused modules, one per responsibility.

```
// BEFORE — UserService handles auth + profile + email
// AFTER
class AuthService { login, resetPassword }
class ProfileService { updateProfile, getProfile }
class NotificationService { sendWelcomeEmail, sendPasswordResetEmail }
```

### DIP Violation

**Detect:** High-level module imports concrete implementation directly
(`import { PgUserRepo } from './pg-user-repo'`).

**Problem:** Business logic coupled to infrastructure. Testing needs real DB or heavy mocks.

**Refactor:** Depend on interface. Inject implementation.

```
// BEFORE
class UserService { private repo = new PgUserRepo(); }

// AFTER
interface UserRepository { find(id): Promise<User>; save(user): Promise<void>; }
class UserService { constructor(private repo: UserRepository) {} }
```

### ISP Violation

**Detect:** Interface >5 methods, most consumers use only 2-3. Implementors throw
`NotImplementedError`.

**Problem:** Consumers depend on methods they don't use. Unnecessary coupling.

**Refactor:** Split into focused interfaces.

```
// BEFORE — DataStore has read, write, delete, bulkImport, subscribe, getMetrics
// ReadOnlyConsumer forced to depend on write/delete

// AFTER
interface Readable  { read(id): Item; }
interface Writable  { write(item): void; delete(id): void; }
interface Importable { bulkImport(items): void; }
```

### OCP Violation

**Detect:** Adding a variant requires modifying existing code (new `else if` or `case`).

**Problem:** Extensions risk breaking existing behavior. Merge conflicts on same function.

**Refactor:** Strategy pattern, plugin registry, or polymorphism.

```
// BEFORE — edit switch for every new format
function export(data, format) { switch(format) { case 'csv': ... case 'json': ... } }

// AFTER — registry
const exporters = new Map([['csv', toCSV], ['json', toJSON]]);
function export(data, format) { return exporters.get(format)?.(data) ?? throwUnknown(format); }
// Adding YAML: exporters.set('yaml', toYAML) — no existing code modified
```

### LSP Violation

**Detect:** Subtype overrides method to throw, return different type, or silently skip.

**Problem:** Code against base type breaks with subtype. Polymorphism unreliable.

**Refactor:** If subtype can't honor base contract, don't inherit. Prefer composition.

```
// BEFORE
class Bird { fly() { return 'flying'; } }
class Penguin extends Bird { fly() { throw new Error('Cannot fly'); } } // breaks contract

// AFTER
interface Walkable { walk(): void; }
interface Flyable  { fly(): void; }
class Sparrow implements Walkable, Flyable { ... }
class Penguin implements Walkable { ... } // no broken contract
```

### Circular Dependencies

**Detect:** A imports B, B imports A. Bundler warnings, runtime `undefined`. Tools: `madge --circular`.

**Problem:** Fragile init order. Can't refactor one without the other. Bundle splitting breaks.

**Refactor:** Extract shared types into third module. Invert dependency. Use DI or events.

```
// BEFORE — user.ts imports order.ts, order.ts imports user.ts
// AFTER  — both import types.ts; order.ts accepts userId, not User object
```

### God Module

**Detect:** Single module imported by >10 others. Named `utils`, `helpers`, `common`.

**Problem:** High blast radius on any change. Constant merge conflicts. Poor tree-shaking.

**Refactor:** Split by domain. Each consumer imports from a focused module.

```
// BEFORE — helpers.ts (600 LOC, 45 exports, 22 importers)
// AFTER  — helpers/date.ts, helpers/string.ts, helpers/validation.ts (<100 LOC each)
```

---

## Naming & Clarity Smells

### Magic Numbers / Strings

**Detect:** Unlabeled literal in logic: `if (retries > 3)`, `setTimeout(fn, 86400000)`.

**Problem:** Meaning opaque. Changing requires finding every occurrence. Typos fail silently.

**Refactor:** Named constant.

```
// BEFORE
if (password.length < 8) { ... }
setTimeout(refreshToken, 3600000);

// AFTER
const MIN_PASSWORD_LENGTH = 8;
const TOKEN_REFRESH_MS = 60 * 60 * 1000;
if (password.length < MIN_PASSWORD_LENGTH) { ... }
setTimeout(refreshToken, TOKEN_REFRESH_MS);
```

### Misleading Names

**Detect:** Name implies one behavior, implementation does another. `getUser` that also
writes. `isValid` that throws.

**Problem:** Callers make wrong assumptions. Bugs hide behind "obvious" names.

**Refactor:** Rename to match behavior, or split into honest functions.

```
// BEFORE — getUser has write side effects
function getUser(id) { const u = db.find(id); u.lastAccess = new Date(); db.save(u); return u; }

// AFTER
function getUser(id) { return db.find(id); }
function recordUserAccess(id) { const u = db.find(id); u.lastAccess = new Date(); db.save(u); }
```

### Dead Code

**Detect:** Code after unconditional return, unused exports, uncalled functions.
Tools: `ts-prune`, `knip`, ESLint `no-unused-vars`.

**Problem:** Maintenance cost for nothing. Can mask real bugs.

**Refactor:** Delete it. `git log` preserves history.

```
// BEFORE
function process(order) { return save(order); sendEmail(order); /* unreachable */ }
export function legacyMigrate() { ... } // never imported

// AFTER — both deleted
function process(order) { return save(order); }
```

### Commented-Out Code

**Detect:** Code blocks wrapped in comments with no explanation.

**Problem:** Noise. Rots silently as dependencies change. Readers wonder if it matters.

**Refactor:** Delete it. If context needed, write a prose comment explaining *why*, not the code.

```
// BEFORE
function calculate(items) {
  // const total = items.reduce((s, i) => s + i.price, 0);
  // if (total > 100) applyDiscount(total);
  return items.reduce((s, i) => s + i.finalPrice, 0);
}

// AFTER — prose, not zombie code
// Discount logic moved to CheckoutService
function calculate(items) { return items.reduce((s, i) => s + i.finalPrice, 0); }
```

---

## Quick Reference Table

| Smell | Threshold | Refactoring |
|-------|-----------|-------------|
| Long Function | >30 LOC | Extract Function |
| Large Component | >80 LOC JSX | Extract Component |
| God Class/Module | >300 LOC, >5 responsibilities | Split by domain |
| Feature Envy | Uses more external data | Move Method |
| Shotgun Surgery | 1 change -> >3 files | Registry / config |
| High Complexity | >10 branches | Lookup table / polymorphism |
| Deep Nesting | >4 levels | Guard clauses |
| Long Param List | >4 params | Parameter Object |
| Boolean Blindness | >2 boolean params | Options object |
| Complex Conditionals | Nested ternaries | Map / named booleans |
| Code Clones | >5 lines, >80% similar | Extract + parameterize |
| Duplicate CTEs | Same CTE in >2 queries | View / shared fragment |
| Copy-Paste Components | >70% similar markup | Variant-based component |
| Repeated Error Handling | Same catch >3 times | Middleware / wrapper |
| SRP Violation | >2 reasons to change | Split module |
| DIP Violation | Direct concrete import | Interface + injection |
| ISP Violation | >5 methods, partial use | Split interfaces |
| OCP Violation | Edit to extend | Strategy / registry |
| LSP Violation | Override breaks contract | Composition |
| Circular Dependency | A->B->A | Extract shared module |
| God Module | Imported by >10 | Split by domain |
| Magic Numbers | Unlabeled literals | Named constants |
| Misleading Names | Name != behavior | Rename or split |
| Dead Code | Unreachable / unused | Delete |
| Commented-Out Code | Code in comments | Delete |
