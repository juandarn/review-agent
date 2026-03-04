---
name: backend-reference
description: >
  Complete backend best practices reference covering Go, Python, SQL, and API design.
  Includes error handling, concurrency, query optimization, REST conventions, and
  common anti-patterns with before/after examples. Load this when you need to verify
  a backend pattern during code review.
---

# Backend Reference — Go, Python, SQL & API Design Best Practices

---

## Go Patterns

### Error Handling

```go
// GOOD: wrap with context
user, err := db.FindUser(ctx, id)
if err != nil {
    return fmt.Errorf("finding user %s: %w", id, err)
}

// BAD: bare return
user, err := db.FindUser(ctx, id)
if err != nil {
    return err // no context — impossible to trace in logs
}

// BAD: swallowed error
user, _ := db.FindUser(ctx, id)

// GOOD: sentinel errors
var ErrNotFound = errors.New("not found")
var ErrConflict = errors.New("conflict")

// GOOD: checking errors
if errors.Is(err, ErrNotFound) {
    return http.StatusNotFound
}

// BAD: string comparison
if err.Error() == "not found" { // fragile, breaks on wrapping
```

### Concurrency

```go
// GOOD: goroutine with lifecycle control
func (s *Service) ProcessItems(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    for _, item := range items {
        item := item // capture loop variable (Go < 1.22)
        g.Go(func() error {
            return s.processOne(ctx, item)
        })
    }
    return g.Wait()
}

// BAD: fire-and-forget goroutine
func (s *Service) ProcessItems(items []Item) {
    for _, item := range items {
        go s.processOne(item) // no error handling, no cancellation, potential leak
    }
}

// GOOD: context propagation
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    user, err := h.service.FindUser(ctx, chi.URLParam(r, "id"))
    // ...
}

// BAD: ignoring context
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    user, err := h.service.FindUser(context.Background(), id) // loses request context
}
```

### Interface Design

```go
// GOOD: small, consumer-defined interfaces
type UserReader interface {
    FindUser(ctx context.Context, id string) (*User, error)
}

type UserWriter interface {
    CreateUser(ctx context.Context, user *User) error
}

// Accept interface, return struct
func NewUserService(repo UserReader) *UserService {
    return &UserService{repo: repo}
}

// BAD: large producer-defined interface
type UserRepository interface {
    FindUser(ctx context.Context, id string) (*User, error)
    CreateUser(ctx context.Context, user *User) error
    UpdateUser(ctx context.Context, user *User) error
    DeleteUser(ctx context.Context, id string) error
    ListUsers(ctx context.Context, filter Filter) ([]*User, error)
    CountUsers(ctx context.Context) (int, error)
    // 10 more methods...
}
// Forces consumers to implement or mock everything, even if they need 1 method
```

### Naming Conventions

```go
// GOOD
type HTTPClient struct{}       // acronyms all caps
func (u *User) ID() string {} // getter: Name(), not GetName()
var userID string              // camelCase for unexported
var ErrNotFound error          // Err prefix for sentinel errors

// BAD
type HttpClient struct{}       // should be HTTPClient
func (u *User) GetID() string {} // Go doesn't use Get prefix
var userId string              // should be userID
```

### Testing

```go
// GOOD: table-driven tests
func TestParseAmount(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {name: "valid integer", input: "100", want: 100},
        {name: "valid decimal", input: "10.50", want: 1050},
        {name: "negative", input: "-5", want: 0, wantErr: true},
        {name: "empty string", input: "", want: 0, wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseAmount(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("ParseAmount(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
            }
            if got != tt.want {
                t.Errorf("ParseAmount(%q) = %v, want %v", tt.input, got, tt.want)
            }
        })
    }
}
```

### Struct Tags

```go
// GOOD: validated, consistent
type CreateUserRequest struct {
    Name  string `json:"name" validate:"required,min=1,max=100"`
    Email string `json:"email" validate:"required,email"`
    Age   int    `json:"age" validate:"gte=0,lte=150"`
}

// BAD: inconsistent or missing tags
type CreateUserRequest struct {
    Name  string // no json tag — exported as "Name" (PascalCase)
    Email string `json:"email"`
    age   int    // unexported — not serialized at all
}
```

---

## Python Patterns

### Type Hints

```python
# GOOD: full type hints
from typing import Optional, Sequence

def find_users(
    filters: dict[str, str],
    limit: int = 50,
    offset: int = 0,
) -> Sequence[User]:
    ...

# BAD: no type hints
def find_users(filters, limit=50, offset=0):
    ...

# BAD: Any type
from typing import Any
def process(data: Any) -> Any:  # defeats the purpose
    ...
```

