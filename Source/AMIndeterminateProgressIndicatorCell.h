//
//  $Id: SPFieldEditorController.h 802 2009-07-18 20:46:57Z bibiko $
//
//  AMIndeterminateProgressIndicatorCell.h
//  sequel-pro
//
//  Created by Andreas Mayer on January 23, 2007
//  Copyright 2007 Andreas Mayer (andreas@harmless.de). All rights reserved.
//
//  License: http://www.opensource.org/licenses/bsd-license.php
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

#import <Cocoa/Cocoa.h>


@interface AMIndeterminateProgressIndicatorCell : NSCell {
	double doubleValue;
	NSTimeInterval animationDelay;
	BOOL displayedWhenStopped;
	BOOL spinning;
	NSColor *color;
	float redComponent;
	float greenComponent;
	float blueComponent;
}

- (NSColor *)color;
- (void)setColor:(NSColor *)value;

- (double)doubleValue;
- (void)setDoubleValue:(double)value;

- (NSTimeInterval)animationDelay;
- (void)setAnimationDelay:(NSTimeInterval)value;

- (BOOL)isDisplayedWhenStopped;
- (void)setDisplayedWhenStopped:(BOOL)value;

- (BOOL)isSpinning;
- (void)setSpinning:(BOOL)value;


@end
