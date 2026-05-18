# Reference: Error Handling

Consult during Phase 3. These rules apply across Python projects regardless of framework.

---

## Raise Specific, Typed Exceptions

Define domain exceptions in an `exceptions.py` module per app/domain. Never raise bare `Exception`.

```python
class PaymentDeclined(AppError):
    """Raised when the payment provider declines the charge."""

class UserNotFound(AppError):
    """Raised when a user cannot be located by the given identifier."""
```

Catch the narrowest exception type possible. `except Exception` is a last resort, only at the
top-level boundary (view layer, CLI entry point, worker consumer).

---

## Error Propagation vs Error Boundaries

Let errors propagate until they reach a boundary that knows how to handle them (the view, the
worker, the CLI). Do not swallow exceptions in the middle of a call stack.

The boundary converts domain exceptions to HTTP status codes, log entries, or user messages.
Business logic should not know about HTTP.

```python
@app.errorhandler(UserNotFound)
def handle_not_found(e: UserNotFound) -> tuple[dict, int]:
    return {"error": "not_found", "message": str(e)}, 404
```

---

## Structured Logging for Errors

Log errors with context, not just the message. Include request ID, user ID, affected entity.

```python
logger.error(
    "payment_declined",
    extra={"user_id": user.id, "amount": amount, "provider_code": e.code},
    exc_info=True,
)
```

- Use `exc_info=True` to attach the traceback.
- Never log sensitive data (card numbers, tokens, PII).
- Log at the boundary where an error is caught and handled, not at every intermediate layer.

---

## Retry Policy (External Calls)

Transient failures (network timeout, 429, 503): retry with exponential backoff. Use `tenacity` —
never roll a sleep loop by hand.

```python
@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(min=1, max=10),
    retry=retry_if_exception_type(TransientError),
)
def call_external_api(...): ...
```

- Only retry operations that are safe to repeat. Mark write calls with idempotency keys where the
  external API supports them.
- Never retry on 4xx (except 429), validation errors, or domain exceptions — these will not resolve on retry.

---

## Circuit Breaker (External Dependencies)

Use a circuit breaker (e.g., `pybreaker`) for calls to external services that can fail in bulk.
When the circuit is open, fail fast with a cached response or a graceful degraded state rather
than queuing up hundreds of hanging connections.

Define: failure threshold, recovery timeout, fallback behaviour.

---

## Validation at Boundaries Only

Validate inputs at the point they enter the system (API request, CLI argument, message consumer).
Once validated and converted to domain types, do not re-validate inside service or repository code.

Use `pydantic` models or `marshmallow` schemas as the validation layer — not ad-hoc `if` checks
scattered through business logic.