### Error Handling

```python
# GOOD: specific exception, preserved chain
class UserNotFoundError(DomainError):
    def __init__(self, user_id: str) -> None:
        super().__init__(f"User {user_id} not found")
        self.user_id = user_id

try:
    user = await repo.find(user_id)
except DatabaseError as e:
    raise UserNotFoundError(user_id) from e  # preserves traceback

# BAD: bare except
try:
    user = await repo.find(user_id)
except:  # catches SystemExit, KeyboardInterrupt — dangerous
    pass  # silently swallowed

# BAD: too broad
try:
    user = await repo.find(user_id)
except Exception:
    return None  # which exception? why None?
```

### Mutable Default Arguments

```python
# BAD: classic Python bug
def add_item(item: str, items: list[str] = []) -> list[str]:
    items.append(item)  # mutates the DEFAULT list — shared across calls!
    return items

# GOOD: None sentinel
def add_item(item: str, items: list[str] | None = None) -> list[str]:
    if items is None:
        items = []
    items.append(item)
    return items
```

### FastAPI Patterns

```python
# GOOD: thin route, Pydantic validation, dependency injection
@router.post("/users", status_code=201, response_model=UserResponse)
async def create_user(
    request: CreateUserRequest,  # Pydantic validates automatically
    service: UserService = Depends(get_user_service),
) -> UserResponse:
    user = await service.create(request)
    return UserResponse.from_domain(user)

# BAD: fat route with inline logic
@router.post("/users")
async def create_user(request: Request):
    body = await request.json()  # no validation
    if not body.get("name"):  # manual validation
        raise HTTPException(400, "name required")
    # 50 lines of business logic directly in the route
    db = get_database()  # global state
    ...
```

### Async Patterns

```python
# GOOD: concurrent operations
async def get_dashboard(user_id: str) -> Dashboard:
    user, orders, notifications = await asyncio.gather(
        user_service.find(user_id),
        order_service.list(user_id),
        notification_service.unread(user_id),
    )
    return Dashboard(user=user, orders=orders, notifications=notifications)

# BAD: sequential when could be concurrent
async def get_dashboard(user_id: str) -> Dashboard:
    user = await user_service.find(user_id)          # waits
    orders = await order_service.list(user_id)        # then waits
    notifications = await notification_service.unread(user_id)  # then waits
    # 3x slower than it needs to be
```

---

## SQL & Database Patterns

### Parameterized Queries

```sql
-- GOOD: parameterized (Go)
db.QueryRow(ctx, "SELECT * FROM users WHERE id = $1", userID)

-- GOOD: parameterized (Python)
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

-- BAD: string interpolation (SQL injection!)
db.QueryRow(ctx, fmt.Sprintf("SELECT * FROM users WHERE id = '%s'", userID))
cursor.execute(f"SELECT * FROM users WHERE id = '{user_id}'")
```

### N+1 Query Detection

```python
# BAD: N+1 — 1 query for orders + N queries for users
orders = Order.objects.all()           # 1 query
for order in orders:
    print(order.user.name)             # N queries (one per order)

# GOOD: eager loading
orders = Order.objects.select_related("user").all()  # 1 query with JOIN
for order in orders:
    print(order.user.name)             # no additional queries
```

```go
// BAD: N+1 in Go
orders, _ := repo.ListOrders(ctx)
for _, order := range orders {
    user, _ := repo.FindUser(ctx, order.UserID) // N queries
}

// GOOD: batch load
orders, _ := repo.ListOrders(ctx)
userIDs := extractUserIDs(orders)
users, _ := repo.FindUsersByIDs(ctx, userIDs) // 1 query
userMap := indexByID(users)
```

### Index Strategy

```sql
-- Columns that SHOULD have indexes:
-- 1. Primary keys (automatic)
-- 2. Foreign keys (JOIN performance)
-- 3. Columns in WHERE clauses used frequently
-- 4. Columns in ORDER BY
-- 5. Columns in unique constraints

-- GOOD: composite index matches query pattern
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
-- Supports: WHERE user_id = X AND status = Y
-- Supports: WHERE user_id = X (leftmost prefix)
-- Does NOT support: WHERE status = Y (not leftmost)

-- Anti-pattern: index on low-cardinality column
CREATE INDEX idx_users_active ON users(is_active);
-- Boolean column — only 2 values, index scan often slower than full scan
-- Exception: if only 1% of rows are active, partial index is useful:
CREATE INDEX idx_users_active ON users(id) WHERE is_active = true;
```

### Migration Safety

