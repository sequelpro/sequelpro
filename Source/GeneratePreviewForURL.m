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

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import "SPDataAdditions.h"
#import "SPStringAdditions.h"
#import <Cocoa/Cocoa.h>
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

	NSURL *myURL = (NSURL *)url;
	NSString *urlExtension = [[[myURL path] pathExtension] lowercaseString];

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSError *templateReadError = nil;

	if (QLPreviewRequestIsCancelled(preview))
		return noErr;

	// Get current set file icon
	NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:[myURL path]];

	NSMutableString *html;
	NSString *template = nil;

	if (QLPreviewRequestIsCancelled(preview))
		return noErr;

	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[myURL path] error:nil];

	// Dispatch different fiel extensions
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
			if(spf) [spf release];
			[pool release];
			return noErr;
		}

		// Dispatch different spf formats
		if([[spf objectForKey:@"format"] isEqualToString:@"connection"]) {
			template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginConnectionTemplate" ofType:@"html"] 
				encoding:NSUTF8StringEncoding error:&templateReadError];

			if (template == nil || ![template length] || templateReadError != nil) {
				[pool release];
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
			html = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:template,
				[[iconImage TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01] base64EncodingWithLineLength:0],
				[spf objectForKey:@"rdbms_type"],
				[spf objectForKey:@"rdbms_version"],
				[name stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
				[host stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
				[user stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
				[database stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"],
				[NSString stringForByteSize:[[fileAttributes objectForKey:NSFileSize] longLongValue]],
				[dateFormatter stringFromDate:[fileAttributes fileModificationDate]],
				autoConnect
			]];

			[dateFormatter release];
		}

		else if([[spf objectForKey:@"format"] isEqualToString:@"content filters"]) {
			template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginContentFiltersTemplate" ofType:@"html"] 
				encoding:NSUTF8StringEncoding error:&templateReadError];

			if (template == nil || ![template length] || templateReadError != nil) {
				[pool release];
				return noErr;
			}
			// compose the html
			html = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:template,
				[[iconImage TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01] base64EncodingWithLineLength:0],
				[NSString stringWithContentsOfFile:[myURL path] encoding:NSUTF8StringEncoding error:nil]
			]];
		}

		else if([[spf objectForKey:@"format"] isEqualToString:@"query favorites"]) {
			template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginQueryFavoritesTemplate" ofType:@"html"] 
				encoding:NSUTF8StringEncoding error:&templateReadError];

			if (template == nil || ![template length] || templateReadError != nil) {
				[pool release];
				return noErr;
			}
			// compose the html
			html = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:template,
				[[iconImage TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01] base64EncodingWithLineLength:0],
				[NSString stringWithContentsOfFile:[myURL path] encoding:NSUTF8StringEncoding error:nil]
			]];
		}

		[spf release];

	}

	else if([urlExtension isEqualToString:@"sql"]) {
		template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginSQLTemplate" ofType:@"html"] 
			encoding:NSUTF8StringEncoding error:&templateReadError];

		if (template == nil || ![template length] || templateReadError != nil) {
			[pool release];
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
			NSString *sqlText = [NSString stringWithContentsOfFile:[myURL path] encoding:sqlEncoding error:&readError];
			NSMutableString *sqlHTML = [NSMutableString string];
			NSString *truncatedString = @"";

			if(readError != nil) {
				// cocoa tries to detect the encoding
				sqlText = [NSString stringWithContentsOfFile:[myURL path] usedEncoding:&sqlEncoding error:&readError];
				// fall back to latin1 if no sqlText couldn't read
				if(sqlText == nil) {
					sqlEncoding = NSISOLatin1StringEncoding;
					sqlText = [NSString stringWithContentsOfFile:[myURL path] encoding:sqlEncoding error:&readError];
				}
			}

			// if nothing could be read print ... SQL ...
			if(!sqlText) {
				[sqlHTML appendString:@"... SQL ..."];
			} else {

				// truncate large files since Finder blocks
				if([filesize unsignedLongValue] > kMaxSQLFileSize) {
					sqlText = [sqlText substringToIndex:kMaxSQLFileSize-1];
					truncatedString = @"\n ✂ ...";
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
						[sqlHTML appendString:[sqlText substringWithRange:tokenRange]];
					else
						[sqlHTML appendFormat:@"<font color=%@>%@</font>", tokenColor, [sqlText substringWithRange:tokenRange]];

				}
				[sqlHTML appendString:truncatedString];
			}

			html = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:template,
				[[iconImage TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01] base64EncodingWithLineLength:0],
				[NSString stringForByteSize:[[fileAttributes objectForKey:NSFileSize] longLongValue]],
				sqlHTML
			]];

		} else {

			// No file attributes were read, bail for safety reasons
			[html release];
			[pool release];
			return noErr;

		}

	}

	CFDictionaryRef properties = (CFDictionaryRef)[NSDictionary dictionary];
	QLPreviewRequestSetDataRepresentation(preview,
										  (CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding],
										  kUTTypeHTML, 
										  properties
										  );

	[html release];
	[pool release];
	return noErr;

}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
   // implement only if supported
}

