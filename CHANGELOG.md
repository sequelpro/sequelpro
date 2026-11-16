# Changelog

## Sequel Plus 2.0.3

Upgrading from 2.0.2.

- Version **2.0.3**.

### New Folder and New Favorite on a folder's right-click menu
Right-clicking a folder in the favorites list now offers **New Folder** and **New Favorite** at the top of the menu. Both add the new item inside that folder and start editing its name, as the + and folder buttons below the list do with the folder selected. They don't appear when you right-click a favorite or an empty part of the list.

### "Loading users…" before the User Manager, and a MySQL 8 fix
Clicking **Users** now shows a small **Loading users…** sheet with a spinner while the user list is fetched, instead of a window that seems frozen. It has a **Cancel** button.
- **MySQL:** the sheet appears at once. The access check runs in the background, and the sheet stays up until the User Manager replaces it.
- **PostgreSQL:** the Users sheet opens its own connection (possibly through SSH) and reads the roles. If that takes more than 0.3 seconds, the loading sheet appears; an SSH password prompt goes on top of it.
- **MySQL 8:** the User Manager could fail to open at all when a user had privileges on a single database. It stopped at the "create temporary tables" privilege, which it stored under a name the app didn't recognise. Database privileges are now read correctly, and a privilege column the app doesn't know about is skipped instead of stopping it.

