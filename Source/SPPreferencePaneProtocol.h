//
//  $Id$
//
//  SPPreferencePaneProtocol.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 29, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

/**
 * @protocol SPPreferencePane SPPreferencePane.h
 *
 * @author Stuart Connolly http://stuconnolly.com/ 
 *
 * Protocol that all preference pane controllers should conform to.
 */
@protocol SPPreferencePaneProtocol

/**
 * Returns the preference pane's view.
 *
 * @return The pane's NSView instance
 */
- (NSView *)preferencePaneView;

/**
 * Returns the preference pane's toolbar item icon/image.
 *
 * @return The pane's NSImage instance
 */
- (NSImage *)preferencePaneIcon;

/**
 * Returns the preference pane's name.
 *
 * @return The pane's name
 */
- (NSString *)preferencePaneName;

/**
 * Returns the preference pane's toolbar item identifier.
 *
 * @return The pane's identifier
 */
- (NSString *)preferencePaneIdentifier;

/**
 * Returns the preference pane's toolbar item tooltip.
 *
 * @return The pane's tooltip
 */
- (NSString *)preferencePaneToolTip;

/**
 * Indicates whether or not the preference pane can be resized.
 *
 * @return A BOOL indicating resizability
 */
- (BOOL)preferencePaneAllowsResizing;

@end
