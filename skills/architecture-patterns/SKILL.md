---
name: architecture-patterns
description: >
  Comprehensive catalog of architecture patterns and anti-patterns for backend,
  frontend, and system design. Covers hexagonal, clean, layered, DDD, CQRS,
  microservices, and common anti-patterns with detection heuristics and metrics.
  Load this when an arch subagent needs to evaluate structural decisions during
  code review.
---

# Architecture Patterns & Anti-Patterns Reference

---

## Hexagonal / Ports & Adapters

**What:** Domain logic at the center, isolated from infrastructure. Ports define interfaces the domain exposes (inbound) or requires (outbound). Adapters implement those interfaces for specific technologies.

**Structure:**

```
domain/          # Entities, value objects, domain services — zero imports from outside
ports/
  inbound/       # Use case interfaces (driven by the app)
  outbound/      # Repository/gateway interfaces (driven by infra)
adapters/
  inbound/       # HTTP controllers, CLI handlers, gRPC servers
  outbound/      # Postgres repos, S3 clients, email services
application/     # Use case implementations — orchestrate domain via ports
```

**When to use:** Systems where you need to swap infrastructure (DB, message broker) without touching business logic. High-testability requirements.

**Key characteristics:**
- Domain has no dependency on frameworks or infrastructure
- All dependencies point inward toward the domain
- Adapters are interchangeable (swap Postgres for DynamoDB by writing a new adapter)

**Trade-offs:**
- More boilerplate (interfaces + implementations for every boundary)
- Overkill for CRUD-heavy apps with little domain logic
- Pays off when the domain is complex or infra changes are likely

---

## Clean Architecture

**What:** Concentric layers with strict dependency rules. Inner layers know nothing about outer layers. Dependencies always point inward.

**Layers (inside → out):**
1. **Entities** — Enterprise business rules, domain objects
2. **Use Cases** — Application-specific business rules, orchestration
3. **Interface Adapters** — Controllers, presenters, gateways, DTOs
4. **Frameworks & Drivers** — DB, web framework, UI, external APIs

**When to use:** Large systems with complex business rules that need long-term maintainability. Teams that want framework independence.

**Key characteristics:**
- The Dependency Rule: source code dependencies only point inward
- Entities are plain objects — no ORM decorators, no framework annotations
- Use cases define input/output boundaries (request/response models)

**Trade-offs:**
- Significant boilerplate for mapping between layers
- Can feel over-engineered for simple CRUD
- Mapping DTOs at each boundary is tedious but prevents leaking

**Detection (violations):**
```
# Entity importing from infrastructure — violation
import { Column, Entity } from 'typeorm';  // framework in domain layer

# Use case returning an ORM model — violation
async execute(): Promise<UserEntity> { ... }  // should return a DTO or domain object
```

---

## Layered Architecture

**What:** Horizontal layers where each layer only calls the layer directly below it.

```
Presentation    →  Controllers, views, API endpoints
Application     →  Use cases, orchestration, DTOs
Domain          →  Entities, domain services, business rules
Infrastructure  →  Database, external APIs, file system
```

**When to use:** Default for most web applications. Simple mental model, well understood by teams.

**Key characteristics:**
- Each layer has a clear responsibility
- Strict layering: presentation never calls infrastructure directly
- Relaxed layering (common): any layer can call any lower layer

**Trade-offs:**
- Easy to understand, hard to enforce without tooling
- Tends to produce anemic domain models (logic leaks into services)
- Changes often require touching multiple layers (vertical slicing helps)

---

## MVC / MVVM

### MVC (Model-View-Controller)

**What:** Separates data (Model), presentation (View), and input handling (Controller).

**When to use:** Server-rendered web apps, REST APIs (controller = handler).

**Key characteristics:**
- Controller receives request, invokes model, selects view
- Model encapsulates data and business rules
- View renders output (HTML, JSON)

### MVVM (Model-View-ViewModel)

**What:** View binds to a ViewModel that exposes data and commands. ViewModel transforms Model data for display.

