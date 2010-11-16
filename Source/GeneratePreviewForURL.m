//
//  $Id$
//
//  GeneratePreviewForURL.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on Aug 04, 2010
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import "SPDataAdditions.h"
#import "SPEditorTokens.h"

/* -----------------------------------------------------------------------------
  Generate a preview for file

  This function's job is to create preview for designated file
  ----------------------------------------------------------------------------- */


#pragma mark lex init

/*
* Include all the extern variables and prototypes required for flex (used for syntax highlighting)
*/
extern NSUInteger yylex();
extern NSUInteger yyuoffset, yyuleng;
typedef struct yy_buffer_state *YY_BUFFER_STATE;
void yy_switch_to_buffer(YY_BUFFER_STATE);
YY_BUFFER_STATE yy_scan_string (const char *);



OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSURL *myURL = (NSURL *)url;
	NSString *urlExtension = [[[myURL path] pathExtension] lowercaseString];

	NSError *templateReadError = nil;

	NSString *html = @"";
	NSString *template = nil;

	NSInteger previewHeight = 280;

	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[myURL path] error:nil];

	// Dispatch different file extensions
	if([urlExtension isEqualToString:@"spf"]) {

		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;
		NSDictionary *spf = nil;

		// Get spf data as dictionary
		NSData *pData = [NSData dataWithContentsOfFile:[myURL path] options:NSUncachedRead error:&readError];
		spf = [[NSPropertyListSerialization propertyListFromData:pData 
				mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

		if(!spf || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
			if(spf) [spf release], spf = nil;
			if(pool) [pool release], pool = nil;
			return noErr;
		}

		// Dispatch different spf formats
		if([[spf objectForKey:@"format"] isEqualToString:@"connection"]) {
			template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginConnectionTemplate" ofType:@"html"] 
				encoding:NSUTF8StringEncoding error:&templateReadError];

			if (template == nil || ![template length] || templateReadError != nil) {
				if(spf) [spf release], spf = nil;
				if(pool) [pool release], pool = nil;
				return noErr;
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

			// compose the html
			html = [NSString stringWithFormat:template,
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
		}

		else if([[spf objectForKey:@"format"] isEqualToString:@"content filters"]) {

			template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginContentFiltersTemplate" ofType:@"html"] 
				encoding:NSUTF8StringEncoding error:&templateReadError];

			if (template == nil || ![template length] || templateReadError != nil) {
				if(spf) [spf release], spf = nil;
				if(pool) [pool release], pool = nil;
				return noErr;
			}
			// compose the html
			html = [NSString stringWithFormat:template,
				[NSString stringWithContentsOfFile:[myURL path] encoding:NSUTF8StringEncoding error:nil]
			];
		}

		else if([[spf objectForKey:@"format"] isEqualToString:@"query favorites"]) {

			template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginQueryFavoritesTemplate" ofType:@"html"] 
				encoding:NSUTF8StringEncoding error:&templateReadError];

			if (template == nil || ![template length] || templateReadError != nil) {
				if(spf) [spf release], spf = nil;
				if(pool) [pool release], pool = nil;
				return noErr;
			}
			// compose the html
			html = [NSString stringWithFormat:template,
				[NSString stringWithContentsOfFile:[myURL path] encoding:NSUTF8StringEncoding error:nil]
			];
		}

		[spf release];

	}

	else if([urlExtension isEqualToString:@"spfs"]) {

		template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginConnectionBundleTemplate" ofType:@"html"] 
			encoding:NSUTF8StringEncoding error:&templateReadError];

		if (template == nil || ![template length] || templateReadError != nil) {
			if(pool) [pool release], pool = nil;
			return noErr;
		}

		NSString *windowTemplate = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginConnectionBundleWindowTemplate" ofType:@"html"] 
			encoding:NSUTF8StringEncoding error:&templateReadError];

		if (windowTemplate == nil || ![windowTemplate length] || templateReadError != nil) {
			if(pool) [pool release], pool = nil;
			return noErr;
		}

		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;
		NSDictionary *spf = nil;

		// Get info.plist data as dictionary
		NSData *pData = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/info.plist", [myURL path]] options:NSUncachedRead error:&readError];
		spf = [[NSPropertyListSerialization propertyListFromData:pData 
				mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

		if(!spf || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
			if(spf) [spf release], spf = nil;
			if(pool) [pool release], pool = nil;
			return noErr;
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
				NSDictionary *sessionSpf;
				NSData *pData = [NSData dataWithContentsOfFile:spfPath options:NSUncachedRead error:&readError];
				sessionSpf = [[NSPropertyListSerialization propertyListFromData:pData 
						mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

				if(!sessionSpf || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
					[spfsHTML appendFormat:@"&nbsp;&nbsp;&nbsp;&nbsp;%@&nbsp;∅", [tab objectForKey:@"path"]];
				} else {

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

		if(connectionCounter > 1)
			previewHeight = 495;

		html = [NSString stringWithFormat:template,
			connectionCounter,
			spfsHTML
		];
		

	}

	else if([urlExtension isEqualToString:@"sql"]) {

		template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginSQLTemplate" ofType:@"html"] 
			encoding:NSUTF8StringEncoding error:&templateReadError];

		if (template == nil || ![template length] || templateReadError != nil) {
			if(pool) [pool release], pool = nil;
			return noErr;
		}

		NSError *readError = nil;

		NSStringEncoding sqlEncoding = NSUTF8StringEncoding;

		if(fileAttributes)
		{

			NSNumber *filesize = [fileAttributes objectForKey:NSFileSize];
			NSUInteger kMaxSQLFileSize = (0.7 * 1024 * 1024);

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

				NSRange textRange = NSMakeRange(0, [sqlText length]);
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
				while (token=yylex()){
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
						if(sqlHTML) [sqlHTML release], sqlHTML = nil;
						if(truncatedString) [truncatedString release], sqlHTML = nil;
						if(sqlText) [sqlText release], sqlHTML = nil;
						if(pool) [pool release], pool = nil;
						[loopPool release];
						return noErr;
					}

					poolCount++;
					if (poolCount > 1000) {
						poolCount = 0;
						[loopPool release];
						loopPool = [[NSAutoreleasePool alloc] init];
					}
				}
				[loopPool release];
				[sqlHTML appendString:sqlText];
				[sqlHTML appendString:truncatedString];
				[sqlText release];
				[truncatedString release];

			}

			// Wrap lines, and replace tabs with spaces
			[sqlHTML replaceOccurrencesOfString:@"\n" withString:@"<br>" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];
			[sqlHTML replaceOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];

			// Improve soft wrapping my making more characters wrap points
			[sqlHTML replaceOccurrencesOfString:@"," withString:@",&#8203;" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];
			[sqlHTML replaceOccurrencesOfString:@"/" withString:@"/&#8203;" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];

			html = [NSString stringWithFormat:template,
				[NSString stringForByteSize:[[fileAttributes objectForKey:NSFileSize] longLongValue]],
				sqlHTML
			];
			previewHeight = 495;
			[sqlHTML release];

		} else {

			// No file attributes were read, bail for safety reasons
			if(pool) [pool release], pool = nil;
			return noErr;

		}

	}

	NSMutableDictionary *props,*imgProps;
	NSData *image;

	NSImage *iconImage;

	// Get current Sequel Pro's set of file icons
	NSArray *iconImages = [[[NSWorkspace sharedWorkspace] iconForFile:[myURL path]] representations];

	// just in case
	if(!iconImages || [iconImages count] < 1)
		iconImages = [NSArray arrayWithObject:[NSImage imageNamed:NSImageNameStopProgressTemplate]];

	if([iconImages count] > 0)
		iconImage = [iconImages objectAtIndex:1];
	else
		iconImage = [iconImages objectAtIndex:0];

	image = [iconImage TIFFRepresentation];

	props    = [[NSMutableDictionary alloc] initWithCapacity:6];
	imgProps = [[NSMutableDictionary alloc] initWithCapacity:2];

	[props setObject:[NSNumber numberWithInt:previewHeight] forKey:(NSString *)kQLPreviewPropertyHeightKey];
	[props setObject:[NSNumber numberWithInt:600] forKey:(NSString *)kQLPreviewPropertyWidthKey];

	if(image) {
		[imgProps setObject:@"image/tiff" forKey:(NSString *)kQLPreviewPropertyMIMETypeKey];
		[imgProps setObject:image forKey:(NSString *)kQLPreviewPropertyAttachmentDataKey];
	}

	[props setObject:[NSDictionary dictionaryWithObject:imgProps forKey:@"icon.tiff"] forKey:(NSString *)kQLPreviewPropertyAttachmentsKey];
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

	[pool release];

	return noErr;

}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
   // implement only if supported
}

