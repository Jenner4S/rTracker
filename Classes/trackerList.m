//
//  trackerList.m
//  rTracker
//
//  Created by Robert Miller on 16/03/2010.
//  Copyright 2010 Robert T. Miller. All rights reserved.
//

#import "trackerList.h"
#import "privacyV.h"
#import "dbg-defs.h"
#import "rTracker-resource.h"

@implementation trackerList

@synthesize topLayoutNames, topLayoutIDs, topLayoutPriv;
//@synthesize tObj;

/******************************
 *
 * trackerList db tables
 *
 *   toplevel: rank(int) ; id(int) ; name(text) ; priv(int)
 *      primarily for entry listbox of tracker names
 *
 ******************************/ 
 
#pragma mark -
#pragma mark core object methods and support

- (void) initTDb {
	//int c;
	
	DBGLog(@"Initializing top level dtabase!");
	self.dbName=@"topLevel.sqlite3";
	[self getTDb];
	
	self.sql = @"create table if not exists toplevel (rank integer, id integer unique, name text, priv integer);";
	[self toExecSql];
	self.sql = @"select count(*) from toplevel;";

	DBGLog(@"toplevel at open contains %d entries",[self toQry2Int]);

	self.sql = @"create table if not exists info (val integer, name text);";
	[self toExecSql];

    self.sql = @"select count(*) from info where name='rtdb_version'";
    if (0 == [self toQry2Int]) {
        DBGLog(@"rtdb_version not set");
        self.sql = [NSString stringWithFormat: @"insert into info (name, val) values ('rtdb_version',%i);",RTDB_VERSION];
        [self toExecSql];
#if DEBUGLOG
    } else {
        self.sql = @"select val from info where name='rtdb_version'";
        DBGLog(@"rtdb_version= %d",[self toQry2Int]);
#endif
    }
    
	self.sql = nil;	
}	

- (id) init {
	DBGLog(@"init trackerList");
	
	if ((self = [super init])) {
		topLayoutNames = [[NSMutableArray alloc] init];
		topLayoutIDs = [[NSMutableArray alloc] init];
        topLayoutPriv = [[NSMutableArray alloc] init];

		[self initTDb];
	} 
	return self;
}

- (void) dealloc {
	DBGLog(@"trackerlist dealloc");
	self.topLayoutNames = nil;
	[topLayoutNames release];
	self.topLayoutIDs = nil;
	[topLayoutIDs release];
	self.topLayoutPriv = nil;
	[topLayoutPriv release];
    
	[super dealloc];
}

#pragma mark -
#pragma mark TopLayoutTable <-> db support 

- (void) loadTopLayoutTable {
    DBGTLIST(self);
	[self.topLayoutNames removeAllObjects];
	[self.topLayoutIDs removeAllObjects];
    [self.topLayoutPriv removeAllObjects];

	//self.sql = @"select * from toplevel";
	//[self toQry2Log];
	
	self.sql = [NSString stringWithFormat:@"select id, name, priv from toplevel where priv <= %i order by rank;",[privacyV getPrivacyValue]];
	[self toQry2AryISI:self.topLayoutIDs s1:self.topLayoutNames i2:self.topLayoutPriv];
	self.sql = nil;
	//DBGLog(@"loadTopLayoutTable finished, priv=%i tlt= %@",[privacyV getPrivacyValue],self.topLayoutNames);
    DBGTLIST(self);
}

- (void) addToTopLayoutTable:(trackerObj*) tObj {
    DBGLog(@"%@ toid %d",tObj.trackerName, tObj.toid);
    
    [self.topLayoutIDs addObject:[NSNumber numberWithInt:tObj.toid]];
    [self.topLayoutNames addObject:tObj.trackerName];
    [self.topLayoutPriv addObject:[NSNumber numberWithInt:[[tObj.optDict valueForKey:@"privacy"] intValue]]];

    [self confirmTopLayoutEntry:tObj];
}

