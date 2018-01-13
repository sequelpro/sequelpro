//
//  GeneratePreviewForURL.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 4, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>

#import "SPDataAdditions.h"
#import "SPEditorTokens.h"
#import "SPSyntaxParser.h"
#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview);

static NSString *PreviewForSPF(NSURL *myURL, NSInteger *previewHeight);
static NSString *PreviewForConnectionSPF(NSDictionary *spf, NSURL *myURL, NSInteger *previewHeight);
static NSString *PreviewForContentFiltersSPF(NSDictionary *spf, NSURL *myURL, NSInteger *previewHeight);
static NSString *PreviewForQueryFavoritesSPF(NSDictionary *spf, NSURL *myURL, NSInteger *previewHeight);
static NSString *PreviewForExportSettingsSPF(NSDictionary *spf, NSURL *myURL, NSInteger *previewHeight);

static NSString *PreviewForSPFS(NSURL *myURL,NSInteger *previewHeight);
static NSString *PreviewForSQL(NSURL *myURL, NSInteger *previewHeight, QLPreviewRequestRef preview);

static inline NSString *PathForHTMLResource(NSString *named)
{
	return [[NSBundle bundleWithIdentifier:@"com.sequelpro.SequelPro.qlgenerator"] pathForResource:named ofType:@"html"];
}

#pragma mark -

