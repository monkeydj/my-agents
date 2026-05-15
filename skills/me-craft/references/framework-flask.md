# Reference: Python / Flask

Consult during Phase 3 when the project uses Flask.

---

## App Factory & Blueprints

- Always use the app factory pattern — `create_app(config=None)` — never a module-level `app = Flask(__name__)`.
  This enables testing with different configs and avoids circular imports.
  ```python
  def create_app(config: str = "config.DevelopmentConfig") -> Flask:
      app = Flask(__name__)
      app.config.from_object(config)
      db.init_app(app)
      app.register_blueprint(api_bp, url_prefix="/api/v1")
      return app
  ```
- Organize routes in Blueprints by domain (`users`, `payments`, `auth`). One Blueprint per module.
- Register extensions (SQLAlchemy, Migrate, JWT) in the factory, not at import time.

---

## SQLAlchemy (Flask-SQLAlchemy)

- Use `db.session.add()` + `db.session.commit()` as the single write path. Wrap multi-step writes
  in explicit transactions and roll back on failure.
- Lazy loading is the default and causes N+1 queries. Use `joinedload` / `selectinload` options in
  queries that will serialize related objects.
- Model `__repr__` and `__str__` should never trigger DB queries.
- Use `db.session.get(Model, pk)` (SQLAlchemy 2.x) over `Model.query.get(pk)` (deprecated).

---

## Migrations (Flask-Migrate / Alembic)

- After any model change: `flask db migrate -m "describe the change"`, then review the generated
  script before `flask db upgrade`. Auto-generation misses some changes (e.g., constraint names).
- Downgrade scripts must be correct. Test `flask db downgrade` in development before merging.

---

## Request Handling

- Use `g` for request-scoped state (current user, request ID). Never use module globals for this.
- `@app.before_request` and `@app.teardown_appcontext` for setup/teardown (DB connections, auth).
- Validate inputs with `marshmallow` or `pydantic` — never trust `request.json` or `request.args` raw.
- Return consistent JSON error envelopes from all error handlers:
  ```python
  @app.errorhandler(ValidationError)
  def handle_validation(e: ValidationError) -> tuple[dict, int]:
      return {"error": "validation_failed", "detail": e.messages}, 422
  ```
