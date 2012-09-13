//
//  SPMySQLHTTPTunnelResponseData.m
//  SPMySQLFramework
//
//  Created by Ramon Fritsch on 8/22/12.
//
//

#import "SPMySQLHTTPTunnelResponseData.h"

@implementation SPMySQLHTTPTunnelResponseData

@synthesize position;

- (id)initWithData:(NSData *)theData
{
	if (self = [super init])
	{
		data = [theData retain];
		position = 0;
	}
	return self;
}

- (void)dealloc
{
	[data release];
	
	[super dealloc];
}

- (void)seekToPos:(NSUInteger)thePosition
{
	position = MIN(thePosition, [data length]);
}

#pragma mark - Read methods
- (unsigned char)readChar //8 bits
{
	unsigned char buffer = 0;
	unsigned long length = sizeof(unsigned char);
	
	if (position < [data length])
	{
		[data getBytes:&buffer range:NSMakeRange(position, length)];
	}
	else
	{
		position = [data length];
		length = 0;
	}
	
	position += length;
	
	return buffer;
}

- (UInt32)readLong //32 bits
{
	UInt32 buffer = 0;
	unsigned long length = sizeof(UInt32);
	
	if (position < [data length])
	{
		[data getBytes:&buffer range:NSMakeRange(position, length)];
		buffer = NSSwapBigIntToHost(buffer);
	}
	else
	{
		position = [data length];
		length = 0;
	}
	
	position += length;
	
	return buffer;
}

- (char *)readBlock
{
	return [self _readBlock:YES forString:NO blockLength:NULL];
}

- (char *)readBlockGettingLength:(unsigned long *)length
{
	return [self _readBlock:YES forString:NO blockLength:length];
}

- (NSString *)readBlockAsString
{
	unsigned long length;
	char *buffer = [self _readBlock:YES forString:YES blockLength:&length];
	
	NSString *string = nil;
	
	if (buffer)
	{
		//NSLog(@"### read STRING: %s, size: %li, length: %lu", buffer, strlen(buffer), length);
		
		buffer[length] = '\0';
		string = [NSString stringWithUTF8String:buffer];
	
		free(buffer);
	}
	
	return string;
}

- (void)skipBlock
{
	[self _readBlock:NO forString:NO blockLength:NULL];
}

#pragma mark - Private methods

- (char *)_readBlock:(BOOL)read forString:(BOOL)forString blockLength:(unsigned long *)length
{
	UInt32 blockLength = (UInt32)[self readChar];
	
	if (blockLength == 0xFF)
	{
		if (length)
		{
			*length = 1;
		}
		
		return NULL;
	}
	else if (blockLength == 0xFE)
	{
		blockLength = [self readLong];
		//NSLog(@"--------------- BLOCK LENGTH IS GREATER THAN 253 ------------- %u", blockLength);
	}
	
	if ((unsigned long)(position + blockLength) > (unsigned long)[data length])
	{
		NSLog(@"trying to read something weird. position: %li, blockLength: %i, dataLength: %li", position, blockLength, [data length]);
		//read = NO;
		
		//blockLength = 0;
	}
	
	char *buffer = NULL;
	
	if (read)
	{
		if (forString)
		{
			buffer = malloc((blockLength + 1) * sizeof(char));
		}
		else
		{
			buffer = malloc(blockLength * sizeof(char));
		}
		
		[data getBytes:buffer range:NSMakeRange(position, blockLength)];
		
		/*if (!forString)
		{
			NSLog(@"### read BLOCK: %p, length: %i", buffer, blockLength);
		}*/
	}
	
	position += blockLength;

	if (length)
	{
		*length = blockLength;
	}
	
	return buffer;
}


@end