**When to use:** Frontend frameworks with data binding (Angular, SwiftUI, WPF). React with hooks acts like MVVM where custom hooks = ViewModel.

**Trade-offs:**
- MVC: simple but controllers tend to bloat (fat controller anti-pattern)
- MVVM: clean separation but data binding can obscure data flow

---

## Event-Driven / CQRS

### Event-Driven Architecture

**What:** Components communicate through events. Producers emit events, consumers react to them. Loose coupling.

**When to use:** Systems that need to react to state changes across boundaries. Audit trails. Async processing.

**Key characteristics:**
- Events are immutable facts about what happened (past tense: `OrderPlaced`, `UserCreated`)
- Publishers don't know about subscribers
- Eventually consistent by nature

### CQRS (Command Query Responsibility Segregation)

**What:** Separate models for reading and writing. Commands mutate state, queries read state. Different data models optimized for each.

**When to use:** Read/write ratio heavily skewed. Complex read models that don't match write models. High-performance read requirements.

**Trade-offs:**
- Eventual consistency adds complexity (UI must handle stale reads)
- Two models to maintain instead of one
- Powerful when combined with Event Sourcing, but that adds even more complexity
- Don't use CQRS if your reads and writes use the same model — it's just extra indirection

---

## Microservices vs Monolith vs Modular Monolith

| Aspect | Monolith | Modular Monolith | Microservices |
|--------|----------|-------------------|---------------|
| Deployment | Single unit | Single unit | Independent |
| Boundaries | Implicit (packages) | Explicit (modules with APIs) | Physical (network) |
| Data | Shared DB | Separate schemas, shared DB | Separate DBs |
| Complexity | Low ops, high coupling risk | Moderate | High ops, low coupling |
| Team scale | 1-3 teams | 2-5 teams | 5+ teams |

**Modular Monolith — the sweet spot for most:**
- Enforce module boundaries at compile time (internal packages, visibility modifiers)
- Each module owns its schema/tables — no cross-module table joins
- Modules communicate through public APIs or in-process events
- Can extract to microservice later if a module needs independent scaling

**When to choose microservices:**
- Independent deployment is a hard requirement
- Teams need full autonomy (different languages, different release cycles)
- Specific modules have drastically different scaling needs

---

## Repository Pattern

**What:** Abstraction over data access. Domain code talks to a repository interface, infrastructure provides the implementation.

```typescript
// Port (domain layer)
interface UserRepository {
  findById(id: UserId): Promise<User | null>;
  save(user: User): Promise<void>;
}

// Adapter (infrastructure layer)
class PostgresUserRepository implements UserRepository {
  async findById(id: UserId): Promise<User | null> {
    const row = await this.db.query('SELECT * FROM users WHERE id = $1', [id.value]);
    return row ? UserMapper.toDomain(row) : null;
  }
}
```

**When to use:** Any non-trivial application. Enables testing without a database.

**Key characteristics:**
- Repository returns domain objects, not ORM entities or raw rows
- One repository per aggregate root (DDD)
- Keep repository methods focused — avoid query-builder-style APIs

**Trade-offs:**
- Extra layer of mapping (ORM entity ↔ domain entity)
- Generic repositories (`CrudRepository<T>`) leak abstraction — prefer specific methods

---

## Service Layer Pattern

**What:** Thin layer that orchestrates domain logic and infrastructure. Defines application boundary and transaction scope.

```typescript
class CreateOrderService {
  constructor(
    private orderRepo: OrderRepository,
    private paymentGateway: PaymentGateway,
    private eventBus: EventBus,
  ) {}

  async execute(cmd: CreateOrderCommand): Promise<OrderId> {
    const order = Order.create(cmd.items, cmd.customer);  // domain logic
    await this.paymentGateway.charge(order.total);         // infrastructure
    await this.orderRepo.save(order);                      // persistence
    this.eventBus.publish(new OrderCreated(order.id));     // events
    return order.id;
  }
}
```

**When to use:** When you need to coordinate multiple domain objects and infrastructure concerns in a single operation.

