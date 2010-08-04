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
#import <Cocoa/Cocoa.h>

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

static char base64encodingTable[64] = {
'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };

@interface NSData (QLDataAdditions)

- (NSString *)base64EncodingWithLineLength:(NSUInteger)lineLength;

@end


@implementation NSData (QLDataAdditions)

/*
 * Derived from http://colloquy.info/project/browser/trunk/NSDataAdditions.m?rev=1576
 *  Created by khammond on Mon Oct 29 2001.
 *  Formatted by Timothy Hatcher on Sun Jul 4 2004.
 *  Copyright (c) 2001 Kyle Hammond. All rights reserved.
 *  Original development by Dave Winer.
 *
 * Convert self to a base64 encoded NSString
 */
- (NSString *) base64EncodingWithLineLength:(NSUInteger)lineLength {

	const unsigned char *bytes = [self bytes];
	NSUInteger ixtext = 0;
	NSUInteger lentext = [self length];
	NSInteger ctremaining = 0;
	unsigned char inbuf[3], outbuf[4];
	short i = 0;
	short charsonline = 0, ctcopy = 0;
	NSUInteger ix = 0;

	NSMutableString *base64 = [NSMutableString stringWithCapacity:lentext];

	while(1) {
		ctremaining = lentext - ixtext;
		if( ctremaining <= 0 ) break;

		for( i = 0; i < 3; i++ ) {
			ix = ixtext + i;
			if( ix < lentext ) inbuf[i] = bytes[ix];
			else inbuf [i] = 0;
		}

		outbuf [0] = (inbuf [0] & 0xFC) >> 2;
		outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
		outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
		outbuf [3] = inbuf [2] & 0x3F;
		ctcopy = 4;

		switch( ctremaining ) {
			case 1: 
			ctcopy = 2; 
			break;
			case 2: 
			ctcopy = 3; 
			break;
		}

		for( i = 0; i < ctcopy; i++ )
			[base64 appendFormat:@"%c", base64encodingTable[outbuf[i]]];

		for( i = ctcopy; i < 4; i++ )
			[base64 appendFormat:@"%c",'='];

		ixtext += 3;
		charsonline += 4;

		if( lineLength > 0 ) {
			if (charsonline >= lineLength) {
				charsonline = 0;
				[base64 appendString:@"\n"];
			}
		}
	}

	return base64;
}
@end

@interface NSString (QLStringAdditions)

+ (NSString *)stringForByteSize:(long long)byteSize;

@end

@implementation NSString (QLStringAdditions)

/*
 * Returns a human readable version string of the supplied byte size.
 */
+ (NSString *)stringForByteSize:(long long)byteSize
{
	CGFloat size = byteSize;
	
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0 B"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithInteger:size]];
	}
	
	size = (size / 1024);
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0.0 KiB"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
	}
	
	size = (size / 1024);
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0.0 MiB"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
	}
	
	size = (size / 1024);
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0.0 GiB"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
	}

	size = (size / 1024);
	
	[numberFormatter setFormat:@"#,##0.0 TiB"];
	
	return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
}
@end

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{

	NSURL *myURL = (NSURL *)url;
	NSString *urlExtension = [[[myURL path] pathExtension] lowercaseString];
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSError *templateReadError = nil;

	NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:[myURL path]];

	NSMutableString *html;
	NSString *template = nil;

	if (false == QLPreviewRequestIsCancelled(preview)) {

		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[myURL path] error:nil];

		if([urlExtension isEqualToString:@"spf"]) {

			NSError *readError = nil;
			NSString *convError = nil;
			NSPropertyListFormat format;
			NSDictionary *spf = nil;

			NSData *pData = [NSData dataWithContentsOfFile:[myURL path] options:NSUncachedRead error:&readError];

			spf = [[NSPropertyListSerialization propertyListFromData:pData 
					mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

			if(!spf || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
				if(spf) [spf release];
				[pool release];
				return noErr;
			}

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
				[spf release];

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
		}
		else if([urlExtension isEqualToString:@"sql"]) {
			template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.google.code.sequel-pro.qlgenerator"] pathForResource:@"SPQLPluginSQLTemplate" ofType:@"html"] 
				encoding:NSUTF8StringEncoding error:&templateReadError];

			if (template == nil || ![template length] || templateReadError != nil) {
				[pool release];
				return noErr;
			}

			// compose the html
			if(fileAttributes)
			{
				NSNumber *filesize = [fileAttributes objectForKey:NSFileSize];
				// catch large files since Finder blocks
				if([filesize unsignedLongValue] > 6000000) {
					html = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:template,
						[[iconImage TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01] base64EncodingWithLineLength:0],
						[NSString stringForByteSize:[[fileAttributes objectForKey:NSFileSize] longLongValue]],
						@"... SQL ..."
					]];
				} else {
					html = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:template,
						[[iconImage TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01] base64EncodingWithLineLength:0],
						[NSString stringForByteSize:[[fileAttributes objectForKey:NSFileSize] longLongValue]],
						[NSString stringWithContentsOfFile:[myURL path] encoding:NSUTF8StringEncoding error:nil]
					]];
				}
			} else {
				html = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:template,
					[[iconImage TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01] base64EncodingWithLineLength:0],
					[NSString stringForByteSize:[[fileAttributes objectForKey:NSFileSize] longLongValue]],
					[NSString stringWithContentsOfFile:[myURL path] encoding:NSUTF8StringEncoding error:nil]
				]];
			}
		}

		CFDictionaryRef properties = (CFDictionaryRef)[NSDictionary dictionary];
		QLPreviewRequestSetDataRepresentation(preview,
											  (CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding],
											  kUTTypeHTML, 
											  properties
											  );
		[html release];
		
	}
	[pool release];
    return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