/* -----------------------------------------------------------------------------
  Generate a preview for file

  This function's job is to create preview for designated file
  ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSURL *myURL = (NSURL *)url;
	NSString *urlExtension = [[[myURL path] pathExtension] lowercaseString];

	NSString *html = nil;
	NSInteger previewHeight = 280;

	// Dispatch different file extensions
	if([urlExtension isEqualToString:@"spf"]) {
		html = PreviewForSPF(myURL, &previewHeight);
	}
	else if([urlExtension isEqualToString:@"spfs"]) {
		html = PreviewForSPFS(myURL,&previewHeight);
	}
	else if([urlExtension isEqualToString:@"sql"]) {
		html = PreviewForSQL(myURL,&previewHeight,preview);
	}
	
	if(html) {
		NSImage *iconImage;
		
		// Get current Sequel Pro's set of file icons
		NSArray *iconImages = [[[NSWorkspace sharedWorkspace] iconForFile:[myURL path]] representations];
		
		// just in case
		if(!iconImages || [iconImages count] < 1)
			iconImages = @[[NSImage imageNamed:NSImageNameStopProgressTemplate]];
		
		if([iconImages count] > 1)
			iconImage = [iconImages objectAtIndex:1];
		else
			iconImage = [iconImages objectAtIndex:0];
		
#warning This can cause a runtime error: "This application is assuming that a particular image contains an NSBitmapImageRep, which is not a good assumption.  We are instantiating a bitmap so that whatever this is keeps working, but please do not do this. (...)  This may break in the future."
		// TODO: draw the image into a bitmap context and grab the jpeg representation?
		NSData *image = [iconImage TIFFRepresentation];
		
		NSMutableDictionary *props    = [[NSMutableDictionary alloc] initWithCapacity:6];
		NSMutableDictionary *imgProps = [[NSMutableDictionary alloc] initWithCapacity:2];
		
		[props setObject:@(previewHeight) forKey:(NSString *)kQLPreviewPropertyHeightKey];
		[props setObject:@600 forKey:(NSString *) kQLPreviewPropertyWidthKey];
		
		if(image) {
			[imgProps setObject:@"image/tiff" forKey:(NSString *)kQLPreviewPropertyMIMETypeKey];
			[imgProps setObject:image forKey:(NSString *)kQLPreviewPropertyAttachmentDataKey];
		}
		
		[props setObject:@{@"icon.tiff" : imgProps} forKey:(NSString *) kQLPreviewPropertyAttachmentsKey];
		[props setObject:@"UTF-8" forKey:(NSString *)kQLPreviewPropertyTextEncodingNameKey];
		[props setObject:[NSNumber numberWithInt:NSUTF8StringEncoding] forKey:(NSString *)kQLPreviewPropertyStringEncodingKey];
		[props setObject:@"text/html" forKey:(NSString *)kQLPreviewPropertyMIMETypeKey];
		
		QLPreviewRequestSetDataRepresentation(preview,
											  (CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding],
											  kUTTypeHTML,
											  (CFDictionaryRef)props
											  );
		
		[props release];
		[imgProps release];
	}

	[pool release];

	return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
   // Implement only if supported
}

#pragma mark -

NSString *PreviewForSPF(NSURL *myURL, NSInteger *previewHeight) {
	NSDictionary *spf = nil;
	NSError *readError = nil;

	// Get spf data as dictionary
	NSData *pData = [NSData dataWithContentsOfFile:[myURL path]
										   options:NSUncachedRead
											 error:&readError];
	
	if(pData && !readError) {
		spf = [[NSPropertyListSerialization propertyListWithData:pData
														 options:NSPropertyListImmutable
														  format:NULL
														   error:&readError] retain];
	}
	
	NSString *html = nil;
	if(!readError && spf) {
		NSString *spfType = [spf objectForKey:SPFFormatKey];
		NSString *(*fp)(NSDictionary *spf,NSURL *myURL, NSInteger *previewHeight) = NULL;
		// Dispatch different spf formats
		if([spfType isEqualToString:SPFConnectionContentType]) {
			fp = &PreviewForConnectionSPF;
		}
		else if([spfType isEqualToString:SPFContentFiltersContentType]) {
			fp = &PreviewForContentFiltersSPF;
		}
		else if([spfType isEqualToString:SPFQueryFavoritesContentType]) {
			fp = &PreviewForQueryFavoritesSPF;
		}
		else if([spfType isEqualToString:SPFExportSettingsContentType]) {
			fp = &PreviewForExportSettingsSPF;
		}
		
		if(fp) {
			html = (*fp)(spf,myURL,previewHeight);
		}
	}

	[spf release];
	
	return html;
}

NSString *PreviewForConnectionSPF(NSDictionary *spf, NSURL *myURL, NSInteger *previewHeight)
{
	NSError *templateReadError = nil;
	NSString *template = [NSString stringWithContentsOfFile:PathForHTMLResource(@"SPQLPluginConnectionTemplate")
												   encoding:NSUTF8StringEncoding error:&templateReadError];
	
	if (templateReadError != nil || ![template length]) {
		return nil;
	}
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setLocale:[NSLocale currentLocale]];
	
	NSString *name = @"••••";
	NSString *host = @"••••";
	NSString *user = @"••••";
	NSString *database = @"••••";
	NSString *autoConnect = ([[spf objectForKey:@"auto_connect"] boolValue]) ? @"checked" : @"";
	
	if([[spf objectForKey:@"data"] isKindOfClass:[NSDictionary class]]) {
		if([[spf objectForKey:@"data"] objectForKey:@"connection"] && [[[spf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"name"])
			name = [[[spf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"name"];
		else
			name = @"";
		if([[spf objectForKey:@"data"] objectForKey:@"connection"] && [[[spf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"host"])
			host = [[[spf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"host"];
		else
			host = @"";
		if([[spf objectForKey:@"data"] objectForKey:@"connection"] && [[[spf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"user"])
			user = [[[spf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"user"];
		else
			user = @"";
		if([[spf objectForKey:@"data"] objectForKey:@"connection"] && [[[spf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"database"])
			database = [[[spf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"database"];
		else
			database = @"";
	}
	
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[myURL path] error:nil];
	
	// compose the html
	NSString *html = [NSString stringWithFormat:template,
			[spf objectForKey:@"rdbms_type"],
			[spf objectForKey:@"rdbms_version"],
			[name stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
			[host stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
			[user stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
			[database stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
			[NSString stringForByteSize:[[fileAttributes objectForKey:NSFileSize] longLongValue]],
			[dateFormatter stringFromDate:[fileAttributes fileModificationDate]],
			autoConnect
	];
	
	[dateFormatter release];

	return html;
}

NSString *PreviewForContentFiltersSPF(NSDictionary *spf, NSURL *myURL, NSInteger *previewHeight)
{
	NSError *templateReadError = nil;
	NSString *template = [NSString stringWithContentsOfFile:PathForHTMLResource(@"SPQLPluginContentFiltersTemplate")
										 encoding:NSUTF8StringEncoding error:&templateReadError];
	
	if (templateReadError != nil || ![template length]) {
		return nil;
	}
	
	// compose the html
	NSString *html = [NSString stringWithFormat:template,
			[NSString stringWithContentsOfFile:[myURL path] encoding:NSUTF8StringEncoding error:nil]
	];
	
	return html;
}

NSString *PreviewForQueryFavoritesSPF(NSDictionary *spf, NSURL *myURL, NSInteger *previewHeight)
{
	NSError *templateReadError = nil;
	NSString *template = [NSString stringWithContentsOfFile:PathForHTMLResource(@"SPQLPluginQueryFavoritesTemplate")
										 encoding:NSUTF8StringEncoding error:&templateReadError];
	
	if (templateReadError != nil || ![template length]) {
		return nil;
	}
	
	// compose the html
	NSString *html = [NSString stringWithFormat:template,
			[NSString stringWithContentsOfFile:[myURL path] encoding:NSUTF8StringEncoding error:nil]
	];
	
	return html;
}

static inline void MapIf(NSDictionary *src,NSString *key,NSDictionary *map,NSMutableDictionary *dst)
{
	id srcObj, mappedObj;
	
	if((srcObj = [src objectForKey:key])) {
		if((mappedObj = [map objectForKey:srcObj])) {
			[dst setObject:mappedObj forKey:key];
		}
		else {
			[dst setObject:srcObj forKey:key];
		}
	}
}

static inline void CopyIf(NSDictionary *src,NSString *key,NSMutableDictionary *dst)
{
	id srcObj;
	if((srcObj = [src objectForKey:key])) {
		[dst setObject:srcObj forKey:key];
	}
}

NSString *PreviewForExportSettingsSPF(NSDictionary *spf, NSURL *myURL, NSInteger *previewHeight)
{
	NSError *templateReadError = nil;
	NSString *template = [NSString stringWithContentsOfFile:PathForHTMLResource(@"SPQLPluginExportSettingsTemplate")
												   encoding:NSUTF8StringEncoding error:&templateReadError];
	
	if (templateReadError != nil || ![template length]) {
		return nil;
	}
	
	NSMutableDictionary *vars = [NSMutableDictionary dictionary];
	[vars setObject:[[myURL path] lastPathComponent] forKey:@"filename"];
	CopyIf(spf,@"exportPath",vars);
	NSArray *customFilename = [spf objectForKey:@"customFilename"];
	if([customFilename isKindOfClass:[NSArray class]]) {
		NSMutableArray *items = [NSMutableArray array];
		for (id obj in customFilename) {
			if([obj isKindOfClass:[NSString class]])
				[items addObject:@{@"name":obj,@"isToken":@NO}];
			else if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"tokenId"])
				[items addObject:@{@"name": [obj objectForKey:@"tokenId"] ,@"isToken":@YES}];
		}
		[vars setObject:items forKey:@"customFilename"];
	}
	NSDictionary *types = @{
		@"SPSQLExport": @"SQL",
		@"SPCSVExport": @"CSV",
		@"SPXMLExport": @"XML",
		@"SPDotExport": @"Dot",
	};
	MapIf(spf, @"exportType", types, vars);
	
	NSDictionary *compression = @{
		@"SPNoCompression": NSLocalizedString(@"None", @"compression: none"),
		@"SPGzipCompression": @"Gzip",
		@"SPBzip2Compression": @"Bzip2",
	};
	MapIf(spf, @"compressionFormat", compression, vars);
	
	NSDictionary *source = @{
		@"SPQueryExport":    NSLocalizedString(@"Query results", @"export source"),
		@"SPFilteredExport": NSLocalizedString(@"Filtered table content", @"export source"),
		@"SPTableExport":    NSLocalizedString(@"Database", @"export source"),
	};
	MapIf(spf, @"exportSource", source, vars);
	
	CopyIf(spf, @"lowMemoryStreaming", vars);
	
	// compose the html
	MGTemplateEngine *engine = [MGTemplateEngine templateEngine];
	[engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];
	
	NSString *html = [engine processTemplate:template withVariables:vars];
	
	return html;
}

NSString *PreviewForSPFS(NSURL *myURL,NSInteger *previewHeight)
{
	NSError *templateReadError = nil;
	NSString *template = [NSString stringWithContentsOfFile:PathForHTMLResource(@"SPQLPluginConnectionBundleTemplate")
										 encoding:NSUTF8StringEncoding error:&templateReadError];
	
	if (templateReadError != nil || ![template length]) {
		return nil;
	}
	
	NSString *windowTemplate = [NSString stringWithContentsOfFile:PathForHTMLResource(@"SPQLPluginConnectionBundleWindowTemplate")
														 encoding:NSUTF8StringEncoding error:&templateReadError];
	
	if (templateReadError != nil || ![windowTemplate length]) {
		return nil;
	}
	
	NSError *readError = nil;
	NSDictionary *spf = nil;
	
	// Get info.plist data as dictionary
	NSData *pData = [NSData dataWithContentsOfFile:[[myURL path] stringByAppendingPathComponent:@"info.plist"]
										   options:NSUncachedRead
											 error:&readError];
	
	if(pData && !readError) {
		spf = [[NSPropertyListSerialization propertyListWithData:pData
														 options:NSPropertyListImmutable
														  format:NULL
														   error:&readError] retain];
	}
	
	if(!spf || readError) {
		[spf release];
		return nil;
	}
	
	NSMutableString *spfsHTML = [NSMutableString string];
	NSInteger connectionCounter = 0;
	
	NSArray *theWindows = [[[spf objectForKey:@"windows"] reverseObjectEnumerator] allObjects];
	for(NSDictionary *window in theWindows) {
		
		NSInteger tabCounter = 0;
		NSInteger selectedTab = [[window objectForKey:@"selectedTabIndex"] integerValue];
		
		[spfsHTML appendString:@"<table width='100%' border=1 style='border-collapse:collapse;border:2px solid lightgrey'>"];
		
		NSArray *theTabs = [window objectForKey:@"tabs"];
		for(NSDictionary *tab in theTabs) {
			
			connectionCounter++;
			
			if(tabCounter == selectedTab)
				[spfsHTML appendString:@"<tr><td style='background-color:#EEEEEE'>"];
			else
				[spfsHTML appendString:@"<tr><td>"];
			
			NSString *spfPath = @"";
			NSString *spfPathDisplay = @"";
			if([[tab objectForKey:@"isAbsolutePath"] boolValue]) {
				spfPath = [tab objectForKey:@"path"];
				if([spfPath hasPrefix:NSHomeDirectory()]) {
					spfPathDisplay = [spfPath stringByReplacingOccurrencesOfString:NSHomeDirectory() withString:@"~"];
				} else {
					spfPathDisplay = spfPath;
				}
				spfPathDisplay = [NSString stringWithFormat:@"&nbsp;(%@)", spfPathDisplay];
				
			} else {
				spfPathDisplay = @"";
				spfPath = [NSString stringWithFormat:@"%@/Contents/%@", [myURL path], [tab objectForKey:@"path"]];
			}
			
			if(spfPath == nil || ![spfPath length]) {
				[spfsHTML appendString:@"&nbsp;&nbsp;&nbsp;&nbsp;∅"];
				continue;
			}
			// Get info.plist data as dictionary
			NSDictionary *sessionSpf = nil;
			pData = [NSData dataWithContentsOfFile:spfPath options:NSUncachedRead error:&readError];
			if(pData && !readError) {
				sessionSpf = [[NSPropertyListSerialization propertyListWithData:pData
																		options:NSPropertyListImmutable
																		 format:NULL
																		  error:&readError] retain];
			}
			
			if(!sessionSpf || readError) {
				[spfsHTML appendFormat:@"&nbsp;&nbsp;&nbsp;&nbsp;%@&nbsp;∅", [tab objectForKey:@"path"]];
			}
			else {
				
				NSString *name = @"••••";
				NSString *host = @"••••";
				NSString *user = @"••••";
				NSString *database = @"••••";
				
				if([[sessionSpf objectForKey:@"data"] isKindOfClass:[NSDictionary class]]) {
					if([[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] && [[[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"name"])
						name = [[[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"name"];
					else
						name = @"";
					if([[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] && [[[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"host"])
						host = [[[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"host"];
					else
						host = @"";
					if([[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] && [[[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"user"])
						user = [[[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"user"];
					else
						user = @"";
					if([[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] && [[[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"database"])
						database = [[[sessionSpf objectForKey:@"data"] objectForKey:@"connection"] objectForKey:@"database"];
					else
						database = @"";
				}
				
				[spfsHTML appendFormat:windowTemplate,
				 [sessionSpf objectForKey:@"rdbms_type"],
				 [sessionSpf objectForKey:@"rdbms_version"],
				 [name stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
				 spfPathDisplay,
				 [host stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
				 [user stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
				 [database stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"]
					];
			}
			
			tabCounter++;
			
			[spfsHTML appendString:@"</td></tr>"];
			
		}
		
		[spfsHTML appendString:@"</table><br />"];
		
	}
	
	if(connectionCounter > 1 && previewHeight != NULL)
		*previewHeight = 495;
	
	NSString *html = [NSString stringWithFormat:template,
			connectionCounter,
			spfsHTML
	];
	
	[spf release];
	
	return html;
}

NSString *PreviewForSQL(NSURL *myURL, NSInteger *previewHeight, QLPreviewRequestRef preview)
{
	NSError *templateReadError = nil;
	NSString *template = [NSString stringWithContentsOfFile:PathForHTMLResource(@"SPQLPluginSQLTemplate")
										 encoding:NSUTF8StringEncoding error:&templateReadError];
	
	if (templateReadError != nil || ![template length]) {
		return nil;
	}
	
	NSError *readError = nil;
	
	NSStringEncoding sqlEncoding = NSUTF8StringEncoding;
	
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[myURL path] error:nil];
	
	if(!fileAttributes) return nil;
	
	NSNumber *filesize = [fileAttributes objectForKey:NSFileSize];
	NSUInteger kMaxSQLFileSize = (0.7f * 1024 * 1024);
	
	// compose the html and perform syntax highlighting
	
	// read the file and try to get a proper encoding
	NSString *sqlText = [[NSString alloc] initWithContentsOfFile:[myURL path] encoding:sqlEncoding error:&readError];
	NSMutableString *sqlHTML = [[NSMutableString alloc] initWithCapacity:[sqlText length]];
	NSString *truncatedString = [[NSString alloc] init];
	
	if(readError != nil) {
		// cocoa tries to detect the encoding
		sqlText = [[NSString alloc] initWithContentsOfFile:[myURL path] usedEncoding:&sqlEncoding error:&readError];
		// fall back to latin1 if no sqlText couldn't read
		if(sqlText == nil) {
			sqlEncoding = NSISOLatin1StringEncoding;
			sqlText = [[NSString alloc] initWithContentsOfFile:[myURL path] encoding:sqlEncoding error:&readError];
		}
	}
	
	// if nothing could be read print ... SQL ...
	if(!sqlText) {
		[sqlHTML appendString:@"... SQL ..."];
	} else {
		
		// truncate large files since Finder blocks
		if([filesize unsignedLongValue] > kMaxSQLFileSize) {
			NSString *truncatedSqlText = [[NSString alloc] initWithString:[sqlText substringToIndex:kMaxSQLFileSize-1]];
			[sqlText release];
			sqlText = [[NSString alloc] initWithString:truncatedSqlText];
			[truncatedSqlText release];
			[truncatedString release];
			truncatedString = [[NSString alloc] initWithString:@"\n ✂ ..."];
		}
		
		NSString *tokenColor;
		size_t token;
		NSRange tokenRange;
		
		// initialise flex
		yyuoffset = 0; yyuleng = 0;
		yy_switch_to_buffer(yy_scan_string([sqlText UTF8String]));
		BOOL skipFontTag;
		
		// now loop through all the tokens
		NSUInteger poolCount = 0;
		NSAutoreleasePool *loopPool = [[NSAutoreleasePool alloc] init];
		while ((token=yylex())){
			skipFontTag = NO;
			switch (token) {
				case SPT_SINGLE_QUOTED_TEXT:
				case SPT_DOUBLE_QUOTED_TEXT:
					tokenColor = @"#A7221C";
					break;
				case SPT_BACKTICK_QUOTED_TEXT:
					tokenColor = @"#001892";
					break;
				case SPT_RESERVED_WORD:
					tokenColor = @"#0041F6";
					break;
				case SPT_NUMERIC:
					tokenColor = @"#67350F";
					break;
				case SPT_COMMENT:
					tokenColor = @"#265C10";
					break;
				case SPT_VARIABLE:
					tokenColor = @"#6C6C6C";
					break;
				case SPT_WHITESPACE:
					skipFontTag = YES;
					break;
				default:
					skipFontTag = YES;
			}
			
			tokenRange = NSMakeRange(yyuoffset, yyuleng);
			
			if(skipFontTag)
				[sqlHTML appendString:[[sqlText substringWithRange:tokenRange] HTMLEscapeString]];
			else
				[sqlHTML appendFormat:@"<font color=%@>%@</font>", tokenColor, [[sqlText substringWithRange:tokenRange] HTMLEscapeString]];
			
			if (QLPreviewRequestIsCancelled(preview)) {
				if(sqlHTML) SPClear(sqlHTML);
				if(truncatedString) [truncatedString release], sqlHTML = nil;
				if(sqlText) [sqlText release], sqlHTML = nil;
				[loopPool release];
				return nil;
			}
			
			poolCount++;
			if (poolCount > 1000) {
				poolCount = 0;
				[loopPool release];
				loopPool = [[NSAutoreleasePool alloc] init];
			}
		}
		[loopPool release];
		[sqlHTML appendString:truncatedString];
		[sqlText release];
		[truncatedString release];
		
	}
	
	// Wrap lines, and replace tabs with spaces
	[sqlHTML replaceOccurrencesOfString:@"\n" withString:@"<br>" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];
	[sqlHTML replaceOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];
	
	// Improve soft wrapping my making more characters wrap points
	[sqlHTML replaceOccurrencesOfString:@"," withString:@",&#8203;" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];
	
	NSString *html = [NSString stringWithFormat:template,
			[NSString stringForByteSize:[[fileAttributes objectForKey:NSFileSize] longLongValue]],
			sqlHTML
			];
	if(previewHeight != NULL) *previewHeight = 495;
	[sqlHTML release];
	
	return html;
}
