// This class is a dummy.
// It is only present because DBView.xib already references it, but the
// code itself is still in another branch. This stub is used to avoid a warning
// from the Nib loader, saying 'this class was not found and replaced with a NSObject'.

#import <Foundation/Foundation.h>

@class SPSplitView;
@class SPTableData;
@class SPDatabaseDocument;
@class SPTablesList;

@interface SPTableContentFilterController : NSObject {
	    IBOutlet SPSplitView *contentSplitView;
	    IBOutlet NSRuleEditor *filterRuleEditor;
	    IBOutlet SPTableData *tableDataInstance;
	    IBOutlet SPDatabaseDocument *tableDocumentInstance;
		IBOutlet SPTablesList *tablesListInstance;
}

@end
