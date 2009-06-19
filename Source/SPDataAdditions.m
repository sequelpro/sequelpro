//
//  $Id: SPDataAdditions.m 891 2009-06-19 10:01:14Z bibiko $
//
//  SPDataAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on June 19, 2009
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

#import "SPDataAdditions.h"

static char base64encodingTable[64] = {
'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };


@implementation NSData (SPDataAdditions)

/*
 * Derived from http://colloquy.info/project/browser/trunk/NSDataAdditions.m?rev=1576
 *  Created by khammond on Mon Oct 29 2001.
 *  Formatted by Timothy Hatcher on Sun Jul 4 2004.
 *  Copyright (c) 2001 Kyle Hammond. All rights reserved.
 *  Original development by Dave Winer.
 *
 * Convert self to a base64 encoded NSString
 */
- (NSString *) base64EncodingWithLineLength:(unsigned int)lineLength {

	const unsigned char *bytes = [self bytes];
	unsigned long ixtext = 0;
	unsigned long lentext = [self length];
	long ctremaining = 0;
	unsigned char inbuf[3], outbuf[4];
	short i = 0;
	short charsonline = 0, ctcopy = 0;
	unsigned long ix = 0;

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
