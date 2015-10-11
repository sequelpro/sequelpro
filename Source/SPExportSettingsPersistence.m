//
//  SPExportSettingsPersistence.m
//  sequel-pro
//
//  Created by Max Lohrmann on 09.10.15.
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

#import "SPExportSettingsPersistence.h"
#import "SPExportFileNameTokenObject.h"

/**
 * converts a ([obj state] == NSOnState) to @YES / @NO
 * (because doing @([obj state] == NSOnState) will result in an integer 0/1)
 */
static inline NSNumber *IsOn(id obj);

@interface SPExportController (SPExportSettingsPersistence_Private)

+ (NSString *)describeExportSource:(SPExportSource)es;
+ (NSString *)describeExportType:(SPExportType)et;
+ (NSString *)describeCompressionFormat:(SPFileCompressionFormat)cf;
+ (NSString *)describeXMLExportFormat:(SPXMLExportFormat)xf;
+ (NSString *)describeSQLExportInsertDivider:(SPSQLExportInsertDivider)eid;

- (NSDictionary *)exporterSettings;
- (NSDictionary *)csvSettings;
- (NSDictionary *)dotSettings;
- (NSDictionary *)xmlSettings;
- (NSDictionary *)sqlSettings;

- (id)exporterSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (id)dotSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (id)xmlSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (id)csvSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (id)sqlSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;

@end

#pragma mark -

@implementation SPExportController (SPExportSettingsPersistence)

#define NAMEOF(x) case x: return @#x

+ (NSString *)describeExportSource:(SPExportSource)es
{
	switch (es) {
		NAMEOF(SPFilteredExport);
		NAMEOF(SPQueryExport);
		NAMEOF(SPTableExport);
	}
	return nil;
}

+ (NSString *)describeExportType:(SPExportType)et
{
	switch (et) {
		NAMEOF(SPSQLExport);
		NAMEOF(SPCSVExport);
		NAMEOF(SPXMLExport);
		NAMEOF(SPDotExport);
		NAMEOF(SPPDFExport);
		NAMEOF(SPHTMLExport);
		NAMEOF(SPExcelExport);
	}
	return nil;
}

+ (NSString *)describeCompressionFormat:(SPFileCompressionFormat)cf
{
	switch (cf) {
		NAMEOF(SPNoCompression);
		NAMEOF(SPGzipCompression);
		NAMEOF(SPBzip2Compression);
	}
	return nil;
}

+ (NSString *)describeXMLExportFormat:(SPXMLExportFormat)xf
{
	switch (xf) {
		NAMEOF(SPXMLExportMySQLFormat);
		NAMEOF(SPXMLExportPlainFormat);
	}
	return nil;
}

+ (NSString *)describeSQLExportInsertDivider:(SPSQLExportInsertDivider)eid
{
	switch (eid) {
		NAMEOF(SPSQLInsertEveryNDataBytes);
		NAMEOF(SPSQLInsertEveryNRows);
	}
	return nil;
}

#undef NAMEOF

- (IBAction)exportCurrentSettings:(id)sender
{
	//show save file dialog
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setAllowedFileTypes:@[SPFileExtensionDefault]];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];
	
	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode) {
		if(returnCode != NSFileHandlingPanelOKButton) return;
		
		NSError *err = nil;
		NSData *plist = [NSPropertyListSerialization dataWithPropertyList:[self currentSettingsAsDictionary]
																   format:NSPropertyListXMLFormat_v1_0
																  options:0
																	error:&err];
		if(!err) {
			[plist writeToURL:[panel URL] options:NSAtomicWrite error:&err];
			if(!err) return;
		}

		NSAlert *alert = [NSAlert alertWithError:err];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
	}];
}

- (NSArray *)currentCustomFilenameAsArray
{
	NSArray *tokenListIn = [exportCustomFilenameTokenField objectValue];
	NSMutableArray *tokenListOut = [NSMutableArray arrayWithCapacity:[tokenListIn count]];
	
	for (id obj in tokenListIn) {
		if([obj isKindOfClass:[NSString class]]) {
			[tokenListOut addObject:obj];
		}
		else if([obj isKindOfClass:[SPExportFileNameTokenObject class]]) {
			NSDictionary *tokenProperties = @{@"tokenId": [obj tokenId]};
			// in the future the dict can be used to store per-token settings
			[tokenListOut addObject:tokenProperties];
		}
		else {
			SPLog(@"unknown object in token list: %@",obj);
		}
	}
	
	return tokenListOut;
}

