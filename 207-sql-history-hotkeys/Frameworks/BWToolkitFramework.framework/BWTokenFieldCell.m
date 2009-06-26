//
//  BWTokenFieldCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTokenFieldCell.h"
#import "BWTokenAttachmentCell.h"

@implementation BWTokenFieldCell

- (id)setUpTokenAttachmentCell:(NSTokenAttachmentCell *)aCell forRepresentedObject:(id)anObj 
{
	BWTokenAttachmentCell *attachmentCell = [[BWTokenAttachmentCell alloc] initTextCell:[aCell stringValue]];
	
	[attachmentCell setRepresentedObject:anObj];
	[attachmentCell setAttachment:[aCell attachment]];
	[attachmentCell setControlSize:[self controlSize]];
	[attachmentCell setTextColor:[NSColor blackColor]];
	[attachmentCell setFont:[self font]];
	
	return [attachmentCell autorelease];
}

@end
