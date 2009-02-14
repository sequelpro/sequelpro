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

@end
