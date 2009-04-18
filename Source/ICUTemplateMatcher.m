//
//  ICUTemplateMatcher.m
//
//  Created by Matt Gemmell on 19/05/2008.
//  Copyright 2008 Instinctive Code. All rights reserved.
//

#import "ICUTemplateMatcher.h"
#import "RegexKitLite.h"


@implementation ICUTemplateMatcher


+ (ICUTemplateMatcher *)matcherWithTemplateEngine:(MGTemplateEngine *)theEngine
{
	return [[[ICUTemplateMatcher alloc] initWithTemplateEngine:theEngine] autorelease];
}


- (id)initWithTemplateEngine:(MGTemplateEngine *)theEngine
{
	if (self = [super init]) {
		self.engine = theEngine; // weak ref
	}
	
	return self;
}


- (void)dealloc
{
	self.engine = nil;
	self.templateString = nil;
	self.markerStart = nil;
	self.markerEnd = nil;
	self.exprStart = nil;
	self.exprEnd = nil;
	self.filterDelimiter = nil;
	self.regex = nil;
	
	[super dealloc];
}


- (void)engineSettingsChanged
{
	// This method is a good place to cache settings from the engine.
	self.markerStart = engine.markerStartDelimiter;
	self.markerEnd = engine.markerEndDelimiter;
	self.exprStart = engine.expressionStartDelimiter;
	self.exprEnd = engine.expressionEndDelimiter;
	self.filterDelimiter = engine.filterDelimiter;
	self.templateString = engine.templateContents;
	
	// Note: the \Q ... \E syntax causes everything inside it to be treated as literals.
	// This help us in the case where the marker/filter delimiters have special meaning 
	// in regular expressions; notably the "$" character in the default marker start-delimiter.
	// Note: the (?m) syntax makes ICU enable multiline matching.
	NSString *basePattern = @"(\\Q%@\\E)(?:\\s+)?(.*?)(?:(?:\\s+)?\\Q%@\\E(?:\\s+)?(.*?))?(?:\\s+)?\\Q%@\\E";
	NSString *mrkrPattern = [NSString stringWithFormat:basePattern, self.markerStart, self.filterDelimiter, self.markerEnd];
	NSString *exprPattern = [NSString stringWithFormat:basePattern, self.exprStart, self.filterDelimiter, self.exprEnd];
	self.regex = [NSString stringWithFormat:@"(?m)(?:%@|%@)", mrkrPattern, exprPattern];
}


