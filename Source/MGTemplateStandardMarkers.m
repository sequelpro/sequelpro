//
//  MGTemplateStandardMarkers.m
//
//  Created by Matt Gemmell on 13/05/2008.
//  Copyright 2008 Instinctive Code. All rights reserved.
//

#import "MGTemplateStandardMarkers.h"
#import "MGTemplateFilter.h"

//==============================================================================

#define FOR_START	@"for"
#define FOR_END		@"/for"

#define FOR_TYPE_ENUMERATOR				@"in"	// e.g. for thing in things
#define FOR_TYPE_RANGE					@"to"	// e.g. for 1 to 5
#define FOR_REVERSE						@"reversed"

#define FOR_LOOP_VARS					@"currentLoop"
#define FOR_LOOP_CURR_INDEX				@"currentIndex"
#define FOR_LOOP_START_INDEX			@"startIndex"
#define FOR_LOOP_END_INDEX				@"endIndex"
#define FOR_PARENT_LOOP					@"parentLoop"

#define STACK_START_MARKER_RANGE		@"markerRange"
#define STACK_START_REMAINING_RANGE		@"remainingRange"
#define FOR_STACK_ENUMERATOR			@"enumerator"
#define FOR_STACK_ENUM_VAR				@"enumeratorVariable"
#define FOR_STACK_DISABLED_OUTPUT		@"disabledOutput"

//==============================================================================

#define SECTION_START	@"section"
#define SECTION_END		@"/section"

//==============================================================================

#define IF_START		@"if"
#define	ELSE			@"else"
#define IF_END			@"/if"

#define IF_VARS				@"currentIf"
#define DISABLE_OUTPUT		@"shouldDisableOutput"
#define IF_ARG_TRUE			@"argumentTrue"
#define IF_ELSE_SEEN		@"elseEncountered"

//==============================================================================

#define NOW					@"now"

//==============================================================================

#define COMMENT_START		@"comment"
#define COMMENT_END			@"/comment"

//==============================================================================

#define LOAD				@"load"

//==============================================================================

#define CYCLE				@"cycle"
#define CYCLE_INDEX			@"lastIndex"
#define CYCLE_VALUES		@"value"

//==============================================================================

#define SET					@"set"

//==============================================================================


@implementation MGTemplateStandardMarkers


