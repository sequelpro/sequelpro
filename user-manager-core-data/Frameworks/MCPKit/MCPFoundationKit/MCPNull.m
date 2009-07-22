//
//  $Id: MCPNull.m 482 2009-04-05 01:38:48Z stuart02 $
//
//  MCPNull.m
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 02/06/2002.
//  Copyright (c) 2001 Serge Cohen. All rights reserved.
//
//  Forked by the Sequel Pro team (sequelpro.com), April 2009
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
//  More info at <http://mysql-cocoa.sourceforge.net/>
//  More info at <http://code.google.com/p/sequel-pro/>

#import "MCPNull.h"

@implementation NSObject (MCPNSNullTest)

/**
 * This Category is meant to make any kind of object the possible target to the test (isNSNull).
 */
- (BOOL) isNSNull
{
    return [self isMemberOfClass:[NSNull class]];
}

@end