### Users toolbar button
The toolbar's **Users** button now sits right after **Transfer**, with the other buttons, and has a new icon: two people in black, the one behind lighter, like the Transfer icon (white in Dark Mode). It no longer sits in a round button background.
- A toolbar you set up before gets Users after Transfer once (added if it wasn't there, moved if it was on the right). If you remove or move it afterwards with Customize Toolbar, that sticks.

### Foreign key links in Content (PostgreSQL)
In the Content view, a column that is a foreign key now shows a small arrow after each value, as MySQL's Content view does. Click it to open the table the key points to, showing just the matching row.
- The other table is selected in the left panel (switching schema when it's in another one) and its filter bar is shown holding the filter (for example `id = 2`), so you can change or clear it. Clearing it shows every row again.
- A key into the same table (such as `parent_id`) filters this table. A key over several columns follows its first column.
- There's no arrow on NULL values, on the row being edited, or on a new row that isn't saved yet.
- Following a link is a place in History, so Back returns to the table you came from.

### Filters in Transfer's To: and Database: menus (PostgreSQL)
A **Filter** field beside each of the Transfer sheet's **To:** and **Database:** menus narrows that menu to the names containing what you type (upper or lower case, with or without accents).
- When you pause typing (half a second), the menu opens showing the matches; choose one, or press Esc to type more. It doesn't open when nothing matches.
- A connection or database the filter leaves out is unset: the connection is closed and its databases cleared, or the database is no longer chosen, and **Transfer** stays disabled until you choose one the menu lists. Clearing the filter doesn't choose again, and typing never opens a connection.
- **New Database…** always stays in the Database: menu, and the database filter also applies to the databases of another connection you choose. A database you make with New Database… clears the database filter and is chosen.

### Transfer for MySQL
The toolbar's **Transfer** button now works on MySQL tabs too: it copies this tab's database, or some of its tables, to a database of another MySQL favorite. The sheet is the same as PostgreSQL's: **Whole database** or **Selected tables**, the **To:** and **Database:** menus with their filters and **New Database…**, **Empty the target database first** (confirmed by typing its name) or **Overwrite tables that already exist on the target**, and the task list.
- The source is read in one consistent snapshot and its rows are sent in batches of multi-row INSERTs.
- **Your target is safe until the very end.** MySQL can't undo table changes the way PostgreSQL rolls back a transaction, so the tables are first copied into the target under temporary names while the real ones stay untouched. Only once every table has been copied are they swapped in, all at once. A failure or cancel before then leaves the target exactly as it was.
- After the swap, foreign keys, CHECK constraints, views (in the order they depend on each other), triggers, routines and events are created. If one of them can't be, the sheet lists which.
- Definers aren't copied: views, routines, triggers and events are created with the To: connection's user as their definer, and the sheet says so. Selected tables bring their triggers; views, routines and events come with the whole database.

### Faster Transfer, especially over a network (PostgreSQL)
- **Read** no longer asks the source about each table one at a time. It used to send about 13 queries per table before any data, and over a network each query waits a round trip, so a database with 1,000 tables spent minutes just waiting. It now reads every table's definition, columns, constraints, indexes and triggers in a few queries for all of them (about 55 queries in all, however many tables), and the sequences' values a few hundred at a time.
- The target gets the structure's statements a few hundred at a time instead of one round trip each.
- Reading the source and writing to the target now run at the same time: the target starts loading while the source is still being read, so a transfer takes about as long as the slower of the two instead of both added together. In the task list, **Read** keeps running beside the other steps until the source has been read whole.
- Nothing else changes: the source is still read in one consistent snapshot, the target is still written in one transaction, and if either side fails or you cancel, the target is left unchanged. If reading the source fails, the **Read** step is marked as the one that failed.

### Transfer shows its steps as a task list (PostgreSQL)
While a transfer runs, its sheet lists eight steps:
1. **Connect to the source and the target**
2. **Check the source and the target**
3. **Read** the source database
4. **Empty** the target (in Overwrite mode: **Drop what will be replaced**)
5. **Create the structure**: schemas, types, functions, tables, views
6. **Write the data**
7. **Create indexes, foreign keys and triggers**
8. **Commit**

- Each step shows a spinner while it runs, a green check when it's done, and a red cross if it fails; the steps after a failure are marked as not run.
- Under the running step, a line says what it's doing, with a count, for example *Reading table 3 of 12: orders*, *1 of 2: DROP SCHEMA IF EXISTS "old", public CASCADE*, *14 of 85: CREATE TABLE public.orders* or *Table 3 of 12: public.orders — 12,000 of 50,000 rows*. The bar under the list is that step's.
- A finished step keeps a line saying what it did: how many objects there are to copy, how many tables and rows were read, which schemas and extensions were dropped (or which objects will be replaced), how many statements ran, how many rows were written.
- Before, reading the source's structure and the whole load showed only *Checking the target…* and *Writing to …*.
- When it ends, the sheet stays open with the result: **Transfer complete** and what was copied, or why it failed (the target is left unchanged), next to the step that failed and what it was doing. Click **Close** when you're done. This replaces the separate message shown before. Cancel still closes the sheet straight away.

### Transfer says who owns the copy (PostgreSQL)
Transfer doesn't copy owners or privileges, and the sheet now says so under the mode choice. Everything the transfer creates is owned by the user the **To:** connection logs in as, and the note names that user. Grants for other roles need to be made again afterwards. The **Transfer complete** message ends with the same information.

### Transfer moved beside Query in the toolbar
The toolbar's **Transfer** button now comes right after **Query** instead of after **Users**. A toolbar you already have is updated once when a window opens. After that, wherever you put Transfer with Customize Toolbar stays, and if you removed it, it isn't added back.

### Fixed: crash after the app sat open
The app could quit by itself after being left open with no activity: when the screen woke from sleep, or a display was connected or disconnected, a window showing the connection screen crashed the app. The connection details' layout ran again for every view it resized, and once the scroll bar started appearing and disappearing it never stopped. It now settles.

### Fixed: editing after a column is dragged (MySQL)
In a MySQL table's Content, or a query's results, dragging a column to another position could make editing act on the wrong column:
- Typing in a cell could be checked against another column's type: the key was dropped and the edit cancelled, or the pop-up sheet opened for a plain single-line value.
- Editing a long value in place could start from its shortened 150-character preview rather than the whole value.
- The hexadecimal check for binary columns, and the check of which row an edit of a view or a query result will update, looked at the wrong column.

Editing now always acts on the column being edited, wherever it is in the grid.

## Sequel Plus 2.0.2

Upgrading from 2.0.1.

- Version **2.0.2**.

### Reduce Storage in the table list (MySQL and PostgreSQL)
Rows deleted with `DELETE` (or replaced by `UPDATE`) leave their space inside the table: the database keeps it for new rows rather than giving it back to the disk. Reduce Storage gives it back.

- Two items in the table list's right-click and gear menus, after **Truncate Table**:
  - **Reduce Storage…** for the selected tables (one or more, not views).
  - **Reduce Storage of All Tables…** for every table of the database (MySQL) or of the schema shown (PostgreSQL), whatever is selected.
- It asks first, saying what happens and what it costs. It runs in the background with **Cancel**, which stops it on the server. Afterwards it shows each table's size before and after, e.g. "orders: 5 MB → 304 kB" (for several tables, the total first), and the table sizes shown are read again.
- For the selected tables, the first problem stops it. For all tables, a table that can't be done is listed as skipped, with the reason, and the others are done.

**PostgreSQL:** `VACUUM (FULL, ANALYZE)` on each table: it is rewritten without the unused space and its statistics are updated. No rows change. The table is locked while it is rewritten, so nothing can read or write it until it is done, and the rewrite needs free disk space about the size of the table.
- It isn't run, and says why, when a transaction is open on the tab's connection (VACUUM can't run inside one).
- You must own the table (or, from PostgreSQL 17, have MAINTAIN on it); the server would otherwise skip it with only a warning. For the selected tables nothing is changed then; for all tables those tables are skipped.
- If a table's lock can't be had within 5 seconds, it stops with the server's message.

**MySQL:** `OPTIMIZE TABLE` on each table. An InnoDB table is rebuilt ("recreate + analyze"); it stays readable and writable except briefly at the start and end, and needs free disk space about its size. The space goes back to the disk when the table has its own file (`innodb_file_per_table`, the default); otherwise it stays in the shared tablespace for new rows. MyISAM tables are locked while they are optimized.
- Sizes are data plus indexes from `information_schema.TABLES`, read fresh for the run (MySQL 8 otherwise caches them).
- A table MySQL reports an error for (for example, no rights on it) stops the selected tables' run, or is skipped for all tables.
- Like MySQL's Truncate, it commits a transaction open on the connection.

## Sequel Plus 2.0.1

Upgrading from 2.0.0.

### Table list shows table sizes
- Each table in the table list shows its size after its name, aligned right in a lighter color. A long name is shortened with "…" before the size.
- The size matches a figure in the Table Information pane:
  - **MySQL:** "size:", the table's data without its indexes (`DATA_LENGTH` from `information_schema.TABLES`). MySQL 8 may cache these figures, so a size can lag behind recent changes, as in Table Information.
  - **PostgreSQL:** "total size:", the table's data, TOAST and indexes (`pg_total_relation_size`).
- Sizes move up a unit at 1024 of the smaller one. From 1024 MB they are shown in GB with one decimal, "1.5 GiB" (MySQL) or "1.5 GB" (PostgreSQL), and from 1024 GB in TB.

### PostgreSQL: sizes written in kB from 1 kB
- PostgreSQL's own size format (`pg_size_pretty`) stays in bytes up to 10 kB and in MB up to 10 GB, so a one-page table showed as "8192 bytes". The table list and Table Info (size, index size and total size, in both the Table Info tab and the sidebar's info pane) now write sizes themselves:
  - under 1 kB in bytes ("0 bytes");
  - then whole kB and MB up to 1023 ("8 kB", "17 MB");
  - from 1024 MB, GB with one decimal ("1.5 GB"), and from 1024 GB, TB.
- Views, procedures, functions and sequences show no size. In PostgreSQL a partitioned table shows none either; each partition shows its own.
- Sizes are read when the list loads or is refreshed. If the server doesn't allow reading them, the list shows names only, as before.

### Filter for the favorites list
- A **Filter** field above the connection screen's favorites list. As you type, the list shows only the MySQL and PostgreSQL favorites whose name or host contains the text (ignoring case and accents), with the groups they are in expanded. Typing a group's name shows everything in that group.
- The selected favorite stays in the list while filtering, and the form keeps what it shows. Quick Connect is always shown.
- Clearing the field shows the whole list again, with groups expanded or collapsed as you left them.
- While filtering, favorites can't be dragged to new places. Adding a favorite or group clears the filter, so the new item is visible.

### PostgreSQL: adding a row to a table with a required column
- **Fixed:** in Content, **Add row** (+) on a table with a NOT NULL column that has no default failed at once ("null value in column … violates not-null constraint"). It inserted the row before you could type anything.
- On such a table the new row is now added in the grid only, as MySQL does, and editing starts in the first required column. The row is inserted when you leave it: Return, selecting another row, adding another row, refreshing, sorting, filtering or changing page. Only the values you typed are sent; the other columns get their defaults.
- If the insert fails (e.g. a required value is still missing), the error is shown and the row stays, with what you typed, so you can finish it. Deleting the new row (−) just removes it, with nothing sent to the server.
- Tables without a required column work as before: the row is inserted at once with every column's default.

### PostgreSQL: Truncate can restart identity
- The **Truncate Table** question has a **Restart identity** checkbox, off by default. Checked, the truncate also resets the counters of the tables' serial and identity columns (`TRUNCATE … RESTART IDENTITY`), so new rows are numbered from the start again. Unchecked, numbering carries on, as before.

### PostgreSQL: the table information pane shows every line
- The **TABLE INFORMATION** pane under the table list is now tall enough for all its lines: type, owner, rows, size, index size, total size and comment. It was fixed at MySQL's 166 pt, which cut off **total size** and **comment**.

### Query's run button shows its whole title (MySQL and PostgreSQL)
- The run button above the results (**Run Current**, **Run Previous**, **Run Selection**, **Run All**) shows its full title, centred. It was cut off ("Run Curre…") because the button kept room for the menu's ⌘R and ⌥⌘R shortcuts.

### PostgreSQL: Add Database and Refresh Databases in the database selector
- The toolbar's database selector is laid out as MySQL's: **Choose Database...**, then **Add Database...** and **Refresh Databases**, then the databases.
  - **Add Database...** asks for the name, creates the database and switches to it, as Database ▸ Add Database… does.
  - **Refresh Databases** reads the list again.
  - Choosing any of these keeps the tab in its database, which the selector shows again.

### Databases in the database selector (MySQL and PostgreSQL)
- **Show all databases**, a new checkbox under the Database field in the connection editor, for MySQL and PostgreSQL, on every connection tab. It is on by default, and for favorites saved before it.
  - **On:** the toolbar's database selector lists every database you can use, as before.
  - **Off:** it lists only the connection's database (MySQL also lists the database in use, after a `USE`). The Database field must then be filled: Connect, Test Connection, Save Changes and Add to Favorites ask for it, and its placeholder says "required".
  - Clicking it is an edit of the connection, like typing in a field: Save Changes, Add to Favorites and Test Connection appear.
  - It is saved with the favorite, and is on for Quick Connect.
- PostgreSQL: the database selector, and Transfer's database lists, now leave out databases you have no CONNECT privilege on, whether granted directly, through a role, or through PUBLIC. Superusers still see every database. (MySQL's list already shows only databases you have a privilege on.)

### PostgreSQL: TABLES expanded in the sidebar
- The sidebar's **TABLES** is now expanded in a new connection tab, and after choosing another database or schema or refreshing. Views, Sequences and Extensions still start collapsed.
- After choosing a database or schema, or refreshing, the other sections keep the state you left them in.

### PostgreSQL: copying rows, and a right-click menu in the grids
- **Right-click menu**, as MySQL's, in Content's grid and in Query's results. Right-clicking a row selects it first.
  - **Content:** Copy, Copy with Column Names, Copy as SQL INSERT, Add New Row, Duplicate Row and Delete Row. The row items are enabled as the bottom bar's buttons are: Duplicate Row needs exactly one selected row.
  - **Query results:** Copy, Copy with Column Names and Copy as SQL INSERT.
- **Edit ▸ Copy** (⌘C) and **Copy with Column Names** (⌥⌘C) copy the selected rows as tab-separated text, as in MySQL. A line per row, with the column names' line first for Copy with Column Names. NULL is shown as the NULL placeholder from Preferences, and line breaks and tabs inside a value become ↵ and ⇥. Query results copy whole values. There is no paste.
- **Edit ▸ Copy as SQL INSERT** (⌃⌥⌘C) now works in Content's grid and in Query's results, as in MySQL. It copies the selected rows as one INSERT statement, with a VALUES line per row:
  ```
  INSERT INTO "public"."items" ("id", "name")
  VALUES
  	('1', 'first'),
  	('2', NULL);
  ```
  - Columns are in the order shown, with names in double quotes. Values are quoted text, which PostgreSQL converts to each column's type; NULL stays NULL.
  - **Content:** the rows go into the table being shown. Generated columns are left out, since PostgreSQL refuses values for them.
  - **Query results:** whole values are copied, not the shortened ones shown in the grid. The rows go into the table every column comes from, or `<table>` when they come from several tables or from none, as in MySQL.

### App
- Version **2.0.1**.

## Sequel Plus 2.0.0

Upgrading from 2.0.0-RC4.

### Separate from Sequel Pro
- Sequel Plus has its own app ID, `com.sequelplus.SequelPlus`, so its settings are kept apart from Sequel Pro's.
- Its data (favorites, query history, bundles, themes, saved Query texts) is kept in `~/Library/Application Support/Sequel Plus`.
- Its saved passwords are kept in the keychain as "Sequel Plus : …", "Sequel Plus SSHTunnel : …" and "Sequel Plus (PostgreSQL) : …".
- The first launch copies everything over once:
  - Sequel Pro's settings;
  - its `~/Library/Application Support/Sequel Pro` folder, which includes the data of the RC builds;
  - each saved password, to a new "Sequel Plus" keychain item. macOS asks to allow each one; choose **Always Allow**.
- Sequel Pro's settings, folder and keychain items are only read, never changed. Afterwards the two apps don't share anything.

### New for MySQL and PostgreSQL connections

#### Query editor keeps its SQL
- The Query editor's text is saved for each connection as you type (about a second after you stop), when the tab closes and when the app quits.
- Connecting again fills an empty Query editor with that connection's saved text. Text from an `.spf` file or **Open in New Tab** is never replaced.
- A saved favorite has its own text, kept when the favorite is renamed or edited. A Quick Connect is matched by its host, port and user (and socket or SSH host).
- Emptying the editor deletes the saved text. Two tabs on the same connection share it: the last one saved wins.
- The texts are kept in `~/Library/Application Support/Sequel Plus/Data/Query Scripts/`, one `.sql` file per connection.

### PostgreSQL connections
- **Add Schema** (the **+** after the schema pop-up) also asks for the owner: a pop-up of the server's roles, with the connected user selected.
- A pencil button before the **+** edits the shown schema's owner. **Save** changes it; if the server refuses, its message is shown.
- With the **Database** field empty, a connection opens the `postgres` database. Before, it tried a database named after the user, which often doesn't exist.
- Fixed: a favorite just added with the favorites **+** button, switched to PostgreSQL in the form, moved to Quick Connect. It now becomes a PostgreSQL favorite, stays selected and keeps what was typed. Other saved MySQL favorites still move their details to Quick Connect when switched.

### Favorites
- MySQL and PostgreSQL favorites are now saved together, in one favorites file (`Favorites.plist`). Groups, sorting and drag and drop work the same for both.
- On first launch the PostgreSQL favorites of RC4 are moved into it, each where it was shown. The old `PostgresFavorites.plist` and `PostgresFavoritePlacements.plist` are kept as backups, renamed with `.imported` at the end.
- Favorites export, favorites import and the **Default favorite** pop-up stay MySQL-only.

### App
- Version **2.0.0**.

### Readme
- The readme's logo and screenshot are now in the repository's `images/` folder instead of on Sequel Pro's website:
  - `Sequel-Plus-icon-512.png`, the app icon;
  - `Sequel-Plus.png`, the connection screen with MySQL and PostgreSQL favorites in one list.

### Unchanged
- **MySQL:** connecting to and working with a MySQL server is unchanged. What's new for MySQL is listed above: the Query editor keeps its SQL, and MySQL favorites share `Favorites.plist` and the separate Sequel Plus data and passwords.
- **Your data:** favorites, saved settings, passwords and data are carried over from RC4 (see "Separate from Sequel Pro").
- **Updates:** checking for updates stays off.

## Sequel Plus 2.0.0-RC4

Upgrading from 2.0.0-RC3.

### New for PostgreSQL connections

#### Table list
- A **+** button after the schema pop-up adds a schema: enter its name and it's created in the open database, then shown. If the server refuses (for example, the schema already exists), its message is shown.
- A **Filter** field under the schema pop-up shows only the tables, views, sequences and extensions whose names contain what you type. **Table ▸ Filter Tables** moves the cursor to it.
- **TABLES**, **VIEWS**, **SEQUENCES** and **EXTENSIONS** can be collapsed and expanded. Each heading has its arrow at the front, always shown.
- Every section starts collapsed when a schema opens. Selecting a table from elsewhere (history, Open Table in New Tab) opens its section.

#### Database menu
The Database menu now works for PostgreSQL connections:
- **Go to Database…**, **Refresh Tables**, **Refresh Databases** and **Open Database in New Tab**.
- **Add Database…** creates a database, then opens it.
- **Rename Database…** and **Duplicate Database…** work on the open database.
- **Delete Database…** permanently deletes the open database. You confirm by typing its name.
- **Alter Database…** changes the open database's name, owner and comment.
- **Show Server Variables…** lists the server's settings, with a filter.
- **Show Server Processes…** lists the server's sessions. **Cancel Query** stops a session's running statement and **Kill Connection** ends the session; your own session can't be stopped.
- PostgreSQL won't rename, copy or delete a database while anyone is connected to it. For those three, the window first moves to another database (`postgres` when it can), then makes the change. If another session is connected, the server refuses and its message is shown.
- **Flush Privileges**, **View Using Encoding** and **Shutdown Server** stay disabled: PostgreSQL has nothing equivalent.

#### Structure
- A new bar above the columns list holds an **Owner** pop-up, at its left, that changes the table's owner. It lists the server's roles.
- Fixed: after choosing another table, its columns could stay greyed out, as if they couldn't be edited, until something else redrew the list.

#### Date and time picker
- Editing a `date`, `time`, `timetz`, `timestamp` or `timestamptz` cell in Content or in a Query result opens a picker on the cell: a calendar for the date, a time stepper for the time, and a text field with the value.
- Picking writes the value into the text field; you can still type there (for `infinity`, fractions of a second, another offset, …). **Today** or **Now** fills in the current date or time.
- **Set** doesn't save to the database: it puts the value into the cell, which stays in edit mode. Press Return to save it or Escape to drop it, as with any cell edit. **NULL** (when the column allows it) puts NULL in the cell the same way. **Cancel** or Escape in the picker leaves the cell as it was.
- A value with a time zone keeps its offset, such as `+08:00`.

#### Query editor completion
- After `alias.` the editor suggests the columns of the table or view that alias stands for, as in `FROM orders a`, `JOIN items AS i` or `FROM public.orders o`. Before, it listed every table.
- After a table's name (`orders.`) it suggests that table's columns. After the shown schema's name (`public.`) it suggests its tables and views.
- Plain suggestions also include the columns of every table the current statement names.

### New for MySQL connections

#### Date and time picker
- Double-clicking a `DATE`, `TIME`, `DATETIME` or `TIMESTAMP` cell in Content or in a Custom Query result opens the same picker as for PostgreSQL. `YEAR` cells still edit as text.
- **Set** puts the value into the cell, which stays in edit mode; it is saved the way any cell edit is. **NULL** appears when the column allows NULL.
- Values the picker can't read, such as `0000-00-00` or a `TIME` over 24 hours, stay as they are in the text field.
- A cell that can't be edited (for example a Custom Query row that doesn't match exactly one row) opens no picker and behaves as before. Edit-in-sheet mode still uses the field editor sheet for every cell.

