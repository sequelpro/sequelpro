# MySQL Transfer — design

Sequel Plus 2.0.3. The toolbar's Transfer button, today PostgreSQL-only (always disabled on MySQL tabs), copies a MySQL
database, or some of its tables, to another MySQL favorite.

## Decided with the owner

- **MySQL → MySQL only.** No MySQL → PostgreSQL.
- **The same sheet as PostgreSQL's Transfer:** Whole database / Selected tables; To: (MySQL favorites, not this tab's)
  and Database: menus with Filter fields (narrow, unset a hidden choice, open the menu when typing pauses) and New
  Database…; Empty the target first (typed-name confirmation, except a database made in the sheet) or Overwrite;
  the task list (marks, a line per task, outcome until Close); the ownership note.
- **On failure the target's tables are unchanged:** tables are copied under temporary names and swapped in at the end
  with one atomic `RENAME TABLE`. MySQL commits each DDL statement, so the target can't be one transaction as on
  PostgreSQL. `DROP DATABASE` is never used (owner's rule).

## How a transfer runs

Connections: the source is a copy of the tab's connection (`-[SPMySQLConnection copy]`, through the tab's tunnel);
the target is a new connection to the favorite (SSH tunnel, SSL, the keychain's password, a prompt when there is
none), made by a small `SPMySQLFavoriteConnector` modelled on `SPPostgresConnector`.

Steps (the task list):

1. **Connect to the source and the target.**
2. **Check the source and the target**: not the same database (server `@@server_uuid` + name), the target has no
   leftover `__spn_`/`__spo_` tables, what Overwrite replaces.
3. **Read "src"**: one consistent snapshot (`START TRANSACTION WITH CONSISTENT SNAPSHOT`, REPEATABLE READ):
   `SHOW CREATE TABLE` per table (MySQL has no bulk form), triggers in one `information_schema.TRIGGERS` query,
   views (`SHOW CREATE VIEW`), routines (`SHOW CREATE PROCEDURE/FUNCTION`), events (`SHOW CREATE EVENT`), and each
   table's copyable columns (not generated) in one `information_schema.COLUMNS` query.
4. **Create the tables in "dst" under temporary names** (`__spn_<n>`), without their foreign keys and CHECK
   constraints (both have schema-wide names that would clash with the tables being replaced; added after the swap).
5. **Copy the data**: each table streamed from the source (`streamingQueryString:`) into multi-row INSERTs of up to
   ~4 MB (below the target's `max_allowed_packet`), values typed (NULL, numbers raw, NSData as `X'…'`, strings
   escaped); target session `FOREIGN_KEY_CHECKS=0`, `UNIQUE_CHECKS=0`, `SQL_MODE='NO_AUTO_VALUE_ON_ZERO'`,
   `NAMES utf8mb4`, `time_zone='+00:00'` (also on the source). Rows "12,000 of ~50,000" (estimate from
   `information_schema.TABLES.TABLE_ROWS`).
6. **Swap the tables in**: one `RENAME TABLE` moves each replaced table to `__spo_<n>` and each new one to its name,
   then the old ones are dropped. Empty mode replaces every table and first drops everything else in the target
   (views, routines, events; triggers go with their tables). Overwrite replaces only the copied tables (and copied
   views/routines/events of the same name). Until this step the target is untouched; a failure or cancel before it
   drops the `__spn_` tables.
7. **Create foreign keys, CHECK constraints, views, triggers, routines and events**: views in dependency order (retry
   until no progress), each trigger/routine/event under its own `sql_mode` and character set. A failure here is the
   one case that leaves the target half done: the sheet names what was and wasn't created.

DEFINER clauses are removed (objects are created with the To: user as definer, as PostgreSQL's copy is owned by the
To: user); the ownership note says so. Views' references to the source database name are made unqualified.
Selected tables copy the tables and their triggers (not views, routines or events).

## Not in scope

Users and privileges; MySQL → PostgreSQL; resuming a failed transfer; parallel table copies.

## Tests

Against the docker `sp-mysql8` (127.0.0.1:55438, root/sptest), skipped when it isn't running: engine end-to-end
(whole database, selected tables, Overwrite, Empty), the swap leaving the target unchanged on a failure before it,
views in dependency order, triggers/routines/events, generated/binary/bit/NULL values, DEFINER removed; the sheet as
for PostgreSQL (menus, filters, task list) with test seams; the toolbar item enabled on a connected MySQL tab with a
database.
