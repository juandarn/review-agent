---
name: frontend-reference
description: >
  Complete React + TypeScript best practices reference. Covers hooks, component
  patterns, performance optimization, accessibility, state management, and common
  anti-patterns with before/after examples. Load this when you need to verify a
  frontend pattern during code review.
---

# Frontend Reference — React + TypeScript Best Practices

---

## Hooks Rules & Patterns

### useEffect

```tsx
// GOOD: cleanup function prevents memory leaks
useEffect(() => {
  const controller = new AbortController();
  fetchData(controller.signal);
  return () => controller.abort(); // cleanup
}, [fetchData]);

// BAD: missing cleanup — component unmounts, fetch completes, setState on unmounted
useEffect(() => {
  fetchData(); // no abort, no cleanup
}, []);

// BAD: missing dependency
const [id, setId] = useState(1);
useEffect(() => {
  fetchUser(id); // 'id' missing from deps → stale closure
}, []); // should be [id]

// BAD: object/array dependency causes infinite loop
useEffect(() => {
  doSomething(options);
}, [options]); // if options = {} inline, new ref each render → infinite loop
// FIX: useMemo the options, or spread individual primitive values into deps
```

### useState vs useMemo

```tsx
// BAD: derived state stored in useState
const [filteredItems, setFilteredItems] = useState([]);
useEffect(() => {
  setFilteredItems(items.filter(i => i.active));
}, [items]);

// GOOD: derive during render
const filteredItems = useMemo(
  () => items.filter(i => i.active),
  [items]
);
```

### Custom Hooks

```tsx
// GOOD: reusable, testable, single purpose
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);
  return debouncedValue;
}

// BAD: hook that does too many things (fetch + cache + transform + validate)
// Split into: useFetch, useCache, useTransform
```

---

## Component Patterns

### Single Responsibility

```tsx
// BAD: god component
function UserPage() {
  // fetches user data
  // fetches user orders
  // handles form state
  // validates form
  // renders sidebar, content, modals
  // 300+ lines
}

// GOOD: composed
function UserPage() {
  return (
    <UserLayout>
      <UserProfile />
      <UserOrders />
    </UserLayout>
  );
}
```

### Props Interface

```tsx
// BAD
function Button(props: any) { ... }
function Button({ label, onClick }: { label: string; onClick: () => void }) { ... }

// GOOD
interface ButtonProps {
  label: string;
  onClick: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

function Button({ label, onClick, variant = 'primary', disabled = false }: ButtonProps) { ... }
```

### Composition over Configuration

```tsx
// BAD: config-driven, hard to customize
<Card
  title="User"
  subtitle="Details"
  headerRight={<Badge>Active</Badge>}
  footer={<Button>Save</Button>}
  showDivider
/>

// GOOD: composition, flexible
<Card>
  <Card.Header>
    <Card.Title>User</Card.Title>
    <Badge>Active</Badge>
  </Card.Header>
  <Card.Content>...</Card.Content>
  <Card.Footer>
    <Button>Save</Button>
  </Card.Footer>
</Card>
```

### Key Prop

```tsx
// BAD: array index as key (breaks on reorder/delete)
{items.map((item, index) => <Item key={index} {...item} />)}

// GOOD: stable unique identifier
{items.map(item => <Item key={item.id} {...item} />)}
```

---

## TypeScript Patterns

### No `any`

```tsx
// BAD
function processData(data: any) { return data.value; }

// GOOD
interface ApiResponse<T> {
  data: T;
  status: number;
}
function processData<T>(response: ApiResponse<T>): T { return response.data; }

// BAD: type assertion to silence TypeScript
const user = response as any as User;

// GOOD: runtime validation
function isUser(value: unknown): value is User {
  return typeof value === 'object' && value !== null && 'id' in value;
}
```

### Discriminated Unions

