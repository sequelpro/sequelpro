//
//  SPStringAdditions.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Jan 28, 2009
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

#import "SPStringAdditions.h"

@implementation NSString (SPStringAdditions)

// -------------------------------------------------------------------------------
// stringForByteSize:
//
// Returns a human readable version string of the supplied byte size.
// -------------------------------------------------------------------------------
+ (NSString *)stringForByteSize:(int)byteSize
{
	float size = byteSize;
	
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0 B"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithInt:size]];
	}
	
	size = (size / 1024);
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0.0 KB"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithFloat:size]];
	}
	
	size = (size / 1024);
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0.0 MB"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithFloat:size]];
	}
	
	size = (size / 1024);
	
	[numberFormatter setFormat:@"#,##0.0 GB"];
	
	return [numberFormatter stringFromNumber:[NSNumber numberWithFloat:size]];
}


// -------------------------------------------------------------------------------
// stringForTimeInterval:
//
// Returns a human readable version string of the supplied time interval.
// -------------------------------------------------------------------------------
+ (NSString *)stringForTimeInterval:(float)timeInterval
{
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	if (timeInterval < 1) {
		timeInterval = (timeInterval * 1000);
		[numberFormatter setFormat:@"#,##0 ms"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithFloat:timeInterval]];
	}
	
	if (timeInterval < 100) {
		[numberFormatter setFormat:@"#,##0.0 s"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithFloat:timeInterval]];
	}

	if (timeInterval < 300) {
		[numberFormatter setFormat:@"#,##0 s"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithFloat:timeInterval]];
	}

	if (timeInterval < 3600) {
		timeInterval = (timeInterval / 60);
		[numberFormatter setFormat:@"#,##0 min"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithFloat:timeInterval]];
	}

	timeInterval = (timeInterval / 3600);
	[numberFormatter setFormat:@"#,##0 hours"];

	return [numberFormatter stringFromNumber:[NSNumber numberWithFloat:timeInterval]];
}


// -------------------------------------------------------------------------------
// backtickQuotedString
//
// Returns the string quoted with backticks as required for MySQL identifiers
// eg.:  tablename    =>   `tablename`
//       my`table     =>   `my``table`
// -------------------------------------------------------------------------------
- (NSString *)backtickQuotedString
{
    // mutableCopy automatically retains the returned string, so don't forget to release it later...
    NSMutableString *workingCopy = [self mutableCopy];
    
    // First double all backticks in the string to escape them
    // I don't want to use "stringByReplacingOccurrencesOfString:withString:" because it's only available in 10.5
    [workingCopy replaceOccurrencesOfString: @"`"  
                                  withString: @"``" 
                                     options: NSLiteralSearch 
                                       range: NSMakeRange(0, [workingCopy length]) ];
                                       
    // Add the quotes around the string
	NSString *quotedString = [NSString stringWithFormat:	@"`%@`", workingCopy];
    
    [workingCopy release];
    
    return quotedString;
}

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
	// -------------------------------------------------------------------------------
	// componentsSeparatedByCharactersInSet:
	// Credit - Greg Hulands <ghulands@mac.com>
	// Needed for 10.4+ compatibility
	// -------------------------------------------------------------------------------
	- (NSArray *)componentsSeparatedByCharactersInSet:(NSCharacterSet *)set // 10.5 adds this to NSString, but we are 10.4+
	{ 
		NSMutableArray *result = [NSMutableArray array];
		NSScanner *scanner = [NSScanner scannerWithString:self];
		NSString *chunk = nil;
		
		[scanner setCharactersToBeSkipped:nil];
		BOOL sepFound = [scanner scanCharactersFromSet:set intoString:(NSString **)nil]; // skip any preceding separators
		
		if (sepFound) { // if initial separator, start with empty component
			[result addObject:@""];
		}
		
		while ([scanner scanUpToCharactersFromSet:set intoString:&chunk]) {
			[result addObject:chunk];
			sepFound = [scanner scanCharactersFromSet: set intoString: (NSString **) nil];
		}
		
		if (sepFound) { // if final separator, end with empty component
			[result addObject: @""];
		}
		
		result = [result copy];
		return [result autorelease];
	}
#endif

@end