- (NSDictionary *)firstMarkerWithinRange:(NSRange)range
{
	NSRange matchRange = [self.templateString rangeOfRegex:self.regex options:RKLNoOptions inRange:range capture:0 error:NULL];
	NSMutableDictionary *markerInfo = nil;
	if (matchRange.length > 0) {
		markerInfo = [NSMutableDictionary dictionary];
		[markerInfo setObject:[NSValue valueWithRange:matchRange] forKey:MARKER_RANGE_KEY];
		
		// Found a match. Obtain marker string.
		NSString *matchString = [self.templateString substringWithRange:matchRange];
		NSRange localRange = NSMakeRange(0, [matchString length]);
		//NSLog(@"mtch: \"%@\"", matchString);
		
		// Find type of match
		NSString *matchType = nil;
		NSRange mrkrSubRange = [matchString rangeOfRegex:regex options:RKLNoOptions inRange:localRange capture:1 error:NULL];
		BOOL isMarker = (mrkrSubRange.length > 0); // only matches if match has marker-delimiters
		int offset = 0;
		if (isMarker) {
			matchType = MARKER_TYPE_MARKER;
		} else  {
			matchType = MARKER_TYPE_EXPRESSION;
			offset = 3;
		}
		[markerInfo setObject:matchType forKey:MARKER_TYPE_KEY];
		
		// Split marker string into marker-name and arguments.
		NSRange markerRange = NSMakeRange(0, [matchString length]);
		markerRange = [matchString rangeOfRegex:regex options:RKLNoOptions inRange:localRange capture:2 + offset error:NULL];
		
		if (markerRange.length > 0) {
			NSString *markerString = [matchString substringWithRange:markerRange];
			NSArray *markerComponents = [self argumentsFromString:markerString];
			if (markerComponents && [markerComponents count] > 0) {
				[markerInfo setObject:[markerComponents objectAtIndex:0] forKey:MARKER_NAME_KEY];
				int count = [markerComponents count];
				if (count > 1) {
					[markerInfo setObject:[markerComponents subarrayWithRange:NSMakeRange(1, count - 1)] 
								   forKey:MARKER_ARGUMENTS_KEY];
				}
			}
			
			// Check for filter.
			NSRange filterRange = [matchString rangeOfRegex:regex options:RKLNoOptions inRange:localRange capture:3 + offset error:NULL];
			if (filterRange.length > 0) {
				// Found a filter. Obtain filter string.
				NSString *filterString = [matchString substringWithRange:filterRange];
				
				// Convert first : plus any immediately-following whitespace into a space.
				localRange = NSMakeRange(0, [filterString length]);
				NSString *space = @" ";
				NSRange filterArgDelimRange = [filterString rangeOfRegex:@":(?:\\s+)?" options:RKLNoOptions inRange:localRange 
																 capture:0 error:NULL];
				if (filterArgDelimRange.length > 0) {
					// Replace found text with space.
					filterString = [NSString stringWithFormat:@"%@%@%@", 
									[filterString substringWithRange:NSMakeRange(0, filterArgDelimRange.location)], 
									space, 
									[filterString substringWithRange:NSMakeRange(NSMaxRange(filterArgDelimRange),
																				 localRange.length - NSMaxRange(filterArgDelimRange))]];
				}
				
				// Split into filter-name and arguments.
				NSArray *filterComponents = [self argumentsFromString:filterString];
				if (filterComponents && [filterComponents count] > 0) {
					[markerInfo setObject:[filterComponents objectAtIndex:0] forKey:MARKER_FILTER_KEY];
					int count = [filterComponents count];
					if (count > 1) {
						[markerInfo setObject:[filterComponents subarrayWithRange:NSMakeRange(1, count - 1)] 
									   forKey:MARKER_FILTER_ARGUMENTS_KEY];
					}
				}
			}
		}
	}
	
	return markerInfo;
}


- (NSArray *)argumentsFromString:(NSString *)argString
{
	// Extract arguments from argString, taking care not to break single- or double-quoted arguments,
	// including those containing \-escaped quotes.
	NSString *argsPattern = @"\"(.*?)(?<!\\\\)\"|'(.*?)(?<!\\\\)'|(\\S+)";
	NSMutableArray *args = [NSMutableArray array];
	
	int location = 0;
	while (location != NSNotFound) {
		NSRange searchRange  = NSMakeRange(location, [argString length] - location);
		NSRange entireRange = [argString rangeOfRegex:argsPattern options:RKLNoOptions 
											  inRange:searchRange capture:0 error:NULL];
		NSRange matchedRange = [argString rangeOfRegex:argsPattern options:RKLNoOptions 
											   inRange:searchRange capture:1 error:NULL];
		if (matchedRange.length == 0) {
			matchedRange = [argString rangeOfRegex:argsPattern options:RKLNoOptions 
										   inRange:searchRange capture:2 error:NULL];
			if (matchedRange.length == 0) {
				matchedRange = [argString rangeOfRegex:argsPattern options:RKLNoOptions 
											   inRange:searchRange capture:3 error:NULL];
			}
		}
		
		location = NSMaxRange(entireRange) + ((entireRange.length == 0) ? 1 : 0);
		if (matchedRange.length > 0) {
			[args addObject:[argString substringWithRange:matchedRange]];
		} else {
			location = NSNotFound;
		}
	}
	
	return args;
}


@synthesize engine;
@synthesize markerStart;
@synthesize markerEnd;
@synthesize exprStart;
@synthesize exprEnd;
@synthesize filterDelimiter;
@synthesize templateString;
@synthesize regex;


@end
