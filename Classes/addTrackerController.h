//
//  addTrackerController.h
//  rTracker
//
//  from this screen the user creates or edits a tracker, by naming it and adding values.
//
//  Created by Robert Miller on 15/04/2010.
//  Copyright 2010 Robert T. Miller. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "trackerList.h"
#import "trackerObj.h"
#import "valueObj.h"

@interface addTrackerController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIActionSheetDelegate>

{
	trackerList *tlist;
	trackerObj *tempTrackerObj;
	UITableView *table;
	UITextField	*nameField;
}

@property (nonatomic, retain) trackerList *tlist;
@property (nonatomic, retain) trackerObj *tempTrackerObj;
@property (nonatomic, retain) IBOutlet UITableView *table;
@property (nonatomic, retain) UITextField *nameField;

- (void)configureToolbarItems;

- (IBAction) nameFieldDone:(id)sender;

@end
