//
//  $Id$
//
//  QKQueryParameter.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 4, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "QKQueryOperators.h"

@interface QKQueryParameter : NSObject 
{
	NSString *_field;
	
	QKQueryOperator _operator;
	
	id _value;
}

/**
 *
 */
@property (readwrite, retain, getter=field, setter=setField:) NSString *_field;

/**
 *
 */
@property (readwrite, assign, getter=operator, setter=setOperator:) QKQueryOperator _operator;

/**
 *
 */
@property (readwrite, retain, getter=value, setter=setValue:) id _value;

+ (QKQueryParameter *)queryParamWithField:(NSString *)field operator:(QKQueryOperator)op value:(id)value;

- (id)initParamWithField:(NSString *)field operator:(QKQueryOperator)op value:(id)value;

@end