- (NSDictionary *)currentSettingsAsDictionary
{
	NSMutableDictionary *root = [NSMutableDictionary dictionary];
	
	[root setObject:@"export settings" forKey:SPFFormatKey];
	[root setObject:@1 forKey:SPFVersionKey];
	
	[root setObject:[exportPathField stringValue] forKey:@"exportPath"];
	
	[root setObject:[[self class] describeExportSource:exportSource] forKey:@"exportSource"];
	[root setObject:[[self class] describeExportType:exportType] forKey:@"exportType"];
	
	if([[exportCustomFilenameTokenField stringValue] length] > 0) {
		[root setObject:[self currentCustomFilenameAsArray] forKey:@"customFilename"];
	}
	
	[root setObject:[self exporterSettings] forKey:@"settings"];
	
	if(exportSource == SPTableExport) {
		NSMutableDictionary *perObjectSettings = [NSMutableDictionary dictionaryWithCapacity:[tables count]];
		
		for (NSMutableArray *table in tables) {
			NSString *key = [table objectAtIndex:0];
			id settings = [self exporterSpecificSettingsForSchemaObject:key ofType:SPTableTypeTable];
			if(settings)
				[perObjectSettings setObject:settings forKey:key];
		}
		
		[root setObject:perObjectSettings forKey:@"schemaObjects"];
	}
	
	[root setObject:IsOn(exportProcessLowMemoryButton) forKey:@"lowMemoryStreaming"];
	[root setObject:[[self class] describeCompressionFormat:(SPFileCompressionFormat)[exportOutputCompressionFormatPopupButton indexOfSelectedItem]] forKey:@"compressionFormat"];
	
	return root;
}

- (NSDictionary *)exporterSettings
{
	switch (exportType) {
		case SPCSVExport:
			return [self csvSettings];
		case SPSQLExport:
			return [self sqlSettings];
		case SPXMLExport:
			return [self xmlSettings];
		case SPDotExport:
			return [self dotSettings];
		case SPExcelExport:
		case SPHTMLExport:
		case SPPDFExport:
		default:
			@throw [NSException exceptionWithName:NSInternalInconsistencyException
										   reason:@"exportType not implemented!"
										 userInfo:@{@"exportType": @(exportType)}];
	}
}

- (NSDictionary *)csvSettings
{
	return @{
		@"exportToMultipleFiles": IsOn(exportFilePerTableCheck),
		@"CSVIncludeFieldNames":  IsOn(exportCSVIncludeFieldNamesCheck),
		@"CSVFieldsTerminated":   [exportCSVFieldsTerminatedField stringValue],
		@"CSVFieldsWrapped":      [exportCSVFieldsWrappedField stringValue],
		@"CSVLinesTerminated":    [exportCSVLinesTerminatedField stringValue],
		@"CSVFieldsEscaped":      [exportCSVFieldsEscapedField stringValue],
		@"CSVNULLValuesAsText":   [exportCSVNULLValuesAsTextField stringValue]
	};
}

- (NSDictionary *)dotSettings
{
	return @{@"DotForceLowerTableNames": IsOn(exportDotForceLowerTableNamesCheck)};
}

- (NSDictionary *)xmlSettings
{
	return @{
		@"exportToMultipleFiles":     IsOn(exportFilePerTableCheck),
		@"XMLFormat":                 [[self class] describeXMLExportFormat:(SPXMLExportFormat)[exportXMLFormatPopUpButton indexOfSelectedItem]],
		@"XMLOutputIncludeStructure": IsOn(exportXMLIncludeStructure),
		@"XMLOutputIncludeContent":   IsOn(exportXMLIncludeContent),
		@"XMLNULLString":             [exportXMLNULLValuesAsTextField stringValue]
	};
}

