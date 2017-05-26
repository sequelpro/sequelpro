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
#import "SPExportFilenameUtilities.h"
#import "SPExportController+SharedPrivateAPI.h"

/**
 * converts a ([obj state] == NSOnState) to @YES / @NO
 * (because doing @([obj state] == NSOnState) will result in an integer 0/1)
 */
static inline NSNumber *IsOn(id obj);
/**
 * Sets the state of obj to NSOnState or NSOffState based on the value of ref
 */
static inline void SetOnOff(NSNumber *ref,id obj);

@interface SPExportController (Private)

- (void)_updateExportAdvancedOptionsLabel;

@end

@interface SPExportController (SPExportSettingsPersistence_Private)

// those methods will convert the name of a C enum constant to a NSString
+ (NSString *)describeExportSource:(SPExportSource)es;
+ (NSString *)describeExportType:(SPExportType)et;
+ (NSString *)describeCompressionFormat:(SPFileCompressionFormat)cf;
+ (NSString *)describeXMLExportFormat:(SPXMLExportFormat)xf;
+ (NSString *)describeSQLExportInsertDivider:(SPSQLExportInsertDivider)eid;

// these will store the C enum constant named by NSString in dst and return YES,
// if a valid mapping exists. Otherwise will just return NO and not modify dst.
+ (BOOL)copyExportSourceForDescription:(NSString *)esd to:(SPExportSource *)dst;
+ (BOOL)copyCompressionFormatForDescription:(NSString *)esd to:(SPFileCompressionFormat *)dst;
+ (BOOL)copyExportTypeForDescription:(NSString *)esd to:(SPExportType *)dst;
+ (BOOL)copyXMLExportFormatForDescription:(NSString *)xfd to:(SPXMLExportFormat *)dst;
+ (BOOL)copySQLExportInsertDividerForDescription:(NSString *)xfd to:(SPSQLExportInsertDivider *)dst;

- (NSDictionary *)exporterSettings;
- (NSDictionary *)csvSettings;
- (NSDictionary *)dotSettings;
- (NSDictionary *)xmlSettings;
- (NSDictionary *)sqlSettings;

- (void)applyExporterSettings:(NSDictionary *)settings;
- (void)applyCsvSettings:(NSDictionary *)settings;
- (void)applyDotSettings:(NSDictionary *)settings;
- (void)applyXmlSettings:(NSDictionary *)settings;
- (void)applySqlSettings:(NSDictionary *)settings;

- (id)exporterSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (id)dotSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (id)xmlSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (id)csvSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (id)sqlSpecificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type;

- (void)applyExporterSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (void)applyDotSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (void)applyXmlSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (void)applyCsvSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type;
- (void)applySqlSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type;

@end

#pragma mark -

@implementation SPExportController (SPExportSettingsPersistence)

#define NAMEOF(x) case x: return @#x
#define VALUEOF(x,y,dst) if([y isEqualToString:@#x]) { *dst = x; return YES; }

+ (NSString *)describeExportSource:(SPExportSource)es
{
	switch (es) {
		NAMEOF(SPFilteredExport);
		NAMEOF(SPQueryExport);
		NAMEOF(SPTableExport);
	}
	return nil;
}

+ (BOOL)copyExportSourceForDescription:(NSString *)esd to:(SPExportSource *)dst
{
	VALUEOF(SPFilteredExport, esd,dst);
	VALUEOF(SPQueryExport,    esd,dst);
	VALUEOF(SPTableExport,    esd,dst);
	return NO;
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
		NAMEOF(SPAnyExportType);
	}
	return nil;
}

+ (BOOL)copyExportTypeForDescription:(NSString *)etd to:(SPExportType *)dst
{
	VALUEOF(SPSQLExport, etd, dst);
	VALUEOF(SPCSVExport, etd, dst);
	VALUEOF(SPXMLExport, etd, dst);
	VALUEOF(SPDotExport, etd, dst);
	//VALUEOF(SPPDFExport, etd, dst);
	//VALUEOF(SPHTMLExport, etd, dst);
	//VALUEOF(SPExcelExport, etd, dst);
	return NO;
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

+ (BOOL)copyCompressionFormatForDescription:(NSString *)cfd to:(SPFileCompressionFormat *)dst
{
	VALUEOF(SPNoCompression,    cfd, dst);
	VALUEOF(SPGzipCompression,  cfd, dst);
	VALUEOF(SPBzip2Compression, cfd, dst);
	return NO;
}

+ (NSString *)describeXMLExportFormat:(SPXMLExportFormat)xf
{
	switch (xf) {
		NAMEOF(SPXMLExportMySQLFormat);
		NAMEOF(SPXMLExportPlainFormat);
	}
	return nil;
}

+ (BOOL)copyXMLExportFormatForDescription:(NSString *)xfd to:(SPXMLExportFormat *)dst
{
	VALUEOF(SPXMLExportMySQLFormat, xfd, dst);
	VALUEOF(SPXMLExportPlainFormat, xfd, dst);
	return NO;
}

+ (NSString *)describeSQLExportInsertDivider:(SPSQLExportInsertDivider)eid
{
	switch (eid) {
		NAMEOF(SPSQLInsertEveryNDataBytes);
		NAMEOF(SPSQLInsertEveryNRows);
	}
	return nil;
}

+ (BOOL)copySQLExportInsertDividerForDescription:(NSString *)eidd to:(SPSQLExportInsertDivider *)dst
{
	VALUEOF(SPSQLInsertEveryNDataBytes, eidd, dst);
	VALUEOF(SPSQLInsertEveryNRows,      eidd, dst);
	return NO;
}

#undef NAMEOF
#undef VALUEOF

- (IBAction)importCurrentSettings:(id)sender
{
	//show open file dialog
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowedFileTypes:@[SPFileExtensionDefault]];
	[panel setAllowsOtherFileTypes:YES];
	
	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
		if(result != NSFileHandlingPanelOKButton) return;
		
		[panel orderOut:nil]; // Panel is still on screen. Hide it first. (This is Apple's recommended way)
		
		NSError *err = nil;
		NSData *plist = [NSData dataWithContentsOfURL:[panel URL]
											  options:0
												error:&err];
		
		NSDictionary *settings = nil;
		if(!err) {
			settings = [NSPropertyListSerialization propertyListWithData:plist
													  options:NSPropertyListImmutable
													   format:NULL
														error:&err];
		}
		
		if(!err) {
			[self applySettingsFromDictionary:settings error:&err];
			if(!err) return;
		}
		
		// give an explanation for some errors
		if([[err domain] isEqualToString:SPErrorDomain]) {
			if([err code] == SPErrorWrongTypeOrNil) {
				NSDictionary *info = @{
					NSLocalizedDescriptionKey:             NSLocalizedString(@"Invalid file supplied!", @"export : import settings : file error title"),
					NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"The selected file is either not a valid SPF file or severely corrupted.", @"export : import settings : file error description"),
				};
				err = [NSError errorWithDomain:[err domain] code:[err code] userInfo:info];
			}
			else if([err code] == SPErrorWrongContentType) {
				NSDictionary *info = @{
					NSLocalizedDescriptionKey:             NSLocalizedString(@"Wrong SPF content type!", @"export : import settings : spf content type error title"),
					NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:NSLocalizedString(@"The selected file contains data of type “%1$@”, but type “%2$@” is needed. Please choose a different file.", @"export : import settings : spf content type error description"),[[err userInfo] objectForKey:@"isType"],[[err userInfo] objectForKey:@"expectedType"]],
				};
				err = [NSError errorWithDomain:[err domain] code:[err code] userInfo:info];
			}
		}
		
		NSAlert *alert = [NSAlert alertWithError:err];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
	}];
}

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
		
		// Panel is still on screen. Hide it first. (This is Apple's recommended way)
		[panel orderOut:nil];
		
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

- (void)setCustomFilenameFromArray:(NSArray *)tokenList
{
	NSMutableArray *tokenListOut = [NSMutableArray arrayWithCapacity:[tokenList count]];
	NSArray *allowedTokens = [self currentAllowedExportFilenameTokens];
	
	for (id obj in tokenList) {
		if([obj isKindOfClass:[NSString class]]) {
			[tokenListOut addObject:obj];
		}
		else if([obj isKindOfClass:[NSDictionary class]]) {
			//there must be at least a non-empty tokenId that is also in the token pool
			NSString *tokenId = [obj objectForKey:@"tokenId"];
			if([tokenId length]) {
				SPExportFileNameTokenObject *token = [SPExportFileNameTokenObject tokenWithId:tokenId];
				if([allowedTokens containsObject:token]) {
					[tokenListOut addObject:token];
					continue;
				}
			}
			SPLog(@"Ignoring an invalid or unknown token with tokenId=%@",tokenId);
		}
		else {
			SPLog(@"unknown object in import token list: %@",obj);
		}
	}
	
	[exportCustomFilenameTokenField setObjectValue:tokenListOut];
	
	[self updateDisplayedExportFilename];
}