### App
- Version **2.0.0-RC4**.

### Unchanged
- **MySQL:** apart from the date and time picker, no changes to MySQL connections.
- **Your data:** favorites, saved settings and data are kept from RC3.
- **App icon:** the same as RC3.
- **Bundle ID and data folder:** the app keeps the same bundle ID and the same `~/Library/Application Support/Sequel Pro` folder.
- **Updates:** checking for updates stays off.

## Sequel Plus 2.0.0-RC3

Upgrading from 2.0.0-RC2. Every PostgreSQL feature is now available. These buttons, menu items and table list sections were disabled or hidden in RC2.

### New for PostgreSQL connections

#### Transfer
- Copies selected tables, or a whole database, from the current server to another PostgreSQL server. The target is usually a saved favorite and can use its own SSH tunnel.
- You choose one of two modes:
  - **Empty the target database first.** This removes everything inside the target database: all schemas (including `public`), tables, views, functions, types and extensions. You confirm by typing the target database's name. Other databases on that server are never touched.
  - **Overwrite tables that already exist.** Copied tables that already exist on the target are replaced, and the target's other tables are left alone. If replacing a table would break something on the target, such as a view or a foreign key from a table not being copied, Transfer stops before changing anything and lists what's in the way.
- Indexes, constraints, defaults and owned sequences are copied with the tables.