**Key characteristics:**
- Thin: orchestration only, no business rules (those live in domain)
- Defines transaction boundaries
- Maps between external DTOs and domain objects

**Trade-offs:**
- If services contain business logic → anemic domain model
- If services are too granular → service explosion

---

## Frontend Architecture Patterns

### Feature-based vs Layer-based Organization

```
# Layer-based (traditional — doesn't scale)
src/
  components/     # 50+ files, mixed concerns
  hooks/
  services/
  utils/

# Feature-based (recommended for apps with 10+ features)
src/
  features/
    auth/
      components/
      hooks/
      api/
      types.ts
      index.ts      # public API — only import from here
    orders/
      components/
      hooks/
      api/
      types.ts
      index.ts
  shared/           # truly shared utilities, components, types
```

**When to use feature-based:** As soon as the app has distinct functional areas. Makes code ownership clear. Enables lazy loading per feature.

**Detection of bad organization:** A single `components/` folder with 30+ files. Imports crossing feature boundaries without going through an index barrel.

### Container / Presentational Components

**What:** Separate data-fetching/state logic (container) from pure rendering (presentational).

**Modern equivalent:** Custom hooks extract the container role. The component itself stays presentational.

```tsx
// Hook = container logic
function useUserProfile(id: string) {
  const { data, isLoading } = useQuery(['user', id], () => fetchUser(id));
  return { user: data, isLoading };
}

// Component = presentational
function UserProfile({ id }: { id: string }) {
  const { user, isLoading } = useUserProfile(id);
  if (isLoading) return <Skeleton />;
  return <ProfileCard user={user} />;
}
```

### State Management Patterns

| Scope | Tool | When |
|-------|------|------|
| Component-local | `useState` / `useReducer` | Form inputs, toggles, ephemeral UI |
| Shared subtree | React Context | Theme, auth, locale — low-frequency updates |
| Global / complex | Zustand, Redux, Jotai | Server cache, cross-feature state, frequent updates |
| Server state | TanStack Query, SWR | API data with caching, refetching, optimistic updates |

**Anti-pattern:** Putting everything in global state. If only one component uses it, keep it local.

### Routing & Code Splitting

- **Route-based splitting:** Each route loads its feature module lazily
- **Nested layouts:** Share chrome (nav, sidebar) without re-rendering on navigation
- **Prefetching:** Preload next-likely route on hover/focus for perceived performance

### Design System / Token Architecture

```
tokens/
  colors.ts       # primitive values: blue-500, gray-100
  spacing.ts      # 4px scale: space-1 = 4px, space-2 = 8px
  typography.ts   # font sizes, line heights, weights
themes/
  light.ts        # semantic tokens: color-bg-primary = white
  dark.ts         # semantic tokens: color-bg-primary = gray-900
components/
  Button/         # consumes semantic tokens, never primitives directly
```

**Key rule:** Components reference semantic tokens, not primitives. This makes theming possible.

---

## Backend Architecture Patterns

### Handler → Service → Repository

```
Handler (Controller)     Receives HTTP/gRPC request, validates input, calls service
       ↓
Service (Use Case)       Orchestrates business logic, transaction boundaries
       ↓
Repository (Data)        Abstracts persistence, returns domain objects
```

**Rules:**
- Handlers never access repositories directly
- Services never import HTTP/transport concerns
- Repositories never contain business logic

**Detection of violations:**
- Handler with `db.query()` calls → skipping service + repo layers
- Service importing `express.Request` → transport leaking into business logic
- Repository with `if (order.total > 100)` → business logic in data layer

### Domain-Driven Design (DDD)

**Bounded Contexts:** Separate models for separate business areas. A `User` in the Auth context ≠ `User` in the Billing context. Each context has its own ubiquitous language.

**Aggregates:** Cluster of domain objects treated as a unit for consistency. One entity is the aggregate root — all external access goes through it.