- (void) confirmTopLayoutEntry:(trackerObj *) tObj {
	//self.sql = @"select * from toplevel";
	//[self toQry2Log];
    DBGLog(@"%@ toid %d",tObj.trackerName, tObj.toid);
	DBGTLIST(self);
	self.sql = [NSString stringWithFormat:@"select rank from toplevel where id=%d;",tObj.toid];
	int rank = [self toQry2Int];  // returns 0 if not found 
	if (rank == 0) {
        DBGLog(@"rank not found");
	} else {
        self.sql = [NSString stringWithFormat:@"select count(*) from toplevel where rank=%i and priv <= %i;",rank,[privacyV getPrivacyValue]];
        if (1 < [self toQry2Int]) {
            DBGLog(@"too many at rank %i",rank);
            rank = 0;
        }
    }
	if (rank == 0) {
		rank = [self.topLayoutNames count];  // so put at end
        DBGLog(@"rank adjust, set to %d",rank);
    }
    
    dbgNSAssert(tObj.toid,@"confirmTLE: toid=0");
    int privVal = [[tObj.optDict valueForKey:@"privacy"] intValue];
    privVal = (privVal ? privVal : PRIVDFLT);  // default is 1 not 0;
	self.sql = [NSString stringWithFormat: @"insert or replace into toplevel (rank, id, name, priv) values (%i, %i, \"%@\", %i);",
				rank, tObj.toid, [self toSqlStr:tObj.trackerName], privVal]; 
	[self toExecSql];
	self.sql = nil;
	
	// call loadTopLayoutTable before using:  [topLayoutTable insertObject:name atIndex:rank];
}

- (void) reorderFromTLT {
    DBGTLIST(self);
	int nrank=0;
	for (NSString *tracker in self.topLayoutNames) {
		DBGLog(@" %@ to rank %d",tracker,nrank);
		self.sql = [NSString stringWithFormat :@"update toplevel set rank = %d where name = \"%@\";",nrank+1,[ self toSqlStr:tracker]];
		[self toExecSql];  // better if used bind vars, but this keeps access in tObjBase
		nrank++;
	}
	self.sql = nil;
    DBGTLIST(self);
}

- (void) reloadFromTLT {
    DBGTLIST(self);
	int nrank=0;
	self.sql = [NSString stringWithFormat:@"delete from toplevel where priv <= %d;",[privacyV getPrivacyValue] ];
	[self toExecSql];
	for (NSString *tracker in self.topLayoutNames) {
		NSInteger tid = [[self.topLayoutIDs objectAtIndex:nrank] intValue];
		NSInteger priv = [[self.topLayoutPriv objectAtIndex:nrank] intValue];
		
		DBGLog(@" %@ id %d to rank %d",tracker,tid,nrank);
		self.sql = [NSString stringWithFormat: @"insert into toplevel (rank, id, name, priv) values (%i, %d, \"%@\", %d);",nrank+1,tid,[self toSqlStr:tracker], priv];  // rank in db always non-0
		[self toExecSql];  // better if used bind vars, but this keeps access in tObjBase
		self.sql = nil;
		nrank++;
	}
}

- (int) getTIDfromIndex:(NSUInteger)ndx {
	return [[self.topLayoutIDs objectAtIndex:ndx] intValue];
}

- (BOOL) checkTIDexists:(NSNumber*)tid {
    for (NSNumber *i in self.topLayoutIDs) {
        if ([tid isEqualToNumber:i]) {
            return TRUE;
        }
    }
    return FALSE;
}

- (int) getTIDfromName:(NSString *)str {
    int ndx=0;
    for (NSString *tname in self.topLayoutNames) {
        if ([tname isEqualToString:str])
            return [self getTIDfromIndex:ndx];
        ndx++;
    }
    return 0;
}

- (void) fixDictTID:(NSDictionary*)tdict {
    [self minUniquev:[[tdict objectForKey:@"tid"] intValue]];
    
    if ([self checkTIDexists:[tdict objectForKey:@"tid"]]) {
        DBGLog(@" tid exists already: %@",[tdict objectForKey:@"tid"]);
        [tdict setValue:[NSNumber numberWithInt:[self getUnique]] forKey:@"tid"];
        DBGLog(@"  changed to: %@",[tdict objectForKey:@"tid"]);
    }
}

/*
 // discard for now, write each tracker as csv ile
 
#pragma mark -
#pragma mark write tracker list xls file

- (void) writeTListXLS:(NSFileHandle*)nsfh {
	
	for (id *tID in self.topLayoutIDs) {
		trackerObj *to = [[trackerObj alloc] init:[(NSNumber*)tID intValue]];
		[to writeTrackerXLS:nsfh];
		[to release];
	}
}
*/

