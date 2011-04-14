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
#ifndef SP_REFACTOR
+ (void)_postNotification:(NSNotification *)notification;
+ (void)_postNotificationName:(NSDictionary *)info;
+ (void)_postNotificationForwarder:(NSDictionary *)info;
#else
+ (void)_sequelProPostNotification:(NSNotification *)notification;
+ (void)_sequelProPostNotificationName:(NSDictionary *)info;
+ (void)_sequelProPostNotificationForwarder:(NSDictionary *)info;
#endif
@end

@implementation NSNotificationCenter (NSNotificationCenterAdditions)

#ifndef SP_REFACTOR
- (void)postNotificationOnMainThread:(NSNotification *)notification 
#else
- (void)sequelProPostNotificationOnMainThread:(NSNotification *)notification 
#endif
{
	if (pthread_main_np()) return [self postNotification:notification];
	
#ifndef SP_REFACTOR
	[self postNotificationOnMainThread:notification waitUntilDone:NO];
#else
	[self sequelProPostNotificationOnMainThread:notification waitUntilDone:NO];
#endif
}

#ifndef SP_REFACTOR
- (void)postNotificationOnMainThread:(NSNotification *)notification waitUntilDone:(BOOL)shouldWaitUntilDone 
#else
- (void)sequelProPostNotificationOnMainThread:(NSNotification *)notification waitUntilDone:(BOOL)shouldWaitUntilDone 
#endif
{
	if (pthread_main_np()) return [self postNotification:notification];

#ifndef SP_REFACTOR
	[self performSelectorOnMainThread:@selector(_postNotification:) withObject:notification waitUntilDone:shouldWaitUntilDone];
#else	
	[self performSelectorOnMainThread:@selector(_sequelProPostNotification:) withObject:notification waitUntilDone:shouldWaitUntilDone];
#endif
}

#ifndef SP_REFACTOR
- (void)postNotificationOnMainThreadWithName:(NSString *)name object:(id)object 
#else
- (void)sequelProPostNotificationOnMainThreadWithName:(NSString *)name object:(id)object 
#endif
{
	if (pthread_main_np()) return [self postNotificationName:name object:object userInfo:nil];
	
#ifndef SP_REFACTOR
	[self postNotificationOnMainThreadWithName:name object:object userInfo:nil waitUntilDone:NO];
#else
	[self sequelProPostNotificationOnMainThreadWithName:name object:object userInfo:nil waitUntilDone:NO];
#endif
}

#ifndef SP_REFACTOR
- (void)postNotificationOnMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo 
#else
- (void)sequelProPostNotificationOnMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo 
#endif
{	
	if(pthread_main_np()) return [self postNotificationName:name object:object userInfo:userInfo];
	
#ifndef SP_REFACTOR
	[self postNotificationOnMainThreadWithName:name object:object userInfo:userInfo waitUntilDone:NO];
#else
	[self sequelProPostNotificationOnMainThreadWithName:name object:object userInfo:userInfo waitUntilDone:NO];
#endif
}

#ifndef SP_REFACTOR
- (void)postNotificationOnMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo waitUntilDone:(BOOL)shouldWaitUntilDone 
#else
- (void)sequelProPostNotificationOnMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo waitUntilDone:(BOOL)shouldWaitUntilDone 
#endif
{
	if (pthread_main_np()) return [self postNotificationName:name object:object userInfo:userInfo];

	NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:3];
	
	if (name) [info setObject:name forKey:@"name"];
	if (object) [info setObject:object forKey:@"object"];
	if (userInfo) [info setObject:userInfo forKey:@"userInfo"];

#ifndef SP_REFACTOR
	[[self class] performSelectorOnMainThread:@selector(_postNotificationName:) withObject:info waitUntilDone:shouldWaitUntilDone];
#else
	[[self class] performSelectorOnMainThread:@selector(_sequelProPostNotificationName:) withObject:info waitUntilDone:shouldWaitUntilDone];
#endif

	[info release];
}

@end

@implementation NSNotificationCenter (NSNotificationCenterAdditions_PrivateAPI)

#ifndef SP_REFACTOR
+ (void)_postNotification:(NSNotification *)notification 
#else
+ (void)_sequelProPostNotification:(NSNotification *)notification 
#endif
{
	[[self defaultCenter] postNotification:notification];
}

#ifndef SP_REFACTOR
+ (void)_postNotificationName:(NSDictionary *)info 
#else
+ (void)_sequelProPostNotificationName:(NSDictionary *)info 
#endif
{
	NSString *name = [info objectForKey:@"name"];
	
	id object = [info objectForKey:@"object"];
	
	NSDictionary *userInfo = [info objectForKey:@"userInfo"];

	[[self defaultCenter] postNotificationName:name object:object userInfo:userInfo];
}

#ifndef SP_REFACTOR
+ (void)_postNotificationForwarder:(NSDictionary *)info 
#else
+ (void)_sequelProPostNotificationForwarder:(NSDictionary *)info 
#endif
{
	NSString *name = [info objectForKey:@"name"];
	
	id object = [info objectForKey:@"object"];
	
	NSDictionary *userInfo = [info objectForKey:@"userInfo"];

	[[self defaultCenter] postNotificationName:name object:object userInfo:userInfo];
}

@end
