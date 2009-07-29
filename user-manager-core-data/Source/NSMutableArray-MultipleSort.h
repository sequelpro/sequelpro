//
//  NSMutableArray-MultipleSort.h
//  iContractor
//
//  Created by Jeff LaMarche on 1/16/09.
//  Copyright 2009 Jeff LaMarche. All rights reserved.
//

// This category on NSMutableArray implements a shell sort based on the old NeXT example 
// SortingInAction. It is functionally identical to sortArrayUsingSelector: except that
// it will sort other paired arrays based on the comparison values of the original array
// this is for use in paired array situations, such as when you use one array to store
// keys and another array to store values. This is a variadic method, so you can sort
// as many paired arrays as you have.

// This source may be used, free of charge, for any purposes. commercial or non-
// commercial. There is no attribution requirement, nor any need to distribute
// your source code. If you do redistribute the source code, you must
// leave the original header comments, but you may add additional ones.


// Stride factor defines the size of the shell sort loop's stride. It can be tweaked 
// for performance, though 3 seems to be a good general purpose value
#define STRIDE_FACTOR 3 

#import <Foundation/Foundation.h>

// This compare method was taken from the GNUStep project. GNUStep is
// licensed under the LGPL, which allows such use.
static inline NSComparisonResult compare(id elem1, id elem2, void* context)
{
	NSComparisonResult (*imp)(id, SEL, id);

	if (context == 0) {
		[NSException raise: NSInvalidArgumentException
					format: @"compare null selector given"];
	}

	imp = (NSComparisonResult (*)(id, SEL, id))
	[elem1 methodForSelector: context];

	if (imp == NULL) {
		[NSException raise: NSGenericException
					format: @"invalid selector passed to compare"];
	}

	return (*imp)(elem1, context, elem2);
}

@interface NSMutableArray(MultipleSort)

// Takes a comparator and a nil-terminated list of paired arrays
- (void)sortArrayUsingSelector:(SEL)comparator withPairedMutableArrays:(NSMutableArray *)array1, ...;
@end
