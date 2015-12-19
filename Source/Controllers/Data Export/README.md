# Sequel Pro Exporter Architecture

The export handling in Sequel Pro is designed to be modular, so it is possible to add support for new export formats without changing much (or any) of the surrounding code.

Theoretically it would even be possible to write an exporter as a dylib and load it at runtime (if someone were to write a loader).

## The Export Handler Factory

The entry point for each export format is the export handler factory `id<SPExportHandlerFactory>` which makes the export format known to Sequel Pro.

Each factory can only handle a single export format and will usually act as a singleton. To make your factory known to Sequel Pro you would usually do something like:

```objc
@implementation MyExportHandlerFactory

+ (void)load
{
	[super load];
	[[SPExporterRegistry sharedRegistry] registerExportHandler:[[[self alloc] init] autorelease]];
}

// ...

@end
```

*Note: You could also implement this protocol as class methods on the handler class itself.*

## The Export Controller

The `SPExportController` class coordinates the whole export workflow. It manages the export interface and is the main communication peer of the export handler. You usually want to keep a reference to the export controller that was passed to the factory in `-makeInstanceWithController:`.

Familiarize yourself with this class since it will provide access to the underlying connection objects and other stuff needed for basically every export handler.

## The Export Handler

The factory is a asked to create an instance of the export handler – one per connection window/tab. This happens when creating the connection, which also means that **your export handler is only available to any connections created after registering its factory**.

The export handler acts as the controller between the user interface and the actual export logic. Sequel Pro provides four basic export handler `@protocol`s (you can implement multiple) based on the inputs the export handler accepts.

The UI of the export dialog is broken down into four areas:

* Output directory and filename customization
* Export object selection
* Export format-specific settings
* Advanced options

The export handler has no influence on the first and the last area. However you have full control over the specific settings area via the `-accessoryViewController` of your export handler. Finally, what is displayed in the object selection table depends on which export handler protocols you implement and which export source the user picks.

SPExportSource   | SPExportHandler
---------------- | ---------------
SPFilteredExport | SPResultExportHandler
SPQueryExport    | SPResultExportHandler
SPTableExport    | SPTableExportHandler
SPDatabaseExport | SPDatabaseExportHandler

**Make sure that the protocol(s) you implement match with the results of the factory's `-supportsExportSource:` method.**

### Database Export

`SPDatabaseExportHandler` is the most generic one. It is available as soon as a database is selected and takes no explicit input. You can get access to the connection's properties via the export controller.
The object selection table will always be empty.

The `dot` export format, which provides a graph of the relations between the tables in a schema, implements this protocol. `SPBaseExportHandler` provides a basic implementation to subclass.

### Result Export

`SPResultExportHandler` is also rather simple. 
It takes a single set of tabular data as input, which can either be the result set of a custom query or the data displayed in the Content view.
The object selection table will always be empty.

The `xml` and `csv` export formats implement this protocol.

### Table Export

`SPTableExportHandler` is the most difficult to implement as it is based around a user-configurable selection of schema objects (ie. tables, views, events, relations, stored procedures, …). The protocol consists of methods to start the export, configure the layout of the object selection table and to manipulate the user's selection.

This is not limited to a simple 'Include/Exclude' kind of selection, but you have full control over any additional table columns in the object selection table that you can use to provide a refined selection.

The `csv` and `xml` export formats implement this protocol by inheriting `SPTableBaseExportHandler` to allow a selection of tables/views to include in a content export.

The `sql` export format also implements this protocol albeit in a more complex way as it allows the user to include the DML and/or DDL statements on a per-object basis. `SPTableBaseExportHandler` provides a basic implementation with a binary 'Include/Exclude' semantic, to subclass and extend.

## The Exporter

Every export handler implements one (or more) methods named `-allExportersFor*`. These methods return a set of `NSOperation`s. You should always create a subclass of `SPExporter`, though. It is a convention to use one exporter per schema object.

