//
//  NSString+BWAdditions.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "NSString+BWAdditions.h"

@implementation NSString (BWAdditions)

+ (NSString *)randomUUID
{
	CFUUIDRef uuidObj = CFUUIDCreate(nil);
	NSString *newUUID = (NSString*)CFMakeCollectable(CFUUIDCreateString(nil, uuidObj));
	CFRelease(uuidObj);
	
	return [newUUID autorelease];
}

@end
