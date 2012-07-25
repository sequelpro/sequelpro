//
//  $Id$
//
//  NSNotificationCenterThreadingAdditions.h
//  Enable NSNotification being sent from threads
//
//  Copied from the TCMPortMapper project; original code available on
//  Google Code at <http://code.google.com/p/tcmportmapper/source/browse/TCMPortMapper/framework/NSNotificationCenterThreadingAdditions.h>
//
//  Copyright (c) 2007-2008 TheCodingMonkeys: 
//  Martin Pittenauer, Dominik Wagner, <http://codingmonkeys.de>
//  Some rights reserved: <http://opensource.org/licenses/mit-license.php>

@interface NSNotificationCenter (NSNotificationCenterThreadingAdditions)
- (void)postNotificationOnMainThread:(NSNotification *)aNotification;
- (void)postNotificationOnMainThreadWithName:(NSString *)aName object:(id)anObject;
@end
