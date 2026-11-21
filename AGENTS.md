# AGENTS.md — ThuVien2 Workspace Rules

## Stack & Environment
- **Database:** Microsoft SQL Server (T-SQL), database name `ThuVien2`.
- **Execution:** Windows `.bat` scripts in `/scripts` (`setup_all.bat` executes schema, seeds, and programs in order).

## Architecture & Execution Pipeline
1. `db/001_schema/`: DDL scripts (`001_create-schema.sql`, `002_drop-schema.sql`, `003_delete-schema-data.sql`).
2. `db/002_seed/`: Seed data in strict FK dependency order (`001_master_lookups` -> `002_entities` -> `003_entity_relationships` -> `004_borrow_return` -> `005_fines`).
3. `db/003_program/`: Programmable objects split by domain (`001_shared`, `002_catalog`, `003_circulation`, `004_fines`) into `functions/` and `procedures/`.
4. `db/tests/`: T-SQL test scripts mirroring `003_program` domains.

## Mandatory Coding Rules
- **Source of Truth:** Always read `SPEC.md` and `db/001_schema/001_create-schema.sql` before writing SQL. Never invent table or column names.
- **Naming Convention:** Keep existing Vietnamese names (`sp_LapPhieuMuon`, `sp_LapPhieuTra`, table names) untouched. Write all new procedures in `002_catalog` and `004_fines` in **English** (`sp_AddBookTitle`, `sp_RecordFinePayment`, etc.).
- **Idempotency:** Every file in `db/003_program/` must use `CREATE OR ALTER PROCEDURE` / `CREATE OR ALTER FUNCTION` with `GO` batch separators so `03_run_programs.bat` is safely re-runnable.
- **Transactions & Errors:** Use `SET XACT_ABORT ON` with `BEGIN TRY ... BEGIN CATCH` and `THROW` using the error codes defined in `SPEC.md` Section 4.
- **Schema Sync:** Any column/constraint change in `001_create-schema.sql` must also update `002_drop-schema.sql`, `003_delete-schema-data.sql`, and `002_seed/`.
- **Testing:** Every new procedure or function requires a corresponding test script in `db/tests/<domain>/` covering both happy paths and `THROW` error cases. Keep `test_fn_CalculateFine.sql` strictly in `db/tests/001_shared/`.

## Phased Implementation Protocol
Execute work strictly in sequential phases. Complete and verify the current phase before starting the next—never implement multiple phases in a single pass unless explicitly instructed:
1. **Phase 1 — Schema Alignment (`db/001_schema/`):** Apply DDL updates and sync `001_create-schema.sql`, `002_drop-schema.sql`, and `003_delete-schema-data.sql`. Verify with `scripts/01_reset_schema.bat`.
2. **Phase 2 — Seed Data Sync (`db/002_seed/`):** Update seed files in dependency order to match schema changes and include edge-case fixtures. Verify with `scripts/02_run_seeds.bat`.
3. **Phase 3 — Shared & Circulation Audit (`db/003_program/001_shared`, `003_circulation`):** Review and align `fn_CalculateFine`, `sp_LapPhieuMuon`, and `sp_LapPhieuTra` with `SPEC.md`.
4. **Phase 4 — Catalog Module (`db/003_program/002_catalog`):** Implement catalog stored procedures (`sp_AddBookTitle`, `sp_AddBookCopies`, `sp_UpdateCopyStatus`, `sp_SearchCatalog`).
5. **Phase 5 — Fines Module (`db/003_program/004_fines`):** Implement fine payment and waiver procedures (`sp_RecordFinePayment`, `sp_WaiveFine`, `sp_GetStudentFineBalance`).
6. **Phase 6 — Tests & End-to-End Verification (`db/tests/`, `scripts/`):** Write unit/integration tests for every procedure and run `scripts/setup_all.bat` to confirm zero errors.