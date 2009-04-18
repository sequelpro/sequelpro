//
//  MGTemplateEngine.m
//
//  Created by Matt Gemmell on 11/05/2008.
//  Copyright 2008 Instinctive Code. All rights reserved.
//

#import "MGTemplateEngine.h"
#import "MGTemplateStandardMarkers.h"
#import "MGTemplateStandardFilters.h"
#import "DeepMutableCopy.h"


#define DEFAULT_MARKER_START		@"{%"
#define DEFAULT_MARKER_END			@"%}"
#define DEFAULT_EXPRESSION_START	@"{{"	// should always be different from marker-start
#define DEFAULT_EXPRESSION_END		@"}}"
#define DEFAULT_FILTER_START		@"|"
#define DEFAULT_LITERAL_START		@"literal"
#define DEFAULT_LITERAL_END			@"/literal"
// example:	{% markername arg1 arg2|filter:arg1 arg2 %}

#define GLOBAL_ENGINE_GROUP			@"engine"		// name of dictionary in globals containing engine settings
#define GLOBAL_ENGINE_DELIMITERS	@"delimiters"	// name of dictionary in GLOBAL_ENGINE_GROUP containing delimiters
#define GLOBAL_DELIM_MARKER_START	@"markerStart"	// name of key in GLOBAL_ENGINE_DELIMITERS containing marker start delimiter
#define GLOBAL_DELIM_MARKER_END		@"markerEnd"
#define GLOBAL_DELIM_EXPR_START		@"expressionStart"
#define GLOBAL_DELIM_EXPR_END		@"expressionEnd"
#define GLOBAL_DELIM_FILTER			@"filter"

@interface MGTemplateEngine (PrivateMethods)

- (NSObject *)valueForVariable:(NSString *)var parent:(NSObject **)parent parentKey:(NSString **)parentKey;
- (void)setValue:(NSObject *)newValue forVariable:(NSString *)var forceCurrentStackFrame:(BOOL)inStackFrame;
- (void)reportError:(NSString *)errorStr code:(int)code continuing:(BOOL)continuing;
- (void)reportBlockBoundaryStarted:(BOOL)started;
- (void)reportTemplateProcessingFinished;

@end


@implementation MGTemplateEngine


#pragma mark Creation and destruction


+ (NSString *)version
{
	// 1.0.0	20 May 2008
	return @"1.0.0";
}


+ (MGTemplateEngine *)templateEngine
{
	return [[[MGTemplateEngine alloc] init] autorelease];
}


- (id)init
{
	if (self = [super init]) {
		_openBlocksStack = [[NSMutableArray alloc] init];
		_globals = [[NSMutableDictionary alloc] init];
		_markers = [[NSMutableDictionary alloc] init];
		_filters = [[NSMutableDictionary alloc] init];
		_templateVariables = [[NSMutableDictionary alloc] init];
		_outputDisabledCount = 0; // i.e. not disabled.
		self.markerStartDelimiter = DEFAULT_MARKER_START;
		self.markerEndDelimiter = DEFAULT_MARKER_END;
		self.expressionStartDelimiter = DEFAULT_EXPRESSION_START;
		self.expressionEndDelimiter = DEFAULT_EXPRESSION_END;
		self.filterDelimiter = DEFAULT_FILTER_START;
		self.literalStartMarker = DEFAULT_LITERAL_START;
		self.literalEndMarker = DEFAULT_LITERAL_END;
		
		// Load standard markers and filters.
		[self loadMarker:[[[MGTemplateStandardMarkers alloc] initWithTemplateEngine:self] autorelease]];
		[self loadFilter:[[[MGTemplateStandardFilters alloc] init] autorelease]];
	}
	
	return self;
}


- (void)dealloc
{
	[_openBlocksStack release];
	_openBlocksStack = nil;
	[_globals release];
	_globals = nil;
	[_filters release];
	_filters = nil;
	[_markers release];
	_markers = nil;
	self.delegate = nil;
	[templateContents release];
	templateContents = nil;
	[_templateVariables release];
	_templateVariables = nil;
	self.markerStartDelimiter = nil;
	self.markerEndDelimiter = nil;
	self.expressionStartDelimiter = nil;
	self.expressionEndDelimiter = nil;
	self.filterDelimiter = nil;
	self.literalStartMarker = nil;
	self.literalEndMarker = nil;
	
	[super dealloc];
}


