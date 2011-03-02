//
//  $Id$
//
//  MCPConnectionDelegate.h
//  MCPKit
//
//  Created by Stuart Connolly (stuconnolly.com) on October 20, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

@protocol MCPConnectionDelegate <NSObject>

/**
 *
 * @param query
 * @param connection
 */
- (void)willQueryString:(NSString *)query connection:(id)connection;

/**
 *
 * @param error
 * @param connection
 */
- (void)queryGaveError:(NSString *)error connection:(id)connection;

/**
 *
 *
 * @param error
 * @param message
 */
- (void)showErrorWithTitle:(NSString *)error message:(NSString *)message;

/**
 *
 *
 * @param connection
 */
- (NSString *)keychainPasswordForConnection:(id)connection;

/**
 *
 *
 * @param connection
 */
- (NSString *)onReconnectShouldSelectDatabase:(id)connection;

/**
 *
 *
 * @param connection
 */
- (void)noConnectionAvailable:(id)connection;

/**
 *
 *
 * @param connection
 */
- (MCPConnectionCheck)connectionLost:(id)connection;

@end