- (id)initWithTemplateEngine:(MGTemplateEngine *)theEngine
{
	if (self = [super init]) {
		engine = theEngine;
		forStack = [[NSMutableArray alloc] init];
		sectionStack = [[NSMutableArray alloc] init];
		ifStack = [[NSMutableArray alloc] init];
		commentStack = [[NSMutableArray alloc] init];
		cycles = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (void)dealloc
{
	engine = nil;
	[forStack release];
	forStack = nil;
	[sectionStack release];
	sectionStack = nil;
	[ifStack release];
	ifStack = nil;
	[commentStack release];
	commentStack = nil;
	[cycles release];
	cycles = nil;
	
	[super dealloc];
}


- (NSArray *)markers
{
	return [NSArray arrayWithObjects:
			FOR_START, FOR_END, 
			SECTION_START, SECTION_END, 
			IF_START, ELSE, IF_END, 
			NOW, 
			COMMENT_START, COMMENT_END, 
			LOAD, 
			CYCLE, 
			SET, 
			nil];
}


- (NSArray *)endMarkersForMarker:(NSString *)marker
{
	if ([marker isEqualToString:FOR_START]) {
		return [NSArray arrayWithObjects:FOR_END, nil];
	} else if ([marker isEqualToString:SECTION_START]) {
		return [NSArray arrayWithObjects:SECTION_END, nil];
	} else if ([marker isEqualToString:IF_START]) {
		return [NSArray arrayWithObjects:IF_END, ELSE, nil];
	} else if ([marker isEqualToString:COMMENT_START]) {
		return [NSArray arrayWithObjects:COMMENT_END, nil];
	}
	return nil;
}


- (NSObject *)markerEncountered:(NSString *)marker withArguments:(NSArray *)args inRange:(NSRange)markerRange 
				   blockStarted:(BOOL *)blockStarted blockEnded:(BOOL *)blockEnded 
				  outputEnabled:(BOOL *)outputEnabled nextRange:(NSRange *)nextRange 
			   currentBlockInfo:(NSDictionary *)blockInfo newVariables:(NSDictionary **)newVariables
{
	if ([marker isEqualToString:FOR_START]) {
		if (args && [args count] >= 3) {
			// Determine which type of loop this is.
			BOOL isRange = YES;
			if ([[args objectAtIndex:1] isEqualToString:FOR_TYPE_ENUMERATOR]) {
				isRange = NO;
			}
			BOOL reversed = NO;
			if ([args count] == 4 && [[args objectAtIndex:3] isEqualToString:FOR_REVERSE]) {
				reversed = YES;
			}
			
			// Determine if we have acceptable parameters.
			NSObject *loopEnumObject = nil;
			BOOL valid = NO;
			NSString *startArg = [args objectAtIndex:0];
			NSString *endArg = [args objectAtIndex:2];
			NSInteger startIndex, endIndex;
			if (isRange) {
				// Check to see if either the arg itself is numeric, or it corresponds to a numeric variable.
				valid = [self argIsNumeric:startArg intValue:&startIndex checkVariables:YES];
				if (valid) {
					valid = [self argIsNumeric:endArg intValue:&endIndex checkVariables:YES];
					if (valid) {
						// Check startIndex and endIndex are sensible.
						valid = (startIndex <= endIndex);
					}
				}
			} else {
				startIndex = 0;
				
				// Check that endArg is a collection.
				NSObject *obj = [engine resolveVariable:endArg];
				if (obj && [obj respondsToSelector:@selector(objectEnumerator)] && [obj respondsToSelector:@selector(count)]) {
					endIndex = [(NSArray *)obj count];
					if (endIndex > 0) {
						loopEnumObject = obj;
						valid = YES;
					}
				}
			}
			
			if (valid) {
				*blockStarted = YES;
				
				// Set up for-stack frame for this loop.
				NSMutableDictionary *stackFrame = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												   [NSValue valueWithRange:markerRange], STACK_START_MARKER_RANGE, 
												   [NSValue valueWithRange:*nextRange], STACK_START_REMAINING_RANGE, 
												   nil];
				[forStack addObject:stackFrame];
				
				// Set up variables for the block.
				NSInteger currentIndex = (reversed) ? endIndex : startIndex;
				NSMutableDictionary *loopVars = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												 [NSNumber numberWithInteger:startIndex], FOR_LOOP_START_INDEX, 
												 [NSNumber numberWithInteger:endIndex], FOR_LOOP_END_INDEX, 
												 [NSNumber numberWithInteger:currentIndex], FOR_LOOP_CURR_INDEX, 
												 [NSNumber numberWithBool:reversed], FOR_REVERSE, 
												 nil];
				NSMutableDictionary *blockVars = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												  loopVars, FOR_LOOP_VARS, 
												  nil];
				
				// Add enumerator variable if appropriate.
				if (!isRange) {
					NSEnumerator *enumerator;
					if (reversed && [loopEnumObject respondsToSelector:@selector(reverseObjectEnumerator)]) {
						enumerator = [(NSArray *)loopEnumObject reverseObjectEnumerator];
					} else {
						enumerator = [(NSArray *)loopEnumObject objectEnumerator];
					}
					[stackFrame setObject:enumerator forKey:FOR_STACK_ENUMERATOR];
					[stackFrame setObject:startArg forKey:FOR_STACK_ENUM_VAR];
					[blockVars setObject:[enumerator nextObject] forKey:startArg];
				}
				
				// Add parentLoop if it exists.
				if (blockInfo) {
					NSDictionary *parentLoop;
					parentLoop = (NSDictionary *)[engine resolveVariable:FOR_LOOP_VARS]; // in case parent loop isn't in the first parent stack-frame.
					if (parentLoop) {
						[loopVars setObject:parentLoop forKey:FOR_PARENT_LOOP];
					}
				}
				
				*newVariables = blockVars;
			} else {
				// Disable output for this block.
				*blockStarted = YES;
				NSMutableDictionary *stackFrame = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												   [NSNumber numberWithBool:YES], FOR_STACK_DISABLED_OUTPUT, 
												   [NSValue valueWithRange:markerRange], STACK_START_MARKER_RANGE, 
												   [NSValue valueWithRange:*nextRange], STACK_START_REMAINING_RANGE, 
												   nil];
				[forStack addObject:stackFrame];
				*outputEnabled = NO;
			}
		}
		
	} else if ([marker isEqualToString:FOR_END]) {
		// Decide whether to loop back or terminate.
		if ([self currentBlock:blockInfo matchesTopOfStack:forStack]) {
			NSMutableDictionary *frame = [forStack lastObject];
			
			// Check to see if this was a block with an invalid looping condition.
			NSNumber *disabledOutput = (NSNumber *)[frame objectForKey:FOR_STACK_DISABLED_OUTPUT];
			if (disabledOutput && [disabledOutput boolValue]) {
				*outputEnabled = YES;
				*blockEnded = YES;
				[forStack removeLastObject];
			}
			
			// This is the same loop that's on top of our stack. Check to see if we need to loop back.
			BOOL loop = NO;
			NSDictionary *blockVars = [blockInfo objectForKey:BLOCK_VARIABLES_KEY];
			if ([blockVars count] == 0) {
				*blockEnded = YES;
				return nil;
			}
			NSMutableDictionary *loopVars = [[[blockVars objectForKey:FOR_LOOP_VARS] mutableCopy] autorelease];
			BOOL reversed = [[loopVars objectForKey:FOR_REVERSE] boolValue];
			NSEnumerator *loopEnum = [frame objectForKey:FOR_STACK_ENUMERATOR];
			NSObject *newEnumValue = nil;
			NSInteger currentIndex = [[loopVars objectForKey:FOR_LOOP_CURR_INDEX] integerValue];
			if (loopEnum) {
				// Enumerator type.
				newEnumValue = [loopEnum nextObject];
				if (newEnumValue) {
					loop = YES;
				}
			} else {
				// Range type.
				if (reversed) {
					NSInteger minIndex = [[loopVars objectForKey:FOR_LOOP_START_INDEX] integerValue];
					if (currentIndex > minIndex) {
						loop = YES;
					}
				} else {
					NSInteger maxIndex = [[loopVars objectForKey:FOR_LOOP_END_INDEX] integerValue];
					if (currentIndex < maxIndex) {
						loop = YES;
					}
				}
			}
			
			if (loop) {
				// Set remainingRange from stack dict
				*nextRange = [[frame objectForKey:STACK_START_REMAINING_RANGE] rangeValue];
				
				// Set new currentIndex
				if (reversed) {
					currentIndex--;
				} else {
					currentIndex++;
				}
				[loopVars setObject:[NSNumber numberWithInteger:currentIndex] forKey:FOR_LOOP_CURR_INDEX];
				
				// Set new val for enumVar if specified
				NSMutableDictionary *newVars = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												loopVars, FOR_LOOP_VARS, 
												nil];
				if (newEnumValue) {
					[newVars setObject:newEnumValue forKey:[frame objectForKey:FOR_STACK_ENUM_VAR]];
				}
				
				*newVariables = newVars;
			} else {
				// Don't need to do much here, since:
				// 1. Each blockStack frame for a "for" has its own currentLoop dict.
				// 2. Parent loop's enum-vars are still in place in the parent stack's vars.
				
				// End block.
				*blockEnded = YES;
				[forStack removeLastObject];
			}
			
			// Return immediately.
			return nil;
		}
		*blockEnded = YES;
	
	} else if ([marker isEqualToString:SECTION_START]) {
		if (args && [args count] == 1) {
			*blockStarted = YES;
			
			// Set up for-stack frame for this section.
			NSMutableDictionary *stackFrame = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											   [NSValue valueWithRange:markerRange], STACK_START_MARKER_RANGE, 
											   nil];
			[sectionStack addObject:stackFrame];
		}
		
	} else if ([marker isEqualToString:SECTION_END]) {
		if ([self currentBlock:blockInfo matchesTopOfStack:sectionStack]) {
			// This is the same section that's on top of our stack. Remove from stack.
			[sectionStack removeLastObject];
		}
		*blockEnded = YES;
		
	} else if ([marker isEqualToString:IF_START]) {
		if (args && ([args count] == 1 || [args count] == 3)) {
			*blockStarted = YES;
			
			// Determine appropriate values for outputEnabled and for our if-stack frame.
			BOOL elseEncountered = NO;
			BOOL argTrue = NO;
			if ([args count] == 1) {
				argTrue = [self argIsTrue:[args objectAtIndex:0]];
			} else if ([args count] == 2 && [[[args objectAtIndex:0] lowercaseString] isEqualToString:@"not"]) {
				// e.g. if not x
				argTrue = ![self argIsTrue:[args objectAtIndex:1]];
			} else if ([args count] == 3) {
				// Assumed to be of the form: operand comparison operand, e.g. x == y
				NSString *firstArg = [args objectAtIndex:0];
				NSString *secondArg = [args objectAtIndex:2];
				BOOL firstTrue = [self argIsTrue:firstArg];
				BOOL secondTrue = [self argIsTrue:secondArg];
				NSInteger num1, num2;
				BOOL firstNumeric, secondNumeric;
				firstNumeric = [self argIsNumeric:firstArg intValue:&num1 checkVariables:YES];
				secondNumeric = [self argIsNumeric:secondArg intValue:&num2 checkVariables:YES];
				if (!firstNumeric) {
					num1 = ([engine resolveVariable:firstArg]) ? 1 : 0;
				}
				if (!secondNumeric) {
					num2 = ([engine resolveVariable:secondArg]) ? 1 : 0;
				}
				NSString *op = [[args objectAtIndex:1] lowercaseString];
				
				if ([op isEqualToString:@"and"] || [op isEqualToString:@"&&"]) {
					argTrue = (firstTrue && secondTrue);
				} else if ([op isEqualToString:@"or"] || [op isEqualToString:@"||"]) {
					argTrue = (firstTrue || secondTrue);
				} else if ([op isEqualToString:@"="] || [op isEqualToString:@"=="]) {
					argTrue = (num1 == num2);
				} else if ([op isEqualToString:@"!="] || [op isEqualToString:@"<>"]) {
					argTrue = (num1 != num2);
				} else if ([op isEqualToString:@">"]) {
					argTrue = (num1 > num2);
				} else if ([op isEqualToString:@"<"]) {
					argTrue = (num1 < num2);
				} else if ([op isEqualToString:@">="]) {
					argTrue = (num1 >= num2);
				} else if ([op isEqualToString:@"<="]) {
					argTrue = (num1 <= num2);
				} else if ([op isEqualToString:@"\%"]) {
					argTrue = ((num1 % num2) > 0);
				}
			}
			
			BOOL shouldDisableOutput = *outputEnabled;
			if (shouldDisableOutput && !argTrue) {
				*outputEnabled = NO;
			}
			
			// Create variables.
			NSMutableDictionary *ifVars = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										   [NSNumber numberWithBool:argTrue], IF_ARG_TRUE, 
										   [NSNumber numberWithBool:shouldDisableOutput], DISABLE_OUTPUT, 
										   [NSNumber numberWithBool:elseEncountered], IF_ELSE_SEEN, 
										   nil];
			
			// Set up for-stack frame for this if-statement.
			NSMutableDictionary *stackFrame = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											   [NSValue valueWithRange:markerRange], STACK_START_MARKER_RANGE, 
											   ifVars, IF_VARS, 
											   nil];
			[ifStack addObject:stackFrame];
		}
		
	} else if ([marker isEqualToString:ELSE]) {
		if ([self currentBlock:blockInfo matchesTopOfStack:ifStack]) {
			NSMutableDictionary *frame = [[ifStack lastObject] objectForKey:IF_VARS];
			BOOL elseSeen = [[frame objectForKey:IF_ELSE_SEEN] boolValue];
			BOOL argTrue = [[frame objectForKey:IF_ARG_TRUE] boolValue];
			BOOL modifyOutput = [[frame objectForKey:DISABLE_OUTPUT] boolValue];
			
			if (!elseSeen) {
				if (modifyOutput) {
					// Only make changes if we've not already seen an 'else' for this block,
					// and if we're modifying output state at all.
					*outputEnabled = !argTrue; // either turning it off, or turning it back on.
				}
				
				// Note that we've now seen the else marker.
				[frame setObject:[NSNumber numberWithBool:YES] forKey:IF_ELSE_SEEN];
			}
		}
		
	} else if ([marker isEqualToString:IF_END]) {
		if ([self currentBlock:blockInfo matchesTopOfStack:ifStack]) {
			NSMutableDictionary *frame = [[ifStack lastObject] objectForKey:IF_VARS];
			BOOL modifyOutput = [[frame objectForKey:DISABLE_OUTPUT] boolValue];
			if (modifyOutput) {
				// If we're modifying output, it was enabled when this block started.
				// Thus, it should be enabled after the block ends.
				// If it's already enabled, this will have no harmful effect.
				*outputEnabled = YES;
			}
			
			// End block.
			[ifStack removeLastObject];
			*blockEnded = YES;
		}
		*blockEnded = YES;
		
	} else if ([marker isEqualToString:NOW]) {
		return [NSDate date];
		
	} else if ([marker isEqualToString:COMMENT_START]) {
		// Work out if we need to start a block.
		if (!args || [args count] == 0) {
			*blockStarted = YES;
			
			// Determine appropriate values for outputEnabled and for our stack frame.
			BOOL shouldDisableOutput = *outputEnabled;
			if (shouldDisableOutput) {
				*outputEnabled = NO;
			}
			
			// Set up for-stack frame for this if-statement.
			NSMutableDictionary *stackFrame = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											   [NSValue valueWithRange:markerRange], STACK_START_MARKER_RANGE, 
											   [NSNumber numberWithBool:shouldDisableOutput], DISABLE_OUTPUT, 
											   nil];
			[commentStack addObject:stackFrame];
		}
		
	} else if ([marker isEqualToString:COMMENT_END]) {
		// Check this is block on top of stack.
		if ([self currentBlock:blockInfo matchesTopOfStack:commentStack]) {
			NSMutableDictionary *frame = [commentStack lastObject];
			BOOL modifyOutput = [[frame objectForKey:DISABLE_OUTPUT] boolValue];
			if (modifyOutput) {
				// If we're modifying output, it was enabled when this block started.
				// Thus, it should be enabled after the block ends.
				// If it's already enabled, this will have no harmful effect.
				*outputEnabled = YES;
			}
			
			// End block.
			[commentStack removeLastObject];
			*blockEnded = YES;
		}
		*blockEnded = YES;
		
	} else if ([marker isEqualToString:LOAD]) {
		if (args && [args count] > 0) {
			for (NSString *className in args) {
				Class class = NSClassFromString(className);
				if (class && [(id)class isKindOfClass:[NSObject class]]) {
					if ([class conformsToProtocol:@protocol(MGTemplateFilter)]) {
						// Instantiate and load filter.
						NSObject <MGTemplateFilter> *obj = [[[class alloc] init] autorelease];
						[engine loadFilter:obj];
					} else if ([class conformsToProtocol:@protocol(MGTemplateMarker)]) {
						// Instantiate and load marker.
						NSObject <MGTemplateMarker> *obj = [[[class alloc] initWithTemplateEngine:engine] autorelease];
						[engine loadMarker:obj];
					}
				}
			}
		}
		
	} else if ([marker isEqualToString:CYCLE]) {
		if (args && [args count] > 0) {
			// Check to see if it's an existing cycle.
			NSString *rangeKey = NSStringFromRange(markerRange);
			NSMutableDictionary *cycle = [cycles objectForKey:rangeKey];
			if (cycle) {
				NSArray *vals = [cycle objectForKey:CYCLE_VALUES];
				NSInteger currIndex = [[cycle objectForKey:CYCLE_INDEX] integerValue];
				currIndex++;
				if (currIndex >= [vals count]) {
					currIndex = 0;
				}
				[cycle setObject:[NSNumber numberWithInteger:currIndex] forKey:CYCLE_INDEX];
				return [vals objectAtIndex:currIndex];
			} else {
				// New cycle. Create and output appropriately.
				cycle = [NSMutableDictionary dictionaryWithCapacity:2];
				[cycle setObject:[NSNumber numberWithInteger:0] forKey:CYCLE_INDEX];
				[cycle setObject:args forKey:CYCLE_VALUES];
				[cycles setObject:cycle forKey:rangeKey];
				return [args objectAtIndex:0];
			}
		}
	} else if ([marker isEqualToString:SET]) {
		if (args && [args count] == 2 && *outputEnabled) {
			// Set variable arg1 to value arg2.
			NSDictionary *newVar = [NSDictionary dictionaryWithObject:[args objectAtIndex:1] 
															   forKey:[args objectAtIndex:0]];
			if (newVar) {
				*newVariables = newVar;
			}
		}
	}
	
	return nil;
}


