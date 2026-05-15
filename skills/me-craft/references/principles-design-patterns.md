# Reference: Design Patterns

Consult during Phase 3. Apply only when a pattern removes duplication, reduces coupling, or makes
code testable. Do not apply speculatively — only when the need is present.

---

## Repository Pattern

Isolates data access behind an interface. The service layer calls the repository; it never calls
the ORM directly. Makes business logic unit-testable without a DB.

```python
class UserRepository:
    def get_by_email(self, email: str) -> User | None:
        return db.session.query(User).filter_by(email=email).first()
    def save(self, user: User) -> User:
        db.session.add(user)
        db.session.flush()
        return user
```

Use when: the same query logic appears in multiple places, or you want to swap the data source in tests.

---

## Service Layer

A service module contains the business logic for one domain. It takes simple inputs, calls
repositories, enforces business rules, and returns results or raises domain exceptions.

- Services are framework-agnostic — no `request`, no ORM session management. That belongs in the view.
- Name services as verbs: `create_user(...)`, `process_payment(...)`, `archive_post(...)`.

---

## Factory Pattern

Use when object construction is complex or varies by type. Centralises the "how to build X" logic.

```python
def build_notification(event: str, payload: dict) -> Notification:
    builders = {"email": EmailNotification, "sms": SMSNotification}
    cls = builders.get(event)
    if cls is None:
        raise ValueError(f"Unknown event: {event}")
    return cls.from_payload(payload)
```

---

## Strategy Pattern

Use when a class needs to vary its behaviour at runtime based on a parameter. Replace `if/elif`
chains that choose algorithms with a dict of callables or protocol implementations.

```python
EXPORTERS: dict[str, Callable[[Report], bytes]] = {
    "pdf": export_pdf,
    "csv": export_csv,
    "xlsx": export_xlsx,
}
exporter = EXPORTERS.get(fmt)
if exporter is None:
    raise UnsupportedFormat(fmt)
return exporter(report)
```

---

## Observer / Event Bus

Use for decoupled side-effects where the source should not know about the consumer.

- Prefer an explicit in-process event bus (`blinker` in Flask, Django signals for Django) over
  ad-hoc callback registries.
- Document every event: name, payload shape, which consumers subscribe. Undocumented events become traps.

---

## Adapter Pattern

Wrap third-party SDK calls in a thin adapter class. This pins the external API surface, makes
mocking trivial, and localises changes when the SDK version changes.

```python
class StripeAdapter:
    def charge(self, amount_cents: int, token: str) -> ChargeResult: ...
```
