//
//  $Id$
//
//  MCPConnectionProxy.h
//  MCPKit
//
//  Created by Stuart Connolly (stuconnolly.com) on July 2, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
//
//  Forked by the Sequel Pro team (sequelpro.com), April 2009
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
//  More info at <http://mysql-cocoa.sourceforge.net/>
//  More info at <http://code.google.com/p/sequel-pro/>

#import <Foundation/Foundation.h>

/**
 * Connection proxy state constants.
 */
enum PROXY_TUNNEL_STATES
{
	PROXY_STATE_IDLE = 0,
	PROXY_STATE_CONNECTING = 1,
	PROXY_STATE_WAITING_FOR_AUTH = 2,
	PROXY_STATE_CONNECTED = 3,
	PROXY_STATE_FORWARDING_FAILED = 4
};

@protocol MCPConnectionProxy <NSObject>

/**
 * Connect the proxy.
 */
- (void)connect;

/**
 * Disconnect the proxy.
 */
- (void)disconnect;

/**
 * Get the current state of the proxy.
 */
- (NSInteger)state;

/**
 * Get the local port being used by the proxy.
 */ 
- (NSInteger)localPort;

/**
 * Sets the method the proxy should call whenever the state of the connection changes.
 */
- (BOOL)setConnectionStateChangeSelector:(SEL)theStateChangeSelector delegate:(id)theDelegate;

@end
