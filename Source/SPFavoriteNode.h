//
//  $Id$
//
//  SPFavoriteNode.h
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

/**
 * @class SPFavoriteNode SPFavoriteNode.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * This class is designed to be a simple wrapper around a connection favorite to allow us to easily represent
 * them in a tree structure for use in an outline view. If the node is a group item (i.e. a folder) then it
 * should have a name as well as zero or more child nodes. Similarly, actual connection favorite nodes, don't
 * have a name and should have no children.
 */
@interface SPFavoriteNode : NSObject 
{
	BOOL nodeIsGroup;
	NSString *nodeName;
	
	NSDictionary *nodeFavorite;
	NSMutableArray *nodeChildren;
}

/**
 * @property nodeIsGroup Indicates whether this node is a group item
 */
@property (readwrite, assign) BOOL nodeIsGroup;

/**
 * @property nodeName The node's name if it's a group item
 */
@property (readwrite, retain) NSString *nodeName;

/**
 * @property nodeFavorite The actual favorite dictionary
 */
@property (readwrite, retain) NSDictionary *nodeFavorite;

/**
 * @property nodeChildren This node's children
 */
@property (readwrite, retain) NSMutableArray *nodeChildren;

@end