#### Users
- Manages roles the PostgreSQL way: logins and groups in one list. You can add, remove and duplicate roles.
- **General:** name, password, valid-until, connection limit, and the LOGIN, INHERIT, SUPERUSER, CREATEDB, CREATEROLE, REPLICATION and BYPASSRLS attributes.
- **Membership:** the roles this role belongs to (optionally WITH ADMIN OPTION), and the roles that belong to it.
- **Privileges:** pick a database and schema, then grant or revoke per object:
  - databases: CONNECT, CREATE, TEMP
  - schemas: USAGE, CREATE
  - tables: SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  - sequences: USAGE, SELECT
  - functions: EXECUTE
- You can also set default privileges for objects created later in the schema.
- Changes are applied together with **Apply**, as in the MySQL User Manager.

#### Sequences
- The table list shows a **SEQUENCES** section.
- Select a sequence to edit its name, type, start, increment, minimum, maximum, cache, cycle, owning column and comment. Its owner and current value are also shown.
- **Set Value…** sets the current value.
- **Add Sequence** and **Delete Sequence** are in the right-click and gear menus.

#### Extensions
- The table list shows an **EXTENSIONS** section with the extensions installed in the current database.
- You can install one of the server's available extensions, change an installed extension's version, or drop an extension.

#### Table history
- The toolbar's **Back/Forward** buttons and **View ▸ Back/Forward In History** move between the tables and views you've visited, as they do for MySQL. This also works across databases.

