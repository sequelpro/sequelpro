//
//  $Id$
//
//  CMMCPResult.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed Sept 21 2005.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
#import <MCPKit_bundled/MCPKit_bundled.h>

#define FIELD_TYPE_BIT          16
#define MAGIC_BINARY_CHARSET_NR 63

@interface CMMCPResult : MCPResult

typedef struct st_our_charset
{
	unsigned int	nr;
	const char		*name;
	const char		*collation;
	unsigned int	char_minlen;
	unsigned int	char_maxlen;
} OUR_CHARSET;


- (id)fetchRowAsType:(MCPReturnType)aType;
- (NSArray *)fetchResultFieldsStructure;


- (NSString *)mysqlTypeToStringForType:(unsigned int)type withCharsetNr:(unsigned int)charsetnr withFlags:(unsigned int)flags withLength:(unsigned long long)length;
- (NSString *)mysqlTypeToGroupForType:(unsigned int)type withCharsetNr:(unsigned int)charsetnr withFlags:(unsigned int)flags;
- (NSString *)find_charsetName:(unsigned int)charsetnr;
- (NSString *)find_charsetCollation:(unsigned int)charsetnr;
- (unsigned int)find_charsetMaxByteLengthPerChar:(unsigned int)charsetnr;

@end
