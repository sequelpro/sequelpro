/*
 *  MGTemplateFilter.h
 *
 *  Created by Matt Gemmell on 12/05/2008.
 *  Copyright 2008 Instinctive Code. All rights reserved.
 *
 */

@protocol MGTemplateFilter

- (NSArray *)filters;
- (NSObject *)filterInvoked:(NSString *)filter withArguments:(NSArray *)args onValue:(NSObject *)value;

@end
