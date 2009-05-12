/*
 *  MGTemplateMarker.h
 *
 *  Created by Matt Gemmell on 12/05/2008.
 *  Copyright 2008 Instinctive Code. All rights reserved.
 *
 */

#import "MGTemplateEngine.h"

@protocol MGTemplateMarker
@required
- (id)initWithTemplateEngine:(MGTemplateEngine *)engine; // to avoid retain cycles, use a weak reference for engine.
- (NSArray *)markers; // array of markers (each unique across all markers) this object handles.
- (NSArray *)endMarkersForMarker:(NSString *)marker; // returns the possible corresponding end-markers for a marker which has just started a block.
- (NSObject *)markerEncountered:(NSString *)marker withArguments:(NSArray *)args inRange:(NSRange)markerRange 
				   blockStarted:(BOOL *)blockStarted blockEnded:(BOOL *)blockEnded 
				  outputEnabled:(BOOL *)outputEnabled nextRange:(NSRange *)nextRange 
			   currentBlockInfo:(NSDictionary *)blockInfo newVariables:(NSDictionary **)newVariables;
/* Notes for -markerEncountered:... method
	Arguments:
		marker:				marker encountered by the template engine
		args:				arguments to the marker, in order
		markerRange:		the range of the marker encountered in the engine's templateString
		blockStarted:		pointer to BOOL. Set it to YES if the marker just started a block.
 		blockEnded:			pointer to BOOL. Set it to YES if the marker just ended a block.
							Note: you should never set both blockStarted and blockEnded in the same call.
		outputEnabled:		pointer to BOOL, indicating whether the engine is currently outputting. Can be changed to switch output on/off.
		nextRange:			the next range in the engine's templateString which will be searched. Can be modified if necessary.
		currentBlockInfo:	information about the current block, if the block was started by this handler; otherwise nil.
							Note: if supplied, will include a dictionary of variables set for the current block.
		newVariables:		variables to set in the template context. If blockStarted is YES, these will be scoped only within the new block.
							Note:	if currentBlockInfo was specified, variables set in the return dictionary will override/update any variables of 
							the same name in currentBlockInfo's variables. This is for ease of updating loop-counters or such.
	Returns:
		A return value to insert into the template output, or nil if nothing should be inserted.
 */

- (void)engineFinishedProcessingTemplate;

@end
