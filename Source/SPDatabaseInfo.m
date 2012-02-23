//
//  $Id$
//
//  SPDatbaseInfo.h
//  sequel-pro
//
//  Created by David Rekowski on Apr 13, 2010
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

#import "SPDBActionCommons.h"
#import "SPDatabaseInfo.h"
#import "SPMySQL.h"

@implementation SPDatabaseInfo

-(BOOL)databaseExists:(NSString *)databaseName 
{
	NSArray *names = [self listDBs];
	
	return [names containsObject:databaseName];
}

- (NSArray *)listDBs 
{
	return [connection databases];
}

- (NSArray *)listDBsLike:(NSString *)dbsName
{
	return [connection databasesLike:dbsName];
}

@end