- (BOOL)currentBlock:(NSDictionary *)blockInfo matchesTopOfStack:(NSMutableArray *)stack
{
	if (blockInfo && [stack count] > 0) { // end-tag should always have blockInfo, and correspond to a stack frame.
		NSDictionary *frame = [stack lastObject];
		NSRange stackSectionRange = [[frame objectForKey:STACK_START_MARKER_RANGE] rangeValue];
		NSRange thisSectionRange = [[blockInfo objectForKey:BLOCK_START_MARKER_RANGE_KEY] rangeValue];
		if (NSEqualRanges(stackSectionRange, thisSectionRange)) {
			return YES;
		}
	}
	return NO;
}


- (BOOL)argIsTrue:(NSString *)arg
{
	BOOL argTrue = NO;
	if (arg) {
		NSObject *val = [engine resolveVariable:arg];
		if (val) {
			if ([val isKindOfClass:[NSNumber class]]) {
				argTrue = [(NSNumber *)val boolValue];
			} else {
				argTrue = YES;
			}
		}
	}
	return argTrue;
}


- (BOOL)argIsNumeric:(NSString *)arg intValue:(NSInteger *)val checkVariables:(BOOL)checkVars
{
	BOOL numeric = NO;
	NSInteger value = 0;
	
	if (arg && [arg length] > 0) {
		if ([[arg substringToIndex:1] isEqualToString:@"0"] || [arg integerValue] != 0) {
			numeric = YES;
			value = [arg integerValue];
		} else if (checkVars) {
			// Check to see if arg is a variable with an intValue.
			NSObject *argObj = [engine resolveVariable:arg];
			NSString *argStr = [NSString stringWithFormat:@"%@", argObj];
			if (argObj && [argObj respondsToSelector:@selector(integerValue)] && 
				[self argIsNumeric:argStr intValue:&value checkVariables:NO]) { // avoid recursion
				numeric = YES;
			}
		}
	}
	
	if (val) {
		*val = value;
	}
	return numeric;
}


- (void)engineFinishedProcessingTemplate
{
	// Clean up stacks etc.
	[forStack release];
	forStack = [[NSMutableArray alloc] init];
	[sectionStack release];
	sectionStack = [[NSMutableArray alloc] init];
	[ifStack release];
	ifStack = [[NSMutableArray alloc] init];
	[commentStack release];
	commentStack = [[NSMutableArray alloc] init];
	cycles = [[NSMutableDictionary alloc] init];
}


@end
