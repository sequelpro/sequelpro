//
//  $Id$
//
//  SPFontPreviewTextField.m
//  sequel-pro
//
//  This is a heavily modified version of JVFontPreviewField from
//  the Colloquy Project <http://colloquy.info/>
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

#import "SPFontPreviewTextField.h"

@implementation SPFontPreviewTextField

- (void)setFont:(NSFont *)font 
{
	if (!font) return;

	if (_actualFont) [_actualFont release];
	
	_actualFont = [font retain];

	[super setFont:[[NSFontManager sharedFontManager] convertFont:font toSize:11.]];

	NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[_actualFont displayName]];
	NSMutableParagraphStyle *paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

	[paraStyle setMinimumLineHeight:NSHeight([self bounds])];
	[paraStyle setMaximumLineHeight:NSHeight([self bounds])];
	
	[text addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange(0, [text length])];

	[self setObjectValue:text];
	
	[text release];
	[paraStyle release];
}

#pragma mark -

- (void)dealloc 
{
	if (_actualFont) [_actualFont release], _actualFont = nil;
	
	[super dealloc];
}

@end