```typescript
// Order is the aggregate root
class Order {
  private items: OrderItem[] = [];

  addItem(product: Product, quantity: number): void {
    // invariant: max 50 items per order
    if (this.items.length >= 50) throw new OrderLimitExceeded();
    this.items.push(OrderItem.create(product, quantity));
  }

  get total(): Money {
    return this.items.reduce((sum, i) => sum.add(i.subtotal), Money.zero());
  }
}

// BAD: modifying items from outside the aggregate
order.items.push(new OrderItem(...)); // bypasses invariant
```

**Value Objects:** Immutable, compared by value, no identity.

```typescript
class Money {
  constructor(readonly amount: number, readonly currency: string) {
    if (amount < 0) throw new InvalidMoney();
  }
  add(other: Money): Money {
    if (this.currency !== other.currency) throw new CurrencyMismatch();
    return new Money(this.amount + other.amount, this.currency);
  }
  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }
}
```

### Dependency Injection

**What:** Dependencies are provided from outside rather than created inside.

```typescript
// BAD: hard-coded dependency
class OrderService {
  private repo = new PostgresOrderRepository(); // coupled to Postgres
}

// GOOD: injected dependency
class OrderService {
  constructor(private repo: OrderRepository) {} // depends on interface
}

// Composition root (entry point) wires everything
const repo = new PostgresOrderRepository(db);
const service = new OrderService(repo);
const handler = new OrderHandler(service);
```

**Patterns:**
- **Constructor injection** (preferred): dependencies in constructor params
- **Module-based DI** (Node.js): factory functions that accept dependencies
- **DI container** (NestJS, Spring): framework manages object graph — convenient but magical

### API Versioning Strategies

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| URL path | `/api/v2/users` | Explicit, easy to route | URL pollution, hard to deprecate |
| Header | `Accept: application/vnd.api.v2+json` | Clean URLs | Hidden, harder to test |
| Query param | `/api/users?version=2` | Easy to test | Messy, optional params |

**Recommendation:** URL path versioning for public APIs (explicit, discoverable). Header versioning for internal APIs (cleaner).

### Database Access Patterns

| Pattern | Description | When |
|---------|-------------|------|
| **Repository** | Interface abstracting data access, returns domain objects | DDD, testability |
| **Unit of Work** | Tracks changes across multiple repos, commits atomically | Complex transactions |
| **Active Record** | Object maps to a row, has `save()`/`find()` methods | Simple CRUD, rapid prototyping |
| **Data Mapper** | Separate mapper converts between DB rows and objects | Complex domains, clean separation |
| **Query Object** | Encapsulates a single query as an object | Complex reporting, read models |

---

## Anti-Patterns

### God Module / God Class

**What:** A single module/class that does too much. Attracts all logic, grows unbounded.

**Detection:**
- File exceeds 500 LOC
- More than 10 modules import from it
- Class has 20+ methods or 10+ dependencies
- Name is vague: `Utils`, `Helpers`, `Manager`, `Service` (without qualifier)

**Fix:** Extract cohesive groups of functionality into focused modules. Apply Single Responsibility Principle.

### Circular Dependencies

**What:** Module A imports B, B imports A (directly or transitively).

**Detection:**
- Build tools warn about cycles (`madge --circular`)
- Runtime errors: `undefined` imports at startup (CommonJS)

**Fix:**
- Extract shared types into a third module
- Invert the dependency (depend on an interface in a shared layer)
- Merge modules if they're truly one concept

### Service Locator

**What:** A global registry that components query at runtime for dependencies, instead of receiving them via injection.

```typescript
// BAD: service locator
class OrderService {
  process() {
    const repo = ServiceLocator.get<OrderRepository>('orderRepo'); // hidden dependency
  }
}

// GOOD: explicit injection
class OrderService {
  constructor(private repo: OrderRepository) {} // visible, testable
}
```

**Why it's bad:** Hides dependencies, makes testing harder, runtime failures instead of compile-time errors.

### Anemic Domain Model

**What:** Domain objects are pure data holders (getters/setters) with all logic in services.