#### Create Syntax
- **Show Create Table Syntax…** and **Copy Create Table Syntax** in the table list's right-click and gear menus.

### App
- Version **2.0.0-RC3**.

### Unchanged
- **MySQL:** no changes to MySQL connections.
- **Your data:** favorites, saved settings and data are kept from RC2.
- **Bundle ID and data folder:** the app keeps the same bundle ID and the same `~/Library/Application Support/Sequel Pro` folder.
- **Updates:** checking for updates stays off.

## Sequel Plus 2.0.0-RC2

Upgrading from 2.0.0-RC1.

### New for PostgreSQL connections

These toolbar buttons were already visible in RC1 but disabled. They now work, along with their View menu items and shortcuts.

#### Structure
- See a table's columns, indexes and constraints, and edit them in place with the + and − buttons.
- **Columns:**
  - Add a column with its name, type (with length or precision), default, NOT NULL, identity/serial and comment.
  - Rename a column, change its type, change its default, set or drop NOT NULL, edit its comment, or delete it.
  - If existing data won't convert to the new type, the server's error is shown with a conversion expression (`USING column::newtype`) that you can edit and retry.
- **Indexes and constraints:** add and drop indexes, primary keys, and unique, check and foreign-key constraints.
- **Table:** rename it and edit its comment.
- PostgreSQL can't reorder columns, so there is no drag-to-reorder.