- (NSDictionary *)sqlSettings
{
	BOOL includeStructure = ([exportSQLIncludeStructureCheck state] == NSOnState);
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
		@"SQLIncludeStructure": IsOn(exportSQLIncludeStructureCheck),
		@"SQLIncludeContent":   IsOn(exportSQLIncludeContentCheck),
		@"SQLIncludeErrors":    IsOn(exportSQLIncludeErrorsCheck),
		@"SQLUseUTF8BOM":       IsOn(exportUseUTF8BOMButton),
		@"SQLBLOBFieldsAsHex":  IsOn(exportSQLBLOBFieldsAsHexCheck),
		@"SQLInsertNValue":     @([exportSQLInsertNValueTextField integerValue]),
		@"SQLInsertDivider":    [[self class] describeSQLExportInsertDivider:(SPSQLExportInsertDivider)[exportSQLInsertDividerPopUpButton indexOfSelectedItem]]
	}];
	
	if(includeStructure) {
		[dict addEntriesFromDictionary:@{
			@"SQLIncludeAutoIncrementValue":  IsOn(exportSQLIncludeAutoIncrementValueButton),
			@"SQLIncludeDropSyntax":          IsOn(exportSQLIncludeDropSyntaxCheck)
		}];
	}
	
	return dict;
}

- (id)exporterSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	switch (exportType) {
		case SPCSVExport:
			return [self csvSpecificSettingsForSchemaObject:name ofType:type];
		case SPSQLExport:
			return [self sqlSpecificSettingsForSchemaObject:name ofType:type];
		case SPXMLExport:
			return [self xmlSpecificSettingsForSchemaObject:name ofType:type];
		case SPDotExport:
			return [self dotSpecificSettingsForSchemaObject:name ofType:type];
		case SPExcelExport:
		case SPHTMLExport:
		case SPPDFExport:
		default:
			@throw [NSException exceptionWithName:NSInternalInconsistencyException
										   reason:@"exportType not implemented!"
										 userInfo:@{@"exportType": @(exportType)}];
	}
}

- (id)dotSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	// Dot is a graph of the whole database - nothing to pick from
	return nil;
}

- (id)xmlSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	// XML per table setting is only yes/no
	if(type == SPTableTypeTable) {
		// we have to look through the table views' rows to find the current checkbox value...
		for (NSArray *table in tables) {
			if([[table objectAtIndex:0] isEqualTo:name]) {
				return @([[table objectAtIndex:2] boolValue]);
			}
		}
	}
	return nil;
}

- (id)csvSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	// CSV per table setting is only yes/no
	if(type == SPTableTypeTable) {
		// we have to look through the table views rows to find the current checkbox value...
		for (NSArray *table in tables) {
			if([[table objectAtIndex:0] isEqualTo:name]) {
				return @([[table objectAtIndex:2] boolValue]);
			}
		}
	}
	return nil;
}

- (id)sqlSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	BOOL structure = ([exportSQLIncludeStructureCheck state] == NSOnState);
	BOOL content   = ([exportSQLIncludeContentCheck state] == NSOnState);
	BOOL drop      = ([exportSQLIncludeDropSyntaxCheck state] == NSOnState);
	
	// SQL allows per table setting of structure/content/drop table
	if(type == SPTableTypeTable) {
		// we have to look through the table views rows to find the current checkbox value...
		for (NSArray *table in tables) {
			if([[table objectAtIndex:0] isEqualTo:name]) {
				NSMutableArray *flags = [NSMutableArray arrayWithCapacity:3];
				
				if (structure && [[table objectAtIndex:1] boolValue]) {
					[flags addObject:@"structure"];
				}
				
				if (content && [[table objectAtIndex:2] boolValue]) {
					[flags addObject:@"content"];
				}
				
				if (drop && [[table objectAtIndex:3] boolValue]) {
					[flags addObject:@"drop"];
				}
			
				return flags;
			}
		}
	}
	return nil;
}

@end

#pragma mark -

NSNumber *IsOn(id obj)
{
	return (([obj state] == NSOnState)? @YES : @NO);
}