The export handler should configure every exporter during above-mentioned method call in a way that makes it independent of any later changes to the UI (read: copy the settings). 
The exporter itself will always be invoked on a background thread and if it needs to make calls to other objects (e.g. a delegate) this **must** be performed on the main thread.

### Export Progress

The export controller also provides the methods to control the progress indicator displayed to the user.
Usually you would configure your export handler as the delegate of your exporter(s) and invoke the fitting methods of the export controller in the delegate callbacks.

## Settings Persistence

Every export handler has to implement two methods to save and load the specific settings of the current export handler. Returning `nil` is fine if your handler does not have any settings, but when returning actual objects, the only types supported are `NSString`, `NSNumber`, `NSArray` and `NSDictionary`.

**When loading settings, your export handler must be prepared to silently handle missing settings and unexpected classes!** (I.e. *always* verify that the type of an object matches your expectation before trying to use it!)

The table export handler has to provide two additional methods for saving and loading per-object settings (e.g. whether a table will be exported or not).

## Export workflow

* When opening a new connection tab/window Sequel Pro will ask each export handler factory to provide a new export handler instance for the tab.
* Once the user invokes the export dialog Sequel Pro will pick an export handler it deems most fitting based on a number of factors. (**Important:** the following steps are *not* necessarily executed in the given order!)
  * If Sequel Pro finds previously stored preferences it will re-apply them.
  * The accessory view controller's view will be assigned to the export format-specific settings area
  * If exporting in `SPTableExport` mode, Sequel Pro will ask the export handler about supported schema object types and the configuration of the object selection table.
  * Also in table export mode, it might try to update the list of selected objects, based on what was selected in the UI when invoking the export dialog
  * `willBecomeActive` is called.
* The export dialog will be displayed and the user can change the export options. This can result in nearly all methods of the export handler being invoked. In particular:
  * `didBecomeInactive` and `willBecomeActive` are called when switching the export format tab.
  * The export controller's `exportSource` and `exportToMultipleFiles` properties can change, based on what the user does. Use *Key-Value-Observing* if you need to act on that.
  * The export handler may be asked to save/load it's settings, e.g. when the user presses the "Refresh" button.
  * For a table export the export handler may be asked to change its selection, configure the object selection table's columns as well as act as the datasource for said table view.
* Once the user wishes to start the export, the appropriate `-allExporters*` method will be invoked and the export handler has to prepare and return all exporters according to the current settings.
* Now the export dialog is dismissed,
  * the export handler will be asked to save its settings,
  * `didBecomeInactive` is called 
  * and the export controller enqueues the first exporter.

## Notifications & KVO

Sequel Pro heavily relies on Key-Value-Observing and notifications to provide the export interface and avoid a otherwise hellish complex management of interdependencies between UI elements.
In particular you will have to participate in this via:

* `SPExportController`
  * `exportSource` - Listen for changes if your export handler supports multiple export sources but needs to adapt the specific settings UI based on export source.
  * `exportToMultipleFiles` - Listen for changes if your export handler supports export to multiple files, but this setting affects things like the ability to re-import an export.
  * `SPExportControllerSchemaObjectsChangedNotification` - The controller will post this notification after reloading the list of schema objects. You might want to listen for this notification to re-evaluate if the current selection is valid for export in a table export.
* `SPExportHandler`
  * `canBeImported` - The controller listens for changes to update a warning label about the ability to re-import an export.
  * `isValidForExport` - The controller listens for changes in order to enable/disable the export button.
  * `fileExtension` - The controller will update the displayed export filename if this changes.
  * `tableColumns` (table export only) - The controller will relayout the object selection table view if this changes.
  * `SPExportHandlerSchemaObjectTypeSupportChangedNotification` (table export only) - The controller will listen for this notification and invoke `-canExportSchemaObjectsOfType:` again, once received. **Note:** this may in turn cause a schema objects changed notification from the controller.

Keep in mind that it only really makes sense to listen for (KVO) notifications as long as you are the displayed export handler.
In particular this is what `willBecomeActive` and `didBecomeInactive` are for: so you can update your subscriptions.