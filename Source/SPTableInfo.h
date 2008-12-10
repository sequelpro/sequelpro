//
//  SPTableInfo.h
//  sequel-pro
//
//  Created by Ben Perry on 6/05/08.
//  Copyright 2008 Ben Perry. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SPTableInfo : NSObject {
	IBOutlet id infoTable;
	IBOutlet id tableList;
	IBOutlet id tableListInstance;
	IBOutlet id tableDocumentInstance;
	
	NSMutableArray *info;
}

- (NSString *)sizeFromBytes:(int)bytes;


@end
