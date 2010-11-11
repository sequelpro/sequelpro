//
//  $Id$
//
//  SPFavoriteNode.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 8, 2010
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

#import "SPFavoriteNode.h"

@implementation SPFavoriteNode

@synthesize nodeIsGroup;
@synthesize nodeName;
@synthesize nodeFavorite;
@synthesize nodeChildren;

- (id)init
{
	if ((self = [super init])) {
		[self setNodeIsGroup:NO];
		[self setNodeName:nil];
		[self setNodeFavorite:nil];
		[self setNodeChildren:[[NSMutableArray alloc] init]];
	}
	
	return self;
}

- (void)dealloc
{
	if (nodeName) [nodeName release], nodeName = nil;
	if (nodeFavorite) [nodeFavorite release], nodeFavorite = nil;
	if (nodeChildren) [nodeChildren release], nodeChildren = nil;
	
	[super dealloc];
}

@end