#pragma mark Managing persistent values.


- (void)setObject:(id)anObject forKey:(id)aKey
{
	[_globals setObject:anObject forKey:aKey];
}


- (void)addEntriesFromDictionary:(NSDictionary *)dict
{
	[_globals addEntriesFromDictionary:dict];
}


- (id)objectForKey:(id)aKey
{
	return [_globals objectForKey:aKey];
}


#pragma mark Configuration and extensibility.


- (void)loadMarker:(NSObject <MGTemplateMarker> *)marker
{
	if (marker) {
		// Obtain claimed markers.
		NSArray *markers = [marker markers];
		if (markers) {
			for (NSString *markerName in markers) {
				NSObject *existingHandler = [_markers objectForKey:markerName];
				if (!existingHandler) {
					// Set this MGTemplateMaker instance as the handler for markerName.
					[_markers setObject:marker forKey:markerName];
				}
			}
		}
	}
}


- (void)loadFilter:(NSObject <MGTemplateFilter> *)filter
{
	if (filter) {
		// Obtain claimed filters.
		NSArray *filters = [filter filters];
		if (filters) {
			for (NSString *filterName in filters) {
				NSObject *existingHandler = [_filters objectForKey:filterName];
				if (!existingHandler) {
					// Set this MGTemplateFilter instance as the handler for filterName.
					[_filters setObject:filter forKey:filterName];
				}
			}
		}
	}
}


#pragma mark  Delegate


- (void)reportError:(NSString *)errorStr code:(int)code continuing:(BOOL)continuing
{
	if (delegate) {
		NSString *errStr = NSLocalizedString(errorStr, nil);
		if (!continuing) {
			errStr = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Fatal Error", nil), errStr];
		}
		SEL selector = @selector(templateEngine:encounteredError:isContinuing:);
		if ([(NSObject *)delegate respondsToSelector:selector]) {
			NSError *error = [NSError errorWithDomain:TEMPLATE_ENGINE_ERROR_DOMAIN 
												 code:code 
											 userInfo:[NSDictionary dictionaryWithObject:errStr 
																				  forKey:NSLocalizedDescriptionKey]];
			[(NSObject <MGTemplateEngineDelegate> *)delegate templateEngine:self 
														   encounteredError:error 
															   isContinuing:continuing];
		}
	}
}


- (void)reportBlockBoundaryStarted:(BOOL)started
{
	if (delegate) {
		SEL selector = (started) ? @selector(templateEngine:blockStarted:) : @selector(templateEngine:blockEnded:);
		if ([(NSObject *)delegate respondsToSelector:selector]) {
			[(NSObject *)delegate performSelector:selector withObject:self withObject:[_openBlocksStack lastObject]];
		}
	}
}


- (void)reportTemplateProcessingFinished
{
	if (delegate) {
		SEL selector = @selector(templateEngineFinishedProcessingTemplate:);
		if ([(NSObject *)delegate respondsToSelector:selector]) {
			[(NSObject *)delegate performSelector:selector withObject:self];
		}
	}
}


#pragma mark Utilities.


- (NSObject *)valueForVariable:(NSString *)var parent:(NSObject **)parent parentKey:(NSString **)parentKey
{
	// Returns value for given variable-path, and returns by reference the parent object the variable
	// is contained in, and the key used on that parent object to access the variable.
	// e.g. for var "thing.stuff.2", where thing = NSDictionary and stuff = NSArray,
	// parent would be a pointer to the "stuff" array, and parentKey would be "2".
	
	NSString *dot = @".";
	NSArray *dotBits = [var componentsSeparatedByString:dot];
	NSObject *result = nil;
	NSObject *currObj = nil;
	
	// Check to see if there's a top-level entry for first part of var in templateVariables.
	NSString *firstVar = [dotBits objectAtIndex:0];
	
	if ([_templateVariables objectForKey:firstVar]) {
		currObj = _templateVariables;
	} else if ([_globals objectForKey:firstVar]) {
		currObj = _globals;
	} else {
		// Attempt to find firstVar in stack variables.
		NSEnumerator *stack = [_openBlocksStack reverseObjectEnumerator];
		NSDictionary *stackFrame = nil;
		while (stackFrame = [stack nextObject]) {
			NSDictionary *vars = [stackFrame objectForKey:BLOCK_VARIABLES_KEY];
			if (vars && [vars objectForKey:firstVar]) {
				currObj = vars;
				break;
			}
		}
	}
	
	if (!currObj) {
		return nil;
	}
	
	// Try raw KVC.
	@try {
		result = [currObj valueForKeyPath:var];
	}
	@catch (NSException *exception) {
		// do nothing
	}
	
	if (result) {
		// Got it with regular KVC. Work out parent and parentKey if necessary.
		if (parent || parentKey) {
			if ([dotBits count] > 1) {
				if (parent) {
					*parent = [currObj valueForKeyPath:[[dotBits subarrayWithRange:NSMakeRange(0, [dotBits count] - 1)] 
													   componentsJoinedByString:dot]];
				}
				if (parentKey) {
					*parentKey = [dotBits lastObject];
				}
			} else {
				if (parent) {
					*parent = currObj;
				}
				if (parentKey) {
					*parentKey = var;
				}
			}
		}
	} else {
		// Try iterative checking for array indices.
		int numKeys = [dotBits count];
		if (numKeys > 1) { // otherwise no point in checking
			NSObject *thisParent = currObj;
			NSString *thisKey = nil;
			for (int i = 0; i < numKeys; i++) {
				thisKey = [dotBits objectAtIndex:i];
				NSObject *newObj = nil;
				@try {
					newObj = [currObj valueForKeyPath:thisKey];
				}
				@catch (NSException *e) {
					// do nothing
				}
				// Check to see if this is an array which we can index into.
				if (!newObj && [currObj isKindOfClass:[NSArray class]]) {
					NSCharacterSet *numbersSet = [NSCharacterSet decimalDigitCharacterSet];
					NSScanner *scanner = [NSScanner scannerWithString:thisKey];
					NSString *digits;
					BOOL scanned = [scanner scanCharactersFromSet:numbersSet intoString:&digits];
					if (scanned && digits && [digits length] > 0) {
						int index = [digits intValue];
						if (index >= 0 && index < [((NSArray *)currObj) count]) {
							newObj = [((NSArray *)currObj) objectAtIndex:index];
						}
					}
				}
				thisParent = currObj;
				currObj = newObj;
				if (!currObj) {
					break;
				}
			}
			result = currObj;
			if (parent || parentKey) {
				if (parent) {
					*parent = thisParent;
				}
				if (parentKey) {
					*parentKey = thisKey;
				}
			}
		}
	}
	
	return result;
}


- (void)setValue:(NSObject *)newValue forVariable:(NSString *)var forceCurrentStackFrame:(BOOL)inStackFrame
{
	NSObject *parent = nil;
	NSString *parentKey = nil;
	NSObject *currValue;
	currValue = [self valueForVariable:var parent:&parent parentKey:&parentKey];
	if (!inStackFrame && currValue && (currValue != newValue)) {
		// Set new value appropriately.
		if ([parent isKindOfClass:[NSMutableArray class]]) {
			[(NSMutableArray *)parent replaceObjectAtIndex:[parentKey intValue] withObject:newValue];
		} else {
			// Try using setValue:forKey:
			@try {
				[parent setValue:newValue forKey:parentKey];
			}
			@catch (NSException *e) {
				// do nothing
			}
		}
	} else if (!currValue || inStackFrame) {
		// Put the variable into the current block-stack frame, or _templateVariables otherwise.
		NSMutableDictionary *vars;
		if ([_openBlocksStack count] > 0) {
			vars = [[_openBlocksStack lastObject] objectForKey:BLOCK_VARIABLES_KEY];
		} else {
			vars = _templateVariables;
		}
		if ([vars respondsToSelector:@selector(setValue:forKey:)]) {
			[vars setValue:newValue forKey:var];
		}
	}
}


- (NSObject *)resolveVariable:(NSString *)var
{
	NSObject *parent = nil;
	NSString *key = nil;
	NSObject *result = [self valueForVariable:var parent:&parent parentKey:&key];
	//NSLog(@"var: %@, parent: %@, key: %@, result: %@", var, parent, key, result);
	return result;
}


- (NSDictionary *)templateVariables
{
	return [NSDictionary dictionaryWithDictionary:_templateVariables];
}


#pragma mark Processing templates.


- (NSString *)processTemplate:(NSString *)templateString withVariables:(NSDictionary *)variables
{
	// Set up environment.
	[_openBlocksStack release];
	_openBlocksStack = [[NSMutableArray alloc] init];
	[_globals setObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 [NSDictionary dictionaryWithObjectsAndKeys:
						  self.markerStartDelimiter, GLOBAL_DELIM_MARKER_START, 
						  self.markerEndDelimiter, GLOBAL_DELIM_MARKER_END, 
						  self.expressionStartDelimiter, GLOBAL_DELIM_EXPR_START, 
						  self.expressionEndDelimiter, GLOBAL_DELIM_EXPR_END, 
						  self.filterDelimiter, GLOBAL_DELIM_FILTER, 
						  nil], GLOBAL_ENGINE_DELIMITERS, 
						 nil]
				 forKey:GLOBAL_ENGINE_GROUP];
	[_globals setObject:[NSNumber numberWithBool:YES] forKey:@"true"];
	[_globals setObject:[NSNumber numberWithBool:NO] forKey:@"false"];
	[_globals setObject:[NSNumber numberWithBool:YES] forKey:@"YES"];
	[_globals setObject:[NSNumber numberWithBool:NO] forKey:@"NO"];
	[_globals setObject:[NSNumber numberWithBool:YES] forKey:@"yes"];
	[_globals setObject:[NSNumber numberWithBool:NO] forKey:@"no"];
	_outputDisabledCount = 0;
	[templateContents release];
	templateContents = [templateString retain];
	_templateLength = [templateString length];
	[_templateVariables release];
	_templateVariables = [variables deepMutableCopy];
	remainingRange = NSMakeRange(0, [templateString length]);
	_literal = NO;
	
	// Ensure we have a matcher.
	if (!matcher) {
		[self reportError:@"No matcher has been configured for the template engine" code:7 continuing:NO];
		return nil;
	}
	
	// Tell our matcher to take note of our settings.
	[matcher engineSettingsChanged];
	NSMutableString *output = [NSMutableString string];
	
	while (remainingRange.location != NSNotFound) {
		NSDictionary *matchInfo = [matcher firstMarkerWithinRange:remainingRange];
		if (matchInfo) {
			// Append output before marker if appropriate.
			NSRange matchRange = [[matchInfo objectForKey:MARKER_RANGE_KEY] rangeValue];
			if (_outputDisabledCount == 0) {
				NSRange preMarkerRange = NSMakeRange(remainingRange.location, matchRange.location - remainingRange.location);
				[output appendFormat:@"%@", [templateContents substringWithRange:preMarkerRange]];
			}
			
			// Adjust remainingRange.
			remainingRange.location = NSMaxRange(matchRange);
			remainingRange.length = _templateLength - remainingRange.location;
			
			// Process the marker we found.
			//NSLog(@"Match: %@", matchInfo);
			NSString *matchMarker = [matchInfo objectForKey:MARKER_NAME_KEY];
			
			// Deal with literal mode.
			if ([matchMarker isEqualToString:self.literalStartMarker]) {
				if (_literal && _outputDisabledCount == 0) {
					// Output this tag literally.
					[output appendFormat:@"%@", [templateContents substringWithRange:matchRange]];
				} else {
					// Enable literal mode.
					_literal = YES;
				}
				continue;
			} else if ([matchMarker isEqualToString:self.literalEndMarker]) {
				// Disable literal mode.
				_literal = NO;
				continue;
			} else if (_literal && _outputDisabledCount == 0) {
				[output appendFormat:@"%@", [templateContents substringWithRange:matchRange]];
				continue;
			}
			
			// Check to see if the match is a marker.
			BOOL isMarker = [[matchInfo objectForKey:MARKER_TYPE_KEY] isEqualToString:MARKER_TYPE_MARKER];
			NSObject <MGTemplateMarker> *markerHandler = nil;
			NSObject *val = nil;
			if (isMarker) {
				markerHandler = [_markers objectForKey:matchMarker];
				
				// Process marker with handler.
				BOOL blockStarted = NO;
				BOOL blockEnded = NO;
				BOOL outputEnabled = (_outputDisabledCount == 0);
				BOOL outputWasEnabled = outputEnabled;
				NSRange nextRange = remainingRange;
				NSDictionary *newVariables = nil;
				NSDictionary *blockInfo = nil;
				
				// If markerHandler is same as that of current block, send blockInfo.
				if ([_openBlocksStack count] > 0) {
					NSDictionary *currBlock = [_openBlocksStack lastObject];
					NSString *currBlockStartMarker = [currBlock objectForKey:BLOCK_NAME_KEY];
					if ([_markers objectForKey:currBlockStartMarker] == markerHandler) {
						blockInfo = currBlock;
					}
				}
				
				// Call marker's handler.
				val = [markerHandler markerEncountered:matchMarker 
										 withArguments:[matchInfo objectForKey:MARKER_ARGUMENTS_KEY] 
											   inRange:matchRange 
										  blockStarted:&blockStarted blockEnded:&blockEnded 
										 outputEnabled:&outputEnabled nextRange:&nextRange 
									  currentBlockInfo:blockInfo newVariables:&newVariables];
				
				if (outputEnabled != outputWasEnabled) {
					if (outputEnabled) {
						_outputDisabledCount--;
					} else {
						_outputDisabledCount++;
					}
				}
				remainingRange = nextRange;
				
				// Check to see if remainingRange is valid.
				if (NSMaxRange(remainingRange) > [self.templateContents length]) {
					[self reportError:[NSString stringWithFormat:@"Marker handler \"%@\" specified an invalid range to resume processing from", 
									   matchMarker] 
								 code:5 continuing:NO];
					break;
				}
				
				BOOL forceVarsToStack = NO;
				if (blockStarted && blockEnded) {
					// This is considered an error on the part of the marker-handler. Report to delegate.
					[self reportError:[NSString stringWithFormat:@"Marker \"%@\" reported that a block simultaneously began and ended", 
									   matchMarker] 
								 code:0 continuing:YES];
				} else if (blockStarted) {
					NSArray *endMarkers = [markerHandler endMarkersForMarker:matchMarker];
					if (!endMarkers) {
						// Report error to delegate.
						[self reportError:[NSString stringWithFormat:@"Marker \"%@\" started a block but did not supply any suitable end-markers", 
										   matchMarker] 
									 code:4 continuing:YES];
						continue;
					}
					
					// A block has begun. Create relevant stack frame.
					NSMutableDictionary *frame = [NSMutableDictionary dictionary];
					[frame setObject:matchMarker forKey:BLOCK_NAME_KEY];
					[frame setObject:endMarkers forKey:BLOCK_END_NAMES_KEY];
					NSArray *arguments = [matchInfo objectForKey:MARKER_ARGUMENTS_KEY];
					if (!arguments) {
						arguments = [NSArray array];
					}
					[frame setObject:arguments forKey:BLOCK_ARGUMENTS_KEY];
					[frame setObject:[matchInfo objectForKey:MARKER_RANGE_KEY] forKey:BLOCK_START_MARKER_RANGE_KEY];
					[frame setObject:[NSMutableDictionary dictionary] forKey:BLOCK_VARIABLES_KEY];
					[_openBlocksStack addObject:frame];
					
					forceVarsToStack = YES;
					
					// Report block start to delegate.
					[self reportBlockBoundaryStarted:YES];
				} else if (blockEnded) {
					if (!blockInfo || 
						([_openBlocksStack count] > 0 && 
						 ![(NSArray *)[[_openBlocksStack lastObject] objectForKey:BLOCK_END_NAMES_KEY] containsObject:matchMarker])) {
						// The marker-handler just told us a block ended, but the current block was not
						// started by that marker-handler. This means a syntax error exists in the template,
						// specifically an unterminated block (the current block).
						// This is considered an unrecoverable error.
						NSString *errMsg;
						if ([_openBlocksStack count] == 0) {
							errMsg = [NSString stringWithFormat:@"Marker \"%@\" reported that a non-existent block ended", 
									  matchMarker];
						} else {
							NSString *currBlockName = [[_openBlocksStack lastObject] objectForKey:BLOCK_NAME_KEY];
							errMsg = [NSString stringWithFormat:@"Marker \"%@\" reported that a block ended, \
but current block was started by \"%@\" marker", 
									  matchMarker, currBlockName];
						}
						[self reportError:errMsg code:1 continuing:YES];
						break;
					}
					
					// Report block end to delegate before removing stack frame, so we can send info dict.
					[self reportBlockBoundaryStarted:NO];
					
					// Remove relevant stack frame.
					if ([_openBlocksStack count] > 0) {
						[_openBlocksStack removeLastObject];
					}
				}
				
				// Process newVariables
				if (newVariables) {
					//NSLog(@"new vars %@", newVariables);
					for (NSString *key in newVariables) {
						[self setValue:[newVariables objectForKey:key] forVariable:key forceCurrentStackFrame:forceVarsToStack];
					}
				}
				
			} else {
				// Check to see if the first word of the match is a variable.
				val = [self resolveVariable:matchMarker];
			}
			
			// Prepare result for output, if we have a result.
			if (val && _outputDisabledCount == 0) {
				// Process filter if specified.
				NSString *filter = [matchInfo objectForKey:MARKER_FILTER_KEY];
				if (filter) {
					NSObject <MGTemplateFilter> *filterHandler = [_filters objectForKey:filter];
					if (filterHandler) {
						val = [filterHandler filterInvoked:filter 
											 withArguments:[matchInfo objectForKey:MARKER_FILTER_ARGUMENTS_KEY] onValue:val];
					}
				}
				
				// Output result.
				[output appendFormat:@"%@", val];
			} else if ((!val && !isMarker && _outputDisabledCount == 0) || (isMarker && !markerHandler)) {
				// Call delegate's error-reporting method, if implemented.
				[self reportError:[NSString stringWithFormat:@"\"%@\" is not a valid %@", 
								   matchMarker, (isMarker) ? @"marker" : @"variable"] 
							 code:((isMarker) ? 2 : 3)  continuing:YES];
			}
		} else {
			// Append output to end of template.
			if (_outputDisabledCount == 0) {
				[output appendFormat:@"%@", [templateContents substringWithRange:remainingRange]];
			}
			
			// Check to see if there are open blocks left over.
			int openBlocks = [_openBlocksStack count];
			if (openBlocks > 0) {
				NSString *errMsg = [NSString stringWithFormat:@"Finished processing template, but %d %@ left open (%@).", 
									openBlocks, 
									(openBlocks == 1) ? @"block was" : @"blocks were", 
									[[_openBlocksStack valueForKeyPath:BLOCK_NAME_KEY] componentsJoinedByString:@", "]];
				[self reportError:errMsg code:6 continuing:YES];
			}
			
			// Ensure we terminate the loop.
			remainingRange.location = NSNotFound;
		}
	}
	
	// Tell all marker-handlers we're done.
	[[_markers allValues] makeObjectsPerformSelector:@selector(engineFinishedProcessingTemplate)];
	
	// Inform delegate we're done.
	[self reportTemplateProcessingFinished];
	
	return output;
}


- (NSString *)processTemplateInFileAtPath:(NSString *)templatePath withVariables:(NSDictionary *)variables
{
	NSString *result = nil;
	NSStringEncoding enc;
	NSString *templateString = [NSString stringWithContentsOfFile:templatePath usedEncoding:&enc error:NULL];
	if (templateString) {
		result = [self processTemplate:templateString withVariables:variables];
	}
	return result;
}


#pragma mark Properties


@synthesize markerStartDelimiter;
@synthesize markerEndDelimiter;
@synthesize expressionStartDelimiter;
@synthesize expressionEndDelimiter;
@synthesize filterDelimiter;
@synthesize literalStartMarker;
@synthesize literalEndMarker;
@synthesize remainingRange;
@synthesize delegate;
@synthesize matcher;
@synthesize templateContents;


@end
