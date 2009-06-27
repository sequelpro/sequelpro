//
//  NSApplication+BWAdditions.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "NSApplication+BWAdditions.h"

@implementation NSApplication (BWAdditions)

+ (BOOL)isOnLeopard 
{
	SInt32 minorVersion, majorVersion;
	Gestalt(gestaltSystemVersionMajor, &majorVersion);
	Gestalt(gestaltSystemVersionMinor, &minorVersion);
	return majorVersion == 10 && minorVersion == 5;
}

@end
