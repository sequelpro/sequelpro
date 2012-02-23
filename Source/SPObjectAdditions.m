//
//  $Id$
//
//  SPObjectAdditions.m
//  sequel-pro
//
//  Created by Rowan Beentje (rowan.beent.je) on February 22, 2012
//  Copyright (c) 2012 Rowan Beentje. All rights reserved.
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

@implementation NSObject (SPObjectAdditions)

/**
 * Detect whether an object is a NSNull instance
 */
- (BOOL)isNSNull
{
	id const null = [NSNull null];

	// [NSNull null] is documented as being a singleton class so a pointer equality
	// check is possible - and much faster than checking class membership.
	return (self == null);
}

@end
