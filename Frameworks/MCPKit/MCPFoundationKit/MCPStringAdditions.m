//
//  $Id$
//
//  MCPStringAdditions.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 25, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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



@implementation NSString (MCPStringAdditions)

/**
 * Returns the string quoted with backticks as required for MySQL identifiers
 * eg.:  tablename    =>   `tablename`
 *       my`table     =>   `my``table`
 */
- (NSString *)backtickQuotedString
{
	return [NSString stringWithFormat: @"`%@`", [self stringByReplacingOccurrencesOfString:@"`" withString:@"``"]];
}

/**
 * Returns the string quoted with ticks as required for MySQL identifiers
 * eg.:  tablename    =>   'tablename'
 *       my'table     =>   'my''table'
 */
- (NSString *)tickQuotedString
{
	return [NSString stringWithFormat: @"'%@'", [self stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
}

@end
