//
//  $Id$
//
//  SPCategoryAdditions.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 23, 2010
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
 * This header is intended to import all of our custom category additions to classes outwith our control.
 * It is subsequently included in Sequel Pro's precompiled header making all of the additional methods/functions 
 * included in header available to all classes within the application.
 */

#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPObjectAdditions.h"
#import "SPTextViewAdditions.h"
#import "SPWindowAdditions.h"
#import "SPDataAdditions.h"
#import "SPDataBase64EncodingAdditions.h"
#import "SPMenuAdditions.h"
#import "SPNotLoaded.h"
#import "SPMainThreadTrampoline.h"
#import "SPColorAdditions.h"
#import "SPFileManagerAdditions.h"

#import "NSNotificationCenterThreadingAdditions.h"
#import "NSMutableArray-MultipleSort.h"