- (NSDictionary *)currentSettingsAsDictionary
{
	NSMutableDictionary *root = [NSMutableDictionary dictionary];
	
	[root setObject:SPFExportSettingsContentType forKey:SPFFormatKey];
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

- (BOOL)applySettingsFromDictionary:(NSDictionary *)dict error:(NSError **)err
{
	//check for dict/nil
	if(![dict isKindOfClass:[NSDictionary class]]) {
		if(err) {
			*err = [NSError errorWithDomain:SPErrorDomain
									   code:SPErrorWrongTypeOrNil
								   userInfo:nil]; // we don't know where data came from, so we can't provide meaningful help to the user
		}
		return NO;
	}
	
	//check for export settings
	NSString *ctype = [dict objectForKey:SPFFormatKey];
	if (![SPFExportSettingsContentType isEqualToString:ctype]) {
		if(err) {
			NSDictionary *errInfo = @{
				@"isType":       ctype,
				@"expectedType": SPFExportSettingsContentType
			};
			*err = [NSError errorWithDomain:SPErrorDomain
									   code:SPErrorWrongContentType
								   userInfo:errInfo];
		}
		return NO;
	}
	
	//check for version
	NSInteger version = [[dict objectForKey:SPFVersionKey] integerValue];
	if(version != 1) {
		if(err) {
			NSDictionary *errInfo = @{
				@"isVersion":                          @(version),
				NSLocalizedDescriptionKey:             NSLocalizedString(@"Unsupported version for export settings!", @"export : import settings : file version error title"),
				NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:NSLocalizedString(@"The selected export settings were stored with version\u00A0%1$ld, but only settings with the following versions can be imported: %2$@.\n\nEither save the settings in a backwards compatible way or update your version of Sequel Pro.", @"export : import settings : file version error description ($1 = is version, $2 = list of supported versions); note: the u00A0 is a non-breaking space, do not add more whitespace."),version,@"1"],
			};
			*err = [NSError errorWithDomain:SPErrorDomain
									   code:SPErrorWrongContentVersion
								   userInfo:errInfo];
		}
		return NO;
	}
	
	//ok, we can try to import that...
	
	[exporters removeAllObjects];
	[exportFiles removeAllObjects];
	
	id o;
	if((o = [dict objectForKey:@"exportPath"])) [exportPathField setStringValue:o];
	
	SPExportType et;
	if((o = [dict objectForKey:@"exportType"]) && [[self class] copyExportTypeForDescription:o to:&et]) {
		[exportTypeTabBar selectTabViewItemAtIndex:et];
	}
	
	//exportType should be changed first, as exportSource depends on it
	SPExportSource es;
	if((o = [dict objectForKey:@"exportSource"]) && [[self class] copyExportSourceForDescription:o to:&es]) {
		[self setExportInput:es]; //try to set it. might fail e.g. if the settings were saved with "query result" but right now no custom query result exists
	}

	// set exporter specific settings
	[self applyExporterSettings:[dict objectForKey:@"settings"]];

	// load schema object settings
	if(exportSource == SPTableExport) {
		NSDictionary *perObjectSettings = [dict objectForKey:@"schemaObjects"];
		
		for (NSString *table in [perObjectSettings allKeys]) {
			id settings = [perObjectSettings objectForKey:table];
			[self applyExporterSpecificSettings:settings forSchemaObject:table ofType:SPTableTypeTable];
		}
		
		[exportTableList reloadData];
	}
	
	if((o = [dict objectForKey:@"lowMemoryStreaming"])) [exportProcessLowMemoryButton setState:([o boolValue] ? NSOnState : NSOffState)];
	
	SPFileCompressionFormat cf;
	if((o = [dict objectForKey:@"compressionFormat"]) && [[self class] copyCompressionFormatForDescription:o to:&cf]) [exportOutputCompressionFormatPopupButton selectItemAtIndex:cf];

	// might have changed
	[self _updateExportAdvancedOptionsLabel];

	// token pool is only valid once the schema object selection is done
	[self updateAvailableExportFilenameTokens];
	if((o = [dict objectForKey:@"customFilename"]) && [o isKindOfClass:[NSArray class]]) [self setCustomFilenameFromArray:o];
	
	return YES;
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

- (void)applyExporterSettings:(NSDictionary *)settings
{
	switch (exportType) {
		case SPCSVExport:
			return [self applyCsvSettings:settings];
		case SPSQLExport:
			return [self applySqlSettings:settings];
		case SPXMLExport:
			return [self applyXmlSettings:settings];
		case SPDotExport:
			return [self applyDotSettings:settings];
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
		@"CSVNULLValuesAsText":   [exportCSVNULLValuesAsTextField stringValue],
		@"CSVExportBlobsAsHex":	  IsOn(exportCSVBlobsAsHexidecimalCheck)
	};
}

- (void)applyCsvSettings:(NSDictionary *)settings
{
	id o;
	if((o = [settings objectForKey:@"exportToMultipleFiles"])) SetOnOff(o,exportFilePerTableCheck);
	[self toggleNewFilePerTable:nil];
	
	if((o = [settings objectForKey:@"CSVIncludeFieldNames"]))  SetOnOff(o, exportCSVIncludeFieldNamesCheck);
	if((o = [settings objectForKey:@"CSVFieldsTerminated"]))   [exportCSVFieldsTerminatedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVFieldsWrapped"]))      [exportCSVFieldsWrappedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVLinesTerminated"]))    [exportCSVLinesTerminatedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVFieldsEscaped"]))      [exportCSVFieldsEscapedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVNULLValuesAsText"]))   [exportCSVNULLValuesAsTextField setStringValue:o];
	if((o = [settings objectForKey:@"CSVExportBlobsAsHex"]))   SetOnOff(o, exportCSVBlobsAsHexidecimalCheck);
}