```tsx
// BAD: boolean flags for state
interface State {
  isLoading: boolean;
  isError: boolean;
  data: User | null;
  error: string | null;
}
// Can represent impossible states: isLoading=true AND isError=true

// GOOD: discriminated union
type State =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: User }
  | { status: 'error'; error: string };
```

### Enums vs Const Objects

```tsx
// AVOID: enums (not tree-shakeable, runtime overhead)
enum Status { Active = 'active', Inactive = 'inactive' }

// PREFER: const objects
const STATUS = { Active: 'active', Inactive: 'inactive' } as const;
type Status = typeof STATUS[keyof typeof STATUS]; // 'active' | 'inactive'
```

---

## Performance Patterns

### Memoization

```tsx
// When to use React.memo:
// - Component receives same props frequently but parent re-renders often
// - Component is expensive to render (large tree, complex calculations)
const ExpensiveList = React.memo(function ExpensiveList({ items }: Props) {
  return items.map(item => <ExpensiveItem key={item.id} item={item} />);
});

// When NOT to use React.memo:
// - Component is cheap to render (a few divs)
// - Props change on every render anyway
// - Component uses children prop (children = new JSX each render)

// useCallback: stable function reference for memoized children
const handleClick = useCallback((id: string) => {
  setSelected(id);
}, []); // no deps needed since setSelected is stable

// useMemo: expensive computation
const sortedItems = useMemo(
  () => items.sort((a, b) => a.name.localeCompare(b.name)),
  [items]
);
```

### Avoiding Unnecessary Re-renders

```tsx
// BAD: new object reference every render
<Component style={{ color: 'red' }} />
<Component config={{ theme: 'dark', lang: 'en' }} />

// GOOD: stable reference
const style = useMemo(() => ({ color: 'red' }), []);
// or define outside component if truly static:
const STYLE = { color: 'red' } as const;
```

### Code Splitting

```tsx
// Heavy component loaded only when needed
const HeavyChart = React.lazy(() => import('./HeavyChart'));

function Dashboard() {
  return (
    <Suspense fallback={<Skeleton />}>
      <HeavyChart data={data} />
    </Suspense>
  );
}
```

---

## Accessibility Quick Reference

### Interactive Elements

```tsx
// BEST: semantic HTML (keyboard support built-in)
<button onClick={handleClick}>Save</button>

// ACCEPTABLE: div with full keyboard support
const handleKeyDown = (e: React.KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault(); // prevent scroll on Space
    handleClick();
  }
};

<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={handleKeyDown} // EXTRACTED function, not inline
>
  Save
</div>
```

### Forms

```tsx
// GOOD: label associated with input
<label htmlFor="email">Email</label>
<input id="email" type="email" aria-describedby="email-hint" />
<p id="email-hint">We'll never share your email.</p>

// BAD: no label association
<span>Email</span>
<input type="email" />
```

### Focus Management

```tsx
// Modal: trap focus inside, return focus on close
function Modal({ isOpen, onClose }: ModalProps) {
  const previousFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      previousFocus.current = document.activeElement as HTMLElement;
    }
    return () => {
      previousFocus.current?.focus(); // return focus on close
    };
  }, [isOpen]);
  // ...
}
```

---

## Common Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|-------------|-------------|-----|
| `useEffect` for derived state | Extra render, stale data | `useMemo` |
| `useEffect` for event handling | Side effects in render | Event handler function |
| Prop drilling 3+ levels | Hard to maintain, rigid | Context, composition, or state lib |
| Index as key | Breaks on reorder/delete | Stable unique ID |
| Inline objects in JSX props | New reference each render | `useMemo` or constant |
| `any` type | No type safety | Proper types/generics |
| Empty catch blocks | Swallowed errors | Log or handle |
| `!important` in styles | Specificity war | Fix selector specificity |
| Snapshot tests on large components | Brittle, low signal | Behavioral tests |
| Mixing async/sync in effects | Race conditions | Proper async handling with cleanup |
