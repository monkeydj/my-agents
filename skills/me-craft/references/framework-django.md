# Reference: Python / Django

Consult during Phase 3 when the project uses Django or Django REST Framework.

---

## ORM & Queries

- Use `select_related` for forward FK/OneToOne relations, `prefetch_related` for reverse FK and M2M.
  Never iterate a QuerySet inside a loop without prefetching — this creates N+1 queries.
- Fat models over fat views: business logic belongs on the model or a dedicated service, not in a view.
- Custom managers and QuerySets encapsulate reusable query logic:
  ```python
  class ActiveUserQuerySet(models.QuerySet):
      def active(self) -> "ActiveUserQuerySet":
          return self.filter(is_active=True, deleted_at__isnull=True)
  ```
- Use `F()` for atomic DB-level field updates; use `Q()` for complex OR/AND filters. Never pull a
  record to Python just to increment a counter.

---

## Migrations

- One migration per logical change. Keep migrations reversible — implement `database_backwards` or
  check `RunPython` calls are idempotent.
- Separate data migrations from schema migrations. A data migration that touches millions of rows
  should run in batches with `queryset.iterator()`.
- Never edit a migration that has already been applied to a shared environment.

---

## Views & Serializers (DRF)

- Thin views: validate in the serializer, act in the service layer, respond in the view.
- Use `serializer.validated_data`, not `serializer.data`, inside create/update logic.
- Override `to_representation` for read shapes that differ from write shapes — don't add write
  fields to read serializers or vice versa.
- `perform_create` / `perform_update` are the right hooks to attach request context (e.g., `request.user`).

---

## Settings

- Never put secrets in `settings.py`. Use `django-environ` or `python-decouple` and `.env` files.
- Use `django.conf.settings` lazy-import pattern inside app code to avoid import cycles.
- Split settings by environment: `settings/base.py`, `settings/local.py`, `settings/production.py`.

---

## Signals

- Prefer explicit service calls over signals for business logic — signals hide control flow.
- Use signals only for decoupled side-effects (audit logs, cache invalidation). Always specify `sender`.