```sql
-- SAFE: add nullable column (no lock, no rewrite)
ALTER TABLE users ADD COLUMN bio TEXT;

-- SAFE: add column with default (Postgres 11+, MySQL 8.0.12+: no rewrite)
ALTER TABLE users ADD COLUMN status VARCHAR(20) DEFAULT 'active';

-- DANGEROUS: add NOT NULL column without default (requires full table rewrite)
ALTER TABLE users ADD COLUMN status VARCHAR(20) NOT NULL;
-- FIX: add nullable → backfill → add NOT NULL constraint

-- DANGEROUS: rename column (breaks running code)
ALTER TABLE users RENAME COLUMN name TO full_name;
-- FIX: add new column → dual-write → backfill → switch reads → drop old

-- DANGEROUS: change column type (may require rewrite)
ALTER TABLE users ALTER COLUMN age TYPE BIGINT;
-- FIX: add new column → backfill → switch → drop old
```

### Pagination

```sql
-- OFFSET pagination: simple but slow for large offsets
SELECT * FROM orders ORDER BY created_at DESC LIMIT 20 OFFSET 10000;
-- DB must skip 10000 rows before returning 20 — O(offset)

-- CURSOR pagination: consistent performance regardless of page
SELECT * FROM orders
WHERE created_at < '2024-01-15T10:30:00Z'
ORDER BY created_at DESC
LIMIT 20;
-- Only scans from cursor position — O(limit)
```

---

## API Design Patterns

### REST Resource Naming

```
GOOD:
GET    /users              — list users
POST   /users              — create user
GET    /users/{id}         — get user
PUT    /users/{id}         — replace user
PATCH  /users/{id}         — partial update
DELETE /users/{id}         — delete user
GET    /users/{id}/orders  — list user's orders

BAD:
GET    /getUsers           — verb in URL
POST   /createUser         — verb in URL
GET    /user/list          — singular + verb
DELETE /users/{id}/delete  — redundant verb
```

### Error Response Format

```json
// GOOD: consistent, structured
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data",
    "details": [
      { "field": "email", "message": "must be a valid email address" },
      { "field": "age", "message": "must be between 0 and 150" }
    ]
  }
}

// BAD: inconsistent, leaks internals
{ "error": "pq: duplicate key value violates unique constraint \"users_email_key\"" }
```

### Status Code Quick Reference

| Code | When | Notes |
|------|------|-------|
| 200 | Successful GET, PUT, PATCH | Include body |
| 201 | Successful POST (created) | Include Location header |
| 204 | Successful DELETE | No body |
| 400 | Malformed request | Can't parse JSON, wrong Content-Type |
| 401 | Not authenticated | Missing or invalid token |
| 403 | Not authorized | Valid token, insufficient permissions |
| 404 | Resource not found | Also use for unauthorized resource access (prevent enumeration) |
| 409 | Conflict | Duplicate resource, version conflict |
| 422 | Validation error | Valid JSON but invalid field values |
| 429 | Rate limited | Include Retry-After header |
| 500 | Server error | Never expose internals |

### Pagination Response

```json
{
  "data": [...],
  "pagination": {
    "total": 150,
    "page": 2,
    "pageSize": 20,
    "hasMore": true,
    "nextCursor": "eyJjcmVhdGVkX2F0IjoiMjAyNC0wMS0xNSJ9"
  }
}
```

### Idempotency

```
// Client sends idempotency key with POST
POST /payments
Idempotency-Key: abc-123
Content-Type: application/json

{ "amount": 1000, "currency": "USD" }

// Server behavior:
// 1st request: process payment, store result keyed by "abc-123"
// 2nd request with same key: return stored result, don't process again
// Different key: process as new payment
```

---

## Common Anti-Patterns

| Anti-Pattern | Language | Why It's Bad | Fix |
|-------------|----------|-------------|-----|
| Bare `return err` | Go | No context for debugging | `fmt.Errorf("doing X: %w", err)` |
| Fire-and-forget goroutine | Go | Leak, no error handling | `errgroup`, WaitGroup |
| `except: pass` | Python | Swallowed errors | Specific exception + logging |
| Mutable default arg | Python | Shared state across calls | `None` sentinel |
| `SELECT *` | SQL | Wastes bandwidth, breaks on schema change | Explicit columns |
| String interpolation in SQL | All | SQL injection | Parameterized queries |
| N+1 queries | All | O(n) queries instead of O(1) | Batch load, JOINs |
| OFFSET pagination | SQL | Slow for large offsets | Cursor/keyset pagination |
| Verb in REST URL | API | Not RESTful | Noun-based resources |
| 200 for errors | API | Breaks client error handling | Proper status codes |
| Stack trace in error response | API | Info leakage | Generic user message |
