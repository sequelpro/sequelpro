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
#import "SPExportHandlerFactory.h"
#import "SPExporterRegistry.h"

@interface SPExportController (SPExportSettingsPersistence_Private)

// those methods will convert the name of a C enum constant to a NSString
+ (NSString *)describeExportSource:(SPExportSource)es;
+ (NSString *)describeCompressionFormat:(SPFileCompressionFormat)cf;

// these will store the C enum constant named by NSString in dst and return YES,
// if a valid mapping exists. Otherwise will just return NO and not modify dst.
+ (BOOL)copyExportSourceForDescription:(NSString *)esd to:(SPExportSource *)dst;
+ (BOOL)copyCompressionFormatForDescription:(NSString *)esd to:(SPFileCompressionFormat *)dst;

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
		NAMEOF(SPDatabaseExport);
	}
	return nil;
}

+ (BOOL)copyExportSourceForDescription:(NSString *)esd to:(SPExportSource *)dst
{
	VALUEOF(SPFilteredExport, esd,dst);
	VALUEOF(SPQueryExport,    esd,dst);
	VALUEOF(SPTableExport,    esd,dst);
	VALUEOF(SPDatabaseExport, esd,dst);
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
		if(IS_STRING(obj)) {
			[tokenListOut addObject:obj];
		}
		else if(IS_TOKEN(obj)) {
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

- (NSString *)currentCustomFilenameAsString
{
	NSArray *tokenListIn = [exportCustomFilenameTokenField objectValue];
	NSMutableString *tokenStringOut = [NSMutableString string];
	
	for (id obj in tokenListIn) {
		if(IS_STRING(obj)) {
			[tokenStringOut appendString:obj];
		}
		else if(IS_TOKEN(obj)) {
			// in the future needs to include per-token settings
			[tokenStringOut appendFormat:@"{%@}",[obj tokenId]];
		}
		else {
			SPLog(@"unknown object in token list: %@",obj);
		}
	}
	
	return tokenStringOut;
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
	
	[root setObject:[self exportPath] forKey:@"exportPath"];
	
	[root setObject:[[self class] describeExportSource:exportSource] forKey:@"exportSource"];
	[root setObject:[[[self currentExportHandler] factory] uniqueName] forKey:@"exportType"];
	
	if([[exportCustomFilenameTokenField stringValue] length] > 0) {
		[root setObject:[self currentCustomFilenameAsArray] forKey:@"customFilename"];
	}

	NSAssert([[self currentExportHandler] respondsToSelector:@selector(settings)],@"export handler %@ is missing mandatory method settings!",[self currentExportHandler]);
	[root setObject:[[self currentExportHandler] settings] forKey:@"settings"];
	
	if(exportSource == SPTableExport) {
		NSAssert([[self currentExportHandler] respondsToSelector:@selector(specificSettingsForSchemaObject:)],@"export handler %@ is missing method specificSettingsForSchemaObject: mandatory for table export!",[self currentExportHandler]);
		NSMutableDictionary *perObjectSettings = [NSMutableDictionary dictionaryWithCapacity:[exportObjectList count]];
		
		for (_SPExportListItem *item in exportObjectList) {
			// skip visual only objects
			if([item isGroupRow]) continue;
			NSString *key = [item name];
			id settings = [(id<SPTableExportHandler>)[self currentExportHandler] specificSettingsForSchemaObject:item];
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
	
	id o = nil;
	if((o = [dict objectForKey:@"exportPath"])) [exportPathField setStringValue:o];
	
	// check that we actually know that export handler or abort
	BOOL peristedHandlerIsValid = NO;
	if((o = [dict objectForKey:@"exportType"]) && [[SPExporterRegistry sharedRegistry] handlerNamed:o]) {
		NSString *actual = [self setExportHandlerIfPossible:o];
		if([actual isEqualToString:o]) peristedHandlerIsValid = YES;
	}
	else {
		if(err) {
			NSDictionary *errInfo = @{
					@"exportType":                         (o? o : [NSNull null]),
					NSLocalizedDescriptionKey:             NSLocalizedString(@"Unknown export format for export settings!", @"export : import settings : unknown export handler error title"),
					NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:NSLocalizedString(@"The selected export settings define export format “%@” which is not supported by this version of Sequel Pro.\n\nEither save the settings in a backwards compatible way or update your version of Sequel Pro.", @"export : import settings : unknown export handler description ($1 = export handler internal name)"),o],
			};
			*err = [NSError errorWithDomain:SPErrorDomain
			                           code:SPErrorUnknownIdentifier
			                       userInfo:errInfo];
		}
		return NO;
	}
	
	//exportType should be changed first, as exportSource depends on it
	SPExportSource es;
	if((o = [dict objectForKey:@"exportSource"]) && [[self class] copyExportSourceForDescription:o to:&es]) {
		[self setExportSourceIfPossible:es]; //try to set it. might fail e.g. if the settings were saved with "query result" but right now no custom query result exists
	}
	else if(exportSource == SPTableExport) {
		// setExportSourceIfPossible: would update the schema objects to which we apply specific settings below.
		// if it is not called we have to do that
		[self _refreshTableListKeepingState:NO fromServer:NO];
	}

	// the handler we have settings for might not be valid right now. E.g.
	//  User does SQL export (-> settings are persisted for SQL),
	//  Closes connection, opens a new one,
	//  Without having a DB selected, does a custom query and wants to export the results
	//  => SQL export is not valid, no point in trying to apply settings
	if(peristedHandlerIsValid) {
		// set exporter specific settings
		NSAssert([[self currentExportHandler] respondsToSelector:@selector(applySettings:)],@"export handler %@ is missing mandatory method applySettings:",[self currentExportHandler]);
		[[self currentExportHandler] applySettings:[dict objectForKey:@"settings"]];
		
		// load schema object settings
		if(exportSource == SPTableExport) {
			NSAssert([[self currentExportHandler] respondsToSelector:@selector(applySpecificSettings:forSchemaObject:)],@"export handler %@ is missing mandatory method applySpecificSettings:forSchemaObject: for table export!",[self currentExportHandler]);
			NSDictionary *perObjectSettings = [dict objectForKey:@"schemaObjects"];
			
			for (NSString *table in [perObjectSettings allKeys]) {
				id settings = [perObjectSettings objectForKey:table];
				//we have to find the current object to apply the settings onto
				id<SPExportSchemaObject> obj = [self schemaObjectNamed:table];
				if (obj) [(id<SPTableExportHandler>)[self currentExportHandler] applySpecificSettings:settings forSchemaObject:obj];
			}
			
			[exportTableList reloadData];
		}
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

@end