```typescript
// ANEMIC: entity is just a bag of data
class Order {
  items: OrderItem[];
  status: string;
  total: number;
}

// All logic in service
class OrderService {
  calculateTotal(order: Order) { ... }
  canCancel(order: Order) { ... }
  addItem(order: Order, item: OrderItem) { ... }
}

// RICH: entity encapsulates behavior
class Order {
  private _items: OrderItem[];

  addItem(item: OrderItem): void { /* validation + mutation */ }
  cancel(): void { /* checks invariants */ }
  get total(): Money { /* calculated from items */ }
}
```

**Detection:** Entity classes with only public fields and no methods. Services with methods that take an entity as first argument.

### Big Ball of Mud

**What:** No discernible architecture. Everything depends on everything. No module boundaries.

**Detection:**
- Any file can import from any other file
- No clear layering or feature boundaries
- Changing one thing breaks unrelated things
- Dependency graph looks like a hairball

**Fix:** Incrementally introduce boundaries. Start by defining modules and restricting imports.

### Leaky Abstraction (Infrastructure in Domain)

**What:** Domain layer depends on infrastructure concerns.

```typescript
// BAD: domain entity knows about SQL
class UserService {
  async findActive(): Promise<User[]> {
    return this.db.query('SELECT * FROM users WHERE active = true'); // SQL in domain
  }
}

// BAD: domain entity decorated with ORM
@Entity()
class User {
  @Column() name: string;  // TypeORM in domain
}

// GOOD: domain defines interface, infra implements
interface UserRepository { findActive(): Promise<User[]>; }
```

**Detection:** Domain or application layer files importing from `pg`, `typeorm`, `mongoose`, `aws-sdk`, `express`, or any infrastructure package.

### Distributed Monolith

**What:** Microservices that are tightly coupled — you must deploy them together, they share a database, or they make synchronous call chains.

**Detection:**
- Deploying service A requires deploying B at the same time
- Services share database tables
- Request flows through 5+ synchronous service calls
- A single business transaction spans multiple services without saga/choreography

**Fix:** Either merge back into a monolith (simpler) or properly decouple with async events, separate databases, and clear contracts.

---

## Architecture Metrics

### Fan-in / Fan-out

- **Fan-in:** Number of modules that depend on this module (importers)
- **Fan-out:** Number of modules this module depends on (imports)
- High fan-in = widely used (stable abstractions should have high fan-in)
- High fan-out = lots of dependencies (fragile, hard to test)

### Instability (I)

```
I = Fan-out / (Fan-in + Fan-out)
```

- `I = 0` → maximally stable (everyone depends on it, it depends on nothing)
- `I = 1` → maximally unstable (depends on everything, nothing depends on it)
- **Rule:** Depend in the direction of stability. Stable modules should be abstract.

### Abstractness (A)

```
A = Abstract types / Total types
```

- `A = 0` → fully concrete (all implementations, no interfaces)
- `A = 1` → fully abstract (all interfaces, no implementations)

### Distance from Main Sequence (D)

```
D = |A + I - 1|
```

- `D = 0` → ideal balance between abstractness and instability
- **Zone of Pain** (A≈0, I≈0): concrete and stable — hard to change, everyone depends on it
- **Zone of Uselessness** (A≈1, I≈1): abstract and unstable — no one uses these interfaces

### Cohesion Indicators

| Signal | Healthy | Unhealthy |
|--------|---------|-----------|
| LCOM (Lack of Cohesion of Methods) | Low — methods use shared fields | High — methods use disjoint fields |
| File has a single "theme" | All exports relate to one concept | Exports serve unrelated features |
| Internal vs external imports | Most imports are internal to module | Most imports come from outside |
| Reason to change | One reason (single responsibility) | Multiple unrelated reasons |

### Quick Reference Thresholds

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| File LOC | < 300 | 300-500 | > 500 |
| Fan-out per module | < 8 | 8-15 | > 15 |
| Fan-in (non-utility) | < 15 | 15-30 | > 30 |
| Circular dependency chains | 0 | 1-2 | > 2 |
| Max dependency depth | < 5 | 5-8 | > 8 |
| Instability of core domain | < 0.3 | 0.3-0.5 | > 0.5 |