#pragma mark -
#pragma mark tracker manipulation methods

- (void) reorderTLT : (NSUInteger) fromRow toRow:(NSUInteger)toRow
{
	DBGTLIST(self);

	id tName = [[self.topLayoutNames objectAtIndex:fromRow] retain];
	id tID = [[self.topLayoutIDs objectAtIndex:fromRow] retain];
    id tPriv = [[self.topLayoutPriv objectAtIndex:fromRow] retain];
	
	[self.topLayoutNames removeObjectAtIndex:fromRow];
	[self.topLayoutIDs removeObjectAtIndex:fromRow];
	[self.topLayoutPriv removeObjectAtIndex:fromRow];
	
	[self.topLayoutNames insertObject:tName atIndex:toRow];
	[self.topLayoutIDs insertObject:tID atIndex:toRow];
	[self.topLayoutPriv insertObject:tPriv atIndex:toRow];
	
	[tName release];
	[tID release];
    [tPriv release];

	DBGTLIST(self);
}

- (trackerObj *) copyToConfig : (trackerObj *) srcTO {
	DBGLog(@"copyToConfig: src id= %d %@",srcTO.toid,srcTO.trackerName);
	trackerObj *newTO = [trackerObj alloc];
	newTO.toid = [self getUnique];
	newTO = [newTO init];
	
	NSString *oTN = srcTO.trackerName;
	//NSString *nTN = [[NSString alloc] initWithString:oTN];
	//newTO.trackerName = nTN;
	// release as well
	newTO.trackerName = [NSString stringWithString:oTN];
	
	//NSEnumerator *enumer = [srcTO.valObjTable objectEnumerator];
	//valueObj *vo;
	//while (vo = (valueObj *) [enumer nextObject]) {
	for (valueObj *vo in srcTO.valObjTable) {
		valueObj *newVO = [newTO copyVoConfig:vo];
		[newTO addValObj:newVO];
		[newVO release];
	}
	
	[newTO saveConfig];
	DBGLog(@"copyToConfig: copy id= %d %@",newTO.toid,newTO.trackerName);
	
	return newTO;
}

- (void) deleteTrackerAllRow:(NSUInteger)row
{
	int tid = [[self.topLayoutIDs objectAtIndex:row] intValue];
	trackerObj *to = [[trackerObj alloc] init:tid];
    DBGLog(@"delete tracker all name:%@ id:%d rowtext= %@", to.trackerName, to.toid, [self.topLayoutNames objectAtIndex:row] );
	[to deleteTrackerDB];
	[to release];
	[self.topLayoutNames removeObjectAtIndex:row];
	[self.topLayoutIDs removeObjectAtIndex:row];
    [self.topLayoutPriv removeObjectAtIndex:row];
}

- (void) deleteTrackerRecordsRow:(NSUInteger)row
{
	int tid = [[self.topLayoutIDs objectAtIndex:row] intValue];
	trackerObj *to = [[trackerObj alloc] init:tid];
	[to deleteTrackerRecordsOnly];
	[to release];
}

- (void) exportAll {
    float ndx=1.0;
    float all = [self.topLayoutIDs count];
    
    for (NSNumber *tid in self.topLayoutIDs) {
        trackerObj *to = [[trackerObj alloc] init:[tid intValue]];
        [to export];
        [to release];
        
        [rTracker_resource setProgressVal:(ndx/all)];
        ndx += 1.0;
    }
}

- (BOOL) testConflict:(NSString*) tname {
    for (NSString *n in self.topLayoutNames) {
        if ([tname isEqualToString:n]) {
            return TRUE;
        }
    }
    return FALSE;
}

- (void) deConflict:(trackerObj*)newTracker {
    if (! [self testConflict:newTracker.trackerName])
        return;

    int i=2;
    NSString *tstr;
    
    while ([self testConflict:(tstr = [NSString stringWithFormat:@"%@ %d",newTracker.trackerName,i++])]) ;
    newTracker.trackerName = tstr;
    [newTracker.optDict setObject:tstr forKey:@"name"];
}

@end
