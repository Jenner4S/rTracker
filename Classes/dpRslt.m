//
//  dpRslt.m
//  rTracker
//
//  Created by Rob Miller on 18/05/2011.
//  Copyright 2011 Robert T. Miller. All rights reserved.
//

#import "dpRslt.h"


@implementation dpRslt

@synthesize date,action;

- (id) init {
    if ((self = [super init])) {
        action=DPA_CANCEL;
    }
    return self;
}

@end