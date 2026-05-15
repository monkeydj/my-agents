# Reference: Language — Python

Consult during Phase 3 when the project is written in Python, regardless of framework.
Framework-specific guidance lives in `framework-django.md` or `framework-flask.md`.

---

## Type Hints

- Annotate all function signatures — parameters and return types. Use `from __future__ import annotations`
  at the top of files targeting Python < 3.10 to enable deferred evaluation.
- Use `X | None` (3.10+) over `Optional[X]`. Use `X | Y` over `Union[X, Y]`.
- Prefer `list[str]` / `dict[str, int]` (lowercase generics, 3.9+) over `List` / `Dict` from `typing`.
- Use `TypeAlias` for complex reused types rather than repeating them inline.
- `Any` is a last resort — add a comment explaining why it can't be avoided.

---

## Idiomatic Python

- Prefer list/dict/set comprehensions over imperative loops that build collections:
  ```python
  # prefer
  active_ids = [u.id for u in users if u.is_active]
  # over
  active_ids = []
  for u in users:
      if u.is_active:
          active_ids.append(u.id)
  ```
- Use generators (`yield`) for large sequences that don't need to materialise in memory at once.
- Prefer `enumerate(iterable)` over `range(len(iterable))` when you need both index and value.
- Use `zip(a, b, strict=True)` (3.10+) when the two iterables must be the same length.
- Context managers (`with`) for any resource that needs guaranteed cleanup — files, locks, DB connections.
- `walrus operator` (`:=`) only when it genuinely reduces duplication; not just to save a line.

---

## Structured Data

- Use `dataclasses` for simple value objects with no validation logic.
- Use `pydantic` (v2) for validated, serialisable data at system boundaries (API payloads, config, messages).
- Avoid passing plain `dict` between functions — model the shape explicitly.
  ```python
  # prefer
  @dataclass
  class InvoiceLineItem:
      description: str
      amount_cents: int
      tax_rate: float
  ```

---

## Module & Package Structure

- One module per cohesive concern. A module that does two unrelated things should be two modules.
- `__init__.py` should only re-export the public API of the package — no logic.
- Avoid circular imports. If two modules import each other, extract the shared dependency into a third.
- Use relative imports (`from .models import User`) within a package; absolute imports for cross-package.
- `pathlib.Path` for all filesystem operations — never `os.path`.

---

## Standard Library Patterns

- `collections.defaultdict` and `collections.Counter` over manual dict initialisation.
- `itertools.chain`, `itertools.groupby`, `itertools.islice` for compositional iteration.
- `functools.lru_cache` / `functools.cache` for pure, deterministic functions with repeated calls.
- `contextlib.suppress(ExceptionType)` instead of a bare `try/except: pass`.
- `contextlib.contextmanager` for simple context managers that don't need a full class.

---

## Testing (pytest)

- Mirror the source path: `src/payments/processor.py` → `tests/payments/test_processor.py`.
- One `assert` per logical claim — do not bundle unrelated assertions in one test function.
- Use `pytest.mark.parametrize` for input/output tables instead of loops inside a test.
- Fixtures over setup/teardown methods. Scope fixtures appropriately (`function`, `module`, `session`).
- Use `pytest-mock` (`mocker` fixture) for patching — prefer patching where an object is *used*, not where it is defined.