- (NSDictionary *)dotSettings
{
	return @{@"DotForceLowerTableNames": IsOn(exportDotForceLowerTableNamesCheck)};
}

- (void)applyDotSettings:(NSDictionary *)settings
{
	id o;
	if((o = [settings objectForKey:@"DotForceLowerTableNames"])) SetOnOff(o, exportDotForceLowerTableNamesCheck);
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

- (void)applyXmlSettings:(NSDictionary *)settings
{
	id o;
	SPXMLExportFormat xmlf;
	if((o = [settings objectForKey:@"exportToMultipleFiles"]))     SetOnOff(o, exportFilePerTableCheck);
	[self toggleNewFilePerTable:nil];
	
	if((o = [settings objectForKey:@"XMLFormat"]) && [[self class] copyXMLExportFormatForDescription:o to:&xmlf]) [exportXMLFormatPopUpButton selectItemAtIndex:xmlf];
	if((o = [settings objectForKey:@"XMLOutputIncludeStructure"])) SetOnOff(o, exportXMLIncludeStructure);
	if((o = [settings objectForKey:@"XMLOutputIncludeContent"]))   SetOnOff(o, exportXMLIncludeContent);
	if((o = [settings objectForKey:@"XMLNULLString"]))             [exportXMLNULLValuesAsTextField setStringValue:o];
	
	[self toggleXMLOutputFormat:exportXMLFormatPopUpButton];
}

- (NSDictionary *)sqlSettings
{
	BOOL includeStructure = ([exportSQLIncludeStructureCheck state] == NSOnState);
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
		@"SQLIncludeStructure": IsOn(exportSQLIncludeStructureCheck),
		@"SQLIncludeContent":   IsOn(exportSQLIncludeContentCheck),
		@"SQLIncludeErrors":    IsOn(exportSQLIncludeErrorsCheck),
		@"SQLIncludeDROP":      IsOn(exportSQLIncludeDropSyntaxCheck),
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

- (void)applySqlSettings:(NSDictionary *)settings
{
	id o;
	SPSQLExportInsertDivider div;
	
	if((o = [settings objectForKey:@"SQLIncludeContent"]))   SetOnOff(o, exportSQLIncludeContentCheck);
	[self toggleSQLIncludeContent:exportSQLIncludeContentCheck];
	
	if((o = [settings objectForKey:@"SQLIncludeDROP"]))    SetOnOff(o, exportSQLIncludeDropSyntaxCheck);
	[self toggleSQLIncludeDropSyntax:exportSQLIncludeDropSyntaxCheck];
	
	if((o = [settings objectForKey:@"SQLIncludeStructure"])) SetOnOff(o, exportSQLIncludeStructureCheck);
	[self toggleSQLIncludeStructure:exportSQLIncludeStructureCheck];
	
	if((o = [settings objectForKey:@"SQLIncludeErrors"]))    SetOnOff(o, exportSQLIncludeErrorsCheck);
	if((o = [settings objectForKey:@"SQLUseUTF8BOM"]))       SetOnOff(o, exportUseUTF8BOMButton);
	if((o = [settings objectForKey:@"SQLBLOBFieldsAsHex"]))  SetOnOff(o, exportSQLBLOBFieldsAsHexCheck);
	if((o = [settings objectForKey:@"SQLInsertNValue"]))     [exportSQLInsertNValueTextField setIntegerValue:[o integerValue]];
	if((o = [settings objectForKey:@"SQLInsertDivider"]) && [[self class] copySQLExportInsertDividerForDescription:o to:&div]) [exportSQLInsertDividerPopUpButton selectItemAtIndex:div];

	if([exportSQLIncludeStructureCheck state] == NSOnState) {
		if((o = [settings objectForKey:@"SQLIncludeAutoIncrementValue"]))  SetOnOff(o, exportSQLIncludeAutoIncrementValueButton);
		if((o = [settings objectForKey:@"SQLIncludeDropSyntax"]))  SetOnOff(o, exportSQLIncludeDropSyntaxCheck);
	}
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

- (void)applyExporterSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	switch (exportType) {
		case SPCSVExport:
			return [self applyCsvSpecificSettings:settings forSchemaObject:name ofType:type];
		case SPSQLExport:
			return [self applySqlSpecificSettings:settings forSchemaObject:name ofType:type];
		case SPXMLExport:
			return [self applyXmlSpecificSettings:settings forSchemaObject:name ofType:type];
		case SPDotExport:
			return [self applyDotSpecificSettings:settings forSchemaObject:name ofType:type];
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

- (void)applyDotSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	//should never be called
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

- (void)applyXmlSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	// XML per table setting is only yes/no
	if(type == SPTableTypeTable) {
		// we have to look through the table views' rows to find the appropriate table...
		for (NSMutableArray *table in tables) {
			if([[table objectAtIndex:0] isEqualTo:name]) {
				[table replaceObjectAtIndex:2 withObject:@([settings boolValue])];
				return;
			}
		}
	}
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

- (void)applyCsvSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	// CSV per table setting is only yes/no
	if(type == SPTableTypeTable) {
		// we have to look through the table views' rows to find the appropriate table...
		for (NSMutableArray *table in tables) {
			if([[table objectAtIndex:0] isEqualTo:name]) {
				[table replaceObjectAtIndex:2 withObject:@([settings boolValue])];
				return;
			}
		}
	}
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

- (void)applySqlSpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	BOOL structure = ([exportSQLIncludeStructureCheck state] == NSOnState);
	BOOL content   = ([exportSQLIncludeContentCheck state] == NSOnState);
	BOOL drop      = ([exportSQLIncludeDropSyntaxCheck state] == NSOnState);
	
	// SQL allows per table setting of structure/content/drop table
	if(type == SPTableTypeTable) {
		// we have to look through the table views' rows to find the appropriate table...
		for (NSMutableArray *table in tables) {
			if([[table objectAtIndex:0] isEqualTo:name]) {
				NSArray *flags = settings;
				
				[table replaceObjectAtIndex:1 withObject:@((structure && [flags containsObject:@"structure"]))];
				[table replaceObjectAtIndex:2 withObject:@((content   && [flags containsObject:@"content"]))];
				[table replaceObjectAtIndex:3 withObject:@((drop      && [flags containsObject:@"drop"]))];
				return;
			}
		}
	}
}

@end

#pragma mark -

NSNumber *IsOn(id obj)
{
	return (([obj state] == NSOnState)? @YES : @NO);
}

void SetOnOff(NSNumber *ref,id obj)
{
	[obj setState:([ref boolValue] ? NSOnState : NSOffState)];
}
