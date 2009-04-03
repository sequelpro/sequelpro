//
//  MCPNull.m
//  SMySQL
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on Sun Jun 02 2002.
//  Copyright (c) 2001 Serge Cohen.
//
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  For a copy of the GNU General Public License, visit <http://www.gnu.org/> or
//  write to the Free Software Foundation, Inc., 59 Temple Place--Suite 330,
//  Boston, MA 02111-1307, USA.
//
//  More info at <http://mysql-cocoa.sourceforge.net/>
//
// $Id: MCPNull.m 334 2006-01-08 20:32:38Z serge $
// $Author: serge $

#import "MCPNull.h"


@implementation NSObject (MCPNSNullTest)
/*"
!{ $Id: MCPNull.m 334 2006-01-08 20:32:38Z serge $ }

This Category is meant to make any kind of object the possible target to the test (isNSNull)
"*/

- (BOOL) isNSNull
{
    return [self isMemberOfClass:[NSNull class]];
}

@end
