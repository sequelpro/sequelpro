//
//  $Id$
//
//  QKQueryOperators.h
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

/**
 * Note that this is by no means complete list of available operators, only the most commonly used ones. Other
 * operators can be added as and when they are required.
 */
typedef enum
{
	QKEqualityOperator,
	QKNotEqualOperator,
	QKLikeOperator,
	QKNotLikeOperator,
	QKInOperator,
	QKNotInOperator,
	QKIsNullOperator,
	QKIsNotNullOperator,
	QKGreaterThanOperator,
	QKLessThanOperator,
	QKGreaterThanOrEqualOperator,
	QKLessThanOrEqualOperator
}
QKQueryOperator;