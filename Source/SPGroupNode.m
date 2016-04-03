//
//  SPGroupNode.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 21, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPGroupNode.h"

// Constants
static NSString *SPGroupNodeNameKey = @"SPGroupNodeName";
static NSString *SPGroupNodeIsExpandedKey = @"SPGroupNodeIsExpanded";

@implementation SPGroupNode

@synthesize nodeName;
@synthesize nodeIsExpanded;

#pragma mark -
#pragma mark Initialisation

- (id)init
{
	if ((self = [super init])) {
		[self setNodeName:nil];
		[self setNodeIsExpanded:YES];
	}
	
	return self;
}

- (id)initWithName:(NSString *)name
{
	if ((self = [self init])) {
		[self setNodeName:name];
	}
	
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if ((self = [self initWithName:[dict objectForKey:SPFavoritesGroupNameKey]])) {
		[self setNodeIsExpanded:[(NSNumber *)[dict objectForKey:SPFavoritesGroupIsExpandedKey] boolValue]];
	}
	
	return self;
}

+ (SPGroupNode *)groupNodeWithName:(NSString *)name
{
	return [[[self alloc] initWithName:name] autorelease];
}

+ (SPGroupNode *)groupNodeWithDictionary:(NSDictionary *)dict
{
	return [[[self alloc] initWithDictionary:dict] autorelease];
}

#pragma mark -
#pragma mark Copying protocol methods

- (id)copyWithZone:(NSZone *)zone
{
	SPGroupNode *node = [[[self class] allocWithZone:zone] init];
	
	[node setNodeName:[self nodeName]];
	[node setNodeIsExpanded:[self nodeIsExpanded]];
	
	return node;
}

#pragma mark -
#pragma mark Coding protocol methods

- (id)initWithCoder:(NSCoder *)coder
{
	if (!(self = [super init])) {
		return nil;
	}
	
	[self setNodeName:[coder decodeObjectForKey:SPGroupNodeNameKey]];
	[self setNodeIsExpanded:[[coder decodeObjectForKey:SPGroupNodeIsExpandedKey] boolValue]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:[self nodeName] forKey:SPGroupNodeNameKey];
	[coder encodeObject:[NSNumber numberWithBool:[self nodeIsExpanded]] forKey:SPGroupNodeIsExpandedKey];
}

#pragma mark -
#pragma mark Other

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p ('%@', %@)>", [self className], self, [self nodeName], [NSNumber numberWithBool:[self nodeIsExpanded]]];
}

#pragma mark -

- (void)dealloc
{
	if (nodeName) SPClear(nodeName);
	
	[super dealloc];
}

@end
