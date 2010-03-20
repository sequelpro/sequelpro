//
//  $Id$
//
//  SPMainThreadTrampoline.h
//  sequel-pro
//
//  Created by Rowan Beentje on 20/03/2010.
//  Copyright 2010 Rowan Beentje. All rights reserved.
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
//

#import <Cocoa/Cocoa.h>

/**
 * Set up the categories, available on all NSObjects.
 */
@interface NSObject (SPMainThreadTrampoline)

- (id) onMainThread;
- (id) retainedOnMainThread;

@end


/**
 * Set up the trampoline class.
 * This is created automatically by using the onMainThread category; all messages
 * sent to this object are bounced to the initial object on the main thread.
 * Note that base NSObject messages like retain or release apply to the trampoline.
 */

@interface SPMainThreadTrampoline : NSObject
{
	IBOutlet id	trampolineObject;
}

- (id) initWithObject:(id)theObject;

@end
