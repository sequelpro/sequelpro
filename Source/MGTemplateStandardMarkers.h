//
//  MGTemplateStandardMarkers.h
//
//  Created by Matt Gemmell on 13/05/2008.
//  Copyright 2008 Instinctive Code. All rights reserved.
//

#import "MGTemplateEngine.h"
#import "MGTemplateMarker.h"

@interface MGTemplateStandardMarkers : NSObject <MGTemplateMarker> {
	MGTemplateEngine *engine; // weak ref
	NSMutableArray *forStack;
	NSMutableArray *sectionStack;
	NSMutableArray *ifStack;
	NSMutableArray *commentStack;
	NSMutableDictionary *cycles;
}

- (BOOL)currentBlock:(NSDictionary *)blockInfo matchesTopOfStack:(NSMutableArray *)stack;
- (BOOL)argIsNumeric:(NSString *)arg intValue:(int *)val checkVariables:(BOOL)checkVars;
- (BOOL)argIsTrue:(NSString *)arg;

@end