#### Relations
- See a table's foreign keys.
- Add and remove them.

#### Triggers
- See a table's triggers and the functions they call.
- Add and remove triggers.

#### Table Info
- Shows the table's owner, row estimate, table, index and total sizes, its comment, and its CREATE statement.

#### Import and Export
- **File ▸ Export…** exports a database, schemas or selected tables as an SQL dump or as CSV.
  - The SQL dump is generated by Sequel Plus itself, so `pg_dump` is not needed. It works with PostgreSQL 12–18.
  - The table list's **Export** menu and the Query view's **Export Result** (CSV) work too.
- **File ▸ Import…** imports an SQL dump or a CSV file.
  - SQL dumps can be Sequel Plus's own or plain-format `pg_dump` files, including their `COPY … FROM stdin` data.
  - CSV can go into an existing table, with column mapping and the delimiter, quote, header-row and NULL options.
  - Custom, directory and tar `pg_dump` formats aren't supported.

#### Duplicate Table
- **Duplicate Table…** in the table list's right-click menu copies a table, optionally with its contents.
- It already worked in RC1; it is listed here because it is part of this release's feature set.

### App
- The About window shows the app name as **Sequel Plus**.
- When no database is connected, the window and tab title read **Sequel Plus** instead of "Sequel Pro".
- The copyright notice now reads "Copyright 2026-2026 Sequel Plus."
- Version **2.0.0-RC2**.

### Still not available for PostgreSQL in RC2

These buttons and menu items are still shown disabled or hidden:
- Sequences and Extensions in the table list
- Users
- Transfer
- Back/forward table history
- Show/Copy Create Syntax

### Unchanged
- **MySQL:** no changes to MySQL connections.
- **Your data:** favorites, saved settings and data are kept from RC1.
- **Bundle ID and data folder:** the app keeps the same bundle ID and the same `~/Library/Application Support/Sequel Pro` folder.
- **Updates:** checking for updates stays off.
