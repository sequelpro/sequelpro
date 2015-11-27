//
//  SPExportHandlerInstance.h
//  sequel-pro
//
//  Created by Max Lohrmann on 24.11.15.
//  Copyright (c) 2015 Max Lohrmann. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

@protocol SPExportHandlerFactory;
typedef struct {
	NSArray *exporters;
	NSArray *exportFiles;
} SPExportersAndFiles;

extern NSString *SPExportHandlerSchemaObjectTypeSupportChangedNotification;

/**
 * This interface is used for passing information about the schema objects
 * in SPTableExport mode.
 *
 * You can freely use addonData in a export handler to store information you need for the export
 * (e.g. user selection).
 */
@protocol SPExportSchemaObject <NSObject>

@required
@property(readonly, nonatomic, copy) NSString *name;
@property(readonly, nonatomic) SPTableType type;
@property(nonatomic, retain) id addonData;

@end


@protocol SPExportHandlerInstance <NSObject>

@optional

// use this to add observers on the controller.
// will be called right before this handler will become the current export handler
- (void)willBecomeActive;

// the following methods are only needed if you want to support SPTableExport

// decides whether objects of this type will be displayed to the user at all
// If you want to signal a change in the list of supported types, post a
// SPExportHandlerSchemaObjectTypeSupportChangedNotification.
//
// This is an instance method because it can depend on other options. E.g.:
//   In SQL mode if "Include Structure" is disabled, things like procs/funcs/events/… cannot be exported,
//   because they don't have "contents".
- (BOOL)canExportSchemaObjectsOfType:(SPTableType)type;

// must be KVO compliant
// An array of NSString *s.
// The items must be unique. Every item is the internal identifier of an additional table column you need
// to show for the users export options.
@property(readonly, nonatomic, copy) NSArray *tableColumns;

// use this to configure the table columns you requested via the property above.
// The identifier will already be set.
- (void)configureTableColumn:(NSTableColumn *)col;

// data source getter for your additional table columns
- (id)objectValueForTableColumn:(NSTableColumn *)aTableColumn schemaObject:(id<SPExportSchemaObject>)obj;

// data source setter for your additional table columns
- (void)setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn schemaObject:(id<SPExportSchemaObject>)obj;

- (id)specificSettingsForSchemaObject:(id<SPExportSchemaObject>)obj;

// re-apply specific settings for a certain schema object.
// NOTE: It is YOUR responsibility to ensure that the object actually exists and that whatever you try to import is valid
//       for its current type. (i.e. gracefully handle changes to the db structure between save and apply)
- (void)applySpecificSettings:(id)settings forSchemaObject:(id<SPExportSchemaObject>)obj;

/**
 * If the export were to be started now, would the exporter write out any data for a particular object?
 * @param obj The schema object
 * @return YES, if any data would be written (be it structure, content, other metadata…)
 * @note This is **required** when supporting SPTableExport
 *
 * You can send a SPExportHandlerSchemaObjectTypeSupportChangedNotification to signal the controller to re-fetch
 * the results for the current objects.
 */
- (BOOL)wouldIncludeSchemaObject:(id<SPExportSchemaObject>)obj;

/**
 * You can optionally implement this method to enable the "Select all" / "Select none" buttons
 * at the bottom of the export table.
 * @param newState the new state for all objects
 */
- (void)updateIncludeStateForAllSchemaObjects:(BOOL)newState;

@required

- (NSViewController *)accessoryViewController;

- (SPExportersAndFiles)allExporters;

// must be KVO compliant
@property(readonly, nonatomic) BOOL canBeImported;

// must be KVO compliant
@property(readonly, nonatomic) BOOL isValidForExport;

- (NSDictionary *)settings;
- (void)applySettings:(NSDictionary *)settings;

// must be KVO compliant
@property(readonly, nonatomic, copy) NSString *fileExtension;

/**
 * A reference to the factory instance that originally created this object.
 *
 * This is assign because the factory should always outlive the export handler!
 */
@property(readonly, nonatomic, assign) id<SPExportHandlerFactory> factory;

@end
