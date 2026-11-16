#import <Cocoa/Cocoa.h>

@class PGPostgresConnection;
@class SPPostgresTaskRunner;
@class SPPostgresPaginationView;
@class SPPostgresFilter;

/**
 * The Content view of a PostgreSQL tab, laid out as MySQL's Content tab: a filter bar on top (column,
 * comparison, value, Filter; shown or hidden by filterToggleButton, see toggleFilterBar:), the rows in an SPTableView, and MySQL's bottom bar (see addButton). ⌫ or ⌦ in the
 * grid deletes the selected rows (see removeRows:). Built in code.
 * Use on the main thread.
 *
 * Rows come from SPPostgresTableData as PostgreSQL text. The page size is MySQL's "Limit results"
 * preference (unlimited when it is off); NULL is shown as MySQL's NULL placeholder preference, in grey.
 * Header clicks sort ascending, then descending, from the first page. Cells are edited as text, in place or, in edit
 * mode (see toggleEditMode:), in the field editor sheet: ending an edit updates the row on the server. Tables without a
 * primary key, views and generated columns are never edited.
 *
 * A data-layer error is shown as an alert (see alertPresenter); the grid keeps the rows it showed.
 *
 * Loads run through taskRunner: with the tab's background runner a load method returns at once and the end state it
 * documents holds once the runner is idle; a cancelled load shows no alert and keeps what was shown (a cancelled
 * table switch shows the new table's columns, if they came, without rows; Refresh loads it). The short writes (a cell
 * edit, add, duplicate, delete) run on the main thread and are refused (NSBeep) while the runner is busy.
 */
__attribute__((visibility("default")))
@interface SPPostgresContentController : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSPopoverDelegate>

- (instancetype)initWithConnection:(PGPostgresConnection *)connection;

/// Filter bar, grid and bottom bar. Built once; sized by the caller (autoresizes).
- (NSView *)view;

/// Shows the rows of schema.table from the first page, unfiltered and unsorted. A nil table empties the grid.
/// If the rows can't be loaded the error is shown and the grid is empty (only Refresh, to retry, is enabled).
- (void)showTable:(NSString *)table inSchema:(NSString *)schema;

/**
 * As -showTable:inSchema:, starting with theFilter instead of no filter: the filter bar is shown (without changing its
 * preference) holding it, and the first page is the rows it matches. A filter on a column the table doesn't have is
 * dropped. The Content view's foreign key links open their table this way.
 */
- (void)showTable:(NSString *)table inSchema:(NSString *)schema filter:(SPPostgresFilter *)filter;

/// Reloads the current page (keeping the filter and sort). On failure the rows stay and the error is shown.
- (void)reload;

/// Detaches the grid and controls from this controller and drops the presenters (called by the tab on close; also on dealloc).
- (void)invalidate;

- (IBAction)addRow:(id)sender;
/// Asks for confirmation (see confirmationPresenter), then deletes the selected rows.
- (IBAction)removeRows:(id)sender;
/// Inserts a copy of the selected row (one only: with several, MySQL's "You can only copy single rows." error), with
/// new serial and identity values, at the end of this page, and selects it.
- (IBAction)duplicateRow:(id)sender;
- (IBAction)refresh:(id)sender;
/// Writes editModeButton's state to MySQL's "edit in sheet" preference (SPEditInSheetEnabled) in defaults. The button
/// follows that preference, wherever it is changed. While it is on, a cell is edited in the field editor sheet
/// (see fieldEditorPresenter) instead of in place.
- (IBAction)toggleEditMode:(id)sender;
- (IBAction)nextPage:(id)sender;
- (IBAction)previousPage:(id)sender;
/// Applies the filter bar (an empty value, except for IS NULL / IS NOT NULL, removes the filter).
- (IBAction)applyFilter:(id)sender;
/// Shows or hides the filter bar (filterToggleButton) and writes the choice to MySQL's preference
/// (SPRuleFilterEditorLastVisibilityChoice) in defaults. Hiding it while a filter is applied loads the first page
/// unfiltered, keeping the sort.
- (IBAction)toggleFilterBar:(id)sender;
/// Shows or closes MySQL's "Jump to page" popover (paginationPopover, transient) under paginationButton, which is on,
/// with MySQL's button_action image, while it is shown. Showing it puts the current page and the page count in
/// paginationView and the focus in its page field. Needs the view in a window.
- (IBAction)togglePagination:(id)sender;
/// Closes the popover and loads that page with the current filter and sort ("Loading page %lu..."). 0 is page 1;
/// a page past the end shows the last one. Does nothing while the runner is busy.
- (void)goToPage:(NSUInteger)page;

/// The popover's content, on defaults (made again when defaults change).
@property (readonly) SPPostgresPaginationView *paginationView;
/// nil until the popover is first shown.
@property (readonly) NSPopover *paginationPopover;

/// Whether the filter bar is shown (the grid takes its place when it isn't). Read from defaults' "filter bar visible"
/// preference (SPRuleFilterEditorLastVisibilityChoice, hidden when unset) at each -showTable:inSchema:.
@property (readonly, getter=isFilterBarVisible) BOOL filterBarVisible;

@property (readonly) NSTableView *tableView;

/// Where Copy as SQL INSERT puts the selected rows. Default: the general pasteboard.
@property (nonatomic, retain) NSPasteboard *pasteboard;

/// The bottom bar, as MySQL's (DBView.xib): add, delete, duplicate, refresh, edit mode, filter toggle | count, notice |
/// previous, jump to page, next. While the runner is busy every button but the edit mode toggle is disabled.
@property (readonly) NSButton *addButton, *removeButton, *duplicateButton, *refreshButton, *editModeButton, *filterToggleButton, *previousPageButton, *paginationButton, *nextPageButton;
@property (readonly) NSTextField *countField;

/// Where the preferences the view reads (page size, NULL placeholder, table font, gridlines, edit mode, filter bar
/// visibility) come from, and the edit mode and filter toggles and the Jump to page popover's settings write to. Default: standardUserDefaults.
/// The gridlines are read when the view is built.
@property (nonatomic, retain) NSUserDefaults *defaults;
@property (readonly, copy) NSString *schema;
@property (readonly, copy) NSString *table;
/// The names of the shown table's columns, in grid order, as loaded (empty before they come, or with no table).
@property (readonly) NSArray<NSString *> *columnNames;

/// 1-based.
@property (readonly) NSUInteger currentPage;
@property (readonly) NSUInteger pageCount;

/// The bottom bar's row count, as MySQL's (e.g. @"30 rows in table", @"Rows 1 - 7 of 30 from table").
@property (readonly, copy) NSString *countText;
/// The bottom bar's notice: why the rows can't be edited, or @"".
@property (readonly, copy) NSString *noticeText;

/// Runs the loads (default: an inline runner on the connection, so a load has finished when its method returns).
/// With a background runner (the tab's, from Stage 8 Task 7) a load returns at once and is applied when it completes.
@property (retain) SPPostgresTaskRunner *taskRunner;

/// A table switch was cancelled before the table's rows loaded: Refresh (-reload), or the tab showing the view or
/// selecting the table again, loads it.
@property (readonly, getter=isStale) BOOL stale;

/// Shows errors. nil (the default) shows them as sheets on the view's window. Replaceable (the tab routes them through its own).
@property (copy) void (^alertPresenter)(NSAlert *alert);

/// Asks to confirm a deletion; call completion exactly once (later calls are ignored). The completion is a heap
/// block that stays valid until it is called, so a presenter may store it (copying or retaining it is not needed).
/// nil (the default) shows a sheet on the view's window.
@property (copy) void (^confirmationPresenter)(NSAlert *alert, void (^completion)(BOOL confirmed));

/// Edits a cell in a sheet (edit mode on): value is the cell's text (NULL as the NULL placeholder); editable is NO for
/// cells that can't be edited (the sheet then only shows the value). Call completion once with the new value (an
/// NSString or NSNull; the NULL placeholder means NULL where the column allows it), or nil when cancelled; a
/// completion after a table switch or -invalidate, or for a row that is gone, changes nothing. One sheet at a time.
/// nil (the default) shows MySQL's field editor (SPFieldEditorController) as a sheet on the view's window.
@property (copy) void (^fieldEditorPresenter)(NSString *value, NSString *columnName, NSString *typeName, BOOL editable, BOOL allowNull, void (^completion)(id newValue));

/**
 * Foreign keys, as MySQL's Content link arrows: a column that is the first column of a FOREIGN KEY has an arrow after
 * the value of each cell that isn't NULL (none on the cell or row being edited, or on a new row not yet inserted).
 * Clicking it shows the referenced rows: in this view, with an "=" filter on the referenced column, when the key
 * references this table; otherwise through this block (schema, table and column referenced, and the cell's value),
 * NSBeep when it is nil. Nothing happens while the runner is busy (NSBeep).
 */
@property (copy) void (^foreignKeyFollower)(NSString *schema, NSString *table, NSString *column, NSString *value);
/// The shown table's foreign keys (see SPPostgresTableData -foreignKeyReferences:), loaded with its columns (empty
/// when they can't be read).
@property (readonly) NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *foreignKeyReferences;
/// As clicking the link arrow of a cell (row, and the column's index in the table).
- (void)followForeignKeyAtRow:(NSInteger)row column:(NSUInteger)columnIndex;

@end
