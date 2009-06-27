//
//  ICUTemplateMatcher.h
//
//  Created by Matt Gemmell on 19/05/2008.
//  Copyright 2008 Instinctive Code. All rights reserved.
//

#import "MGTemplateEngine.h"

/*
 This is an example Matcher for MGTemplateEngine, implemented using libicucore on Leopard, 
 via the RegexKitLite library: http://regexkit.sourceforge.net/#RegexKitLite
 
 This project includes everything you need, as long as you're building on Mac OS X 10.5 or later.
 
 Other matchers can easily be implemented using the MGTemplateEngineMatcher protocol,
 if you prefer to use another regex framework, or use another matching method entirely.
 */

@interface ICUTemplateMatcher : NSObject <MGTemplateEngineMatcher> {
	MGTemplateEngine *engine;
	NSString *markerStart;
	NSString *markerEnd;
	NSString *exprStart;
	NSString *exprEnd;
	NSString *filterDelimiter;
	NSString *templateString;
	NSString *regex;
}

@property(assign) MGTemplateEngine *engine; // weak ref
@property(retain) NSString *markerStart;
@property(retain) NSString *markerEnd;
@property(retain) NSString *exprStart;
@property(retain) NSString *exprEnd;
@property(retain) NSString *filterDelimiter;
@property(retain) NSString *templateString;
@property(retain) NSString *regex;

+ (ICUTemplateMatcher *)matcherWithTemplateEngine:(MGTemplateEngine *)theEngine;

- (NSArray *)argumentsFromString:(NSString *)argString;

@end
