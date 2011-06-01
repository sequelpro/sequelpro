//
//  $Id$
//
//  NSNotificationAdditions.m
//  sequel-pro
//
//  Copied from the Colloquy project; original code available from Trac at
//  http://colloquy.info/project/browser/trunk/Additions/NSNotificationAdditions.m
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

#import "NSNotificationAdditions.h"
#import "pthread.h"

@interface NSNotificationCenter (NSNotificationCenterAdditions_PrivateAPI)
+ (void)_postNotification:(NSNotification *)aNotification;
+ (void)_postNotificationWithDetails:(NSDictionary *)anInfoDictionary;
@end

@implementation NSNotificationCenter (NSNotificationCenterAdditions)

- (void)postNotificationOnMainThread:(NSNotification *)aNotification
{
	if (pthread_main_np()) return [self postNotification:aNotification];

	[self performSelectorOnMainThread:@selector(_postNotification:) withObject:aNotification waitUntilDone:NO];
}

- (void)postNotificationOnMainThread:(NSNotification *)aNotification waitUntilDone:(BOOL)shouldWaitUntilDone
{
	if (pthread_main_np()) return [self postNotification:aNotification];

	[self performSelectorOnMainThread:@selector(_postNotification:) withObject:aNotification waitUntilDone:shouldWaitUntilDone];
}

- (void)postNotificationOnMainThreadWithName:(NSString *)aName object:(id)anObject
{
	if (pthread_main_np()) return [self postNotificationName:aName object:anObject userInfo:nil];

	[self postNotificationOnMainThreadWithName:aName object:anObject userInfo:nil waitUntilDone:NO];
}

- (void)postNotificationOnMainThreadWithName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
	if(pthread_main_np()) return [self postNotificationName:aName object:anObject userInfo:aUserInfo];

	[self postNotificationOnMainThreadWithName:aName object:anObject userInfo:aUserInfo waitUntilDone:NO];
}

- (void)postNotificationOnMainThreadWithName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo waitUntilDone:(BOOL)shouldWaitUntilDone
{
	if (pthread_main_np()) return [self postNotificationName:aName object:anObject userInfo:aUserInfo];

	NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:3];

	if (aName) [info setObject:aName forKey:@"name"];
	if (anObject) [info setObject:anObject forKey:@"object"];
	if (aUserInfo) [info setObject:aUserInfo forKey:@"userInfo"];

	[[self class] performSelectorOnMainThread:@selector(_postNotificationWithDetails:) withObject:info waitUntilDone:shouldWaitUntilDone];
}

@end

@implementation NSNotificationCenter (NSNotificationCenterAdditions_PrivateAPI)

+ (void)_postNotification:(NSNotification *)aNotification
{
	[[self defaultCenter] postNotification:aNotification];
}

+ (void)_postNotificationWithDetails:(NSDictionary *)anInfoDictionary
{
	NSString *name = [anInfoDictionary objectForKey:@"name"];
	id object = [anInfoDictionary objectForKey:@"object"];
	NSDictionary *userInfo = [anInfoDictionary objectForKey:@"userInfo"];

	[[self defaultCenter] postNotificationName:name object:object userInfo:userInfo];

	[anInfoDictionary release];
}

@end
