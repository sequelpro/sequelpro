//
//  BWToolbarItem.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWToolbarItem.h"
#import "NSString+BWAdditions.h"

@interface BWToolbarItem ()
@property (copy) NSString *identifierString;
@end

@interface NSToolbarItem (BWTIPrivate)
- (void)_setItemIdentifier:(id)fp8;
- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder*)coder;
@end

@implementation BWToolbarItem

@synthesize identifierString;

- (id)initWithCoder:(NSCoder *)coder 
{
    if ((self = [super initWithCoder:coder]) != nil)
	{
		[self setIdentifierString:[coder decodeObjectForKey:@"BWTIIdentifierString"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self identifierString] forKey:@"BWTIIdentifierString"];
}

- (void)setIdentifierString:(NSString *)aString
{
	if (identifierString != aString)
	{
		[identifierString release];
		identifierString = [aString copy];
	}
	
	if (identifierString == nil || [identifierString isEqualToString:@""])
		[self _setItemIdentifier:[[NSString randomUUID] retain]];
	else
		[self _setItemIdentifier:identifierString];
}

- (void)dealloc
{
	[identifierString release];
	[super dealloc];
}

@end
