# Angular UI and integration review reference

Optional checklist. Use the project's installed Angular version and conventions.

- **Contract:** typed API models, nullability, naming, dates, status/error mapping and validation response shapes match backend behavior.
- **Concurrency/state:** avoid stale response races and unbounded subscriptions; cover loading, empty and error states; ensure deduplication where needed.
- **Authorization:** frontend guards are UX, never a substitute for server-side resource authorization. Protect tokens and XSRF behavior.
- **Forms/accessibility:** client/server validation, failed saves, keyboard and screen-reader flows where relevant.
- **Rendering/performance:** change detection, unnecessary recalculation, list tracking, state boundaries.
- **Evidence:** project tests, lint/build, and a real API contract or interaction check if practical.

Review specific paths/lines and describe user-visible impact. Green `ng build` is not proof that the route works with an actual backend.
