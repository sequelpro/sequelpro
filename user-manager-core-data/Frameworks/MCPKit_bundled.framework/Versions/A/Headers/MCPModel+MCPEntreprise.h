//
//  MCPModel+MCPEntreprise.h
//  MCPModeler
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 01/11/04.
//  Copyright 2004 Serge Cohen. All rights reserved.
//
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  For a copy of the GNU General Public License, visit <http://www.gnu.org/> or
//  write to the Free Software Foundation, Inc., 59 Temple Place--Suite 330,
//  Boston, MA 02111-1307, USA.
//
//  More info at <http://mysql-cocoa.sourceforge.net/>
//

#import "MCPModel.h"

@interface MCPModel (MCPEntreprise)

#pragma mark Work as a class description server
- (void) registerAsClassDescriptionServer;
- (void) registerDescriptionForClass:(NSNotification *) notification;

@end
