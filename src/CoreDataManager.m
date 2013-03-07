//
//  CoreDataManager.m
//  WidgetPush
//
//  Created by Marin on 9/1/11.
//  Copyright (c) 2011 mneorr.com. All rights reserved.
//

#import "CoreDataManager.h"

@implementation CoreDataManager
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize databaseName = _databaseName;
@synthesize modelName = _modelName;

static CoreDataManager *singleton;

+ (id)instance {
    static dispatch_once_t singletonToken;
    dispatch_once(&singletonToken, ^{
        singleton = [[self alloc] init];
    });
    
    return singleton;
}


#pragma mark - Private

- (NSString *)appName {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
}

- (NSString *)databaseName {
    if (_databaseName != nil) return _databaseName;
    _databaseName = [[[self appName] stringByAppendingString:@".sqlite"] copy];
    return _databaseName;
}

- (NSString *)modelName {
    if (_modelName != nil) return _modelName;
    _modelName = [[self appName] copy];
    return _modelName;
}

#pragma mark - Public

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) return _managedObjectContext;
    
    if (self.persistentStoreCoordinator) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel) return _managedObjectModel;
    
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:[self modelName] withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

-(void) setUpPersistentStoreCoordinator {

    NSURL *storeURL = [self.applicationDocumentsDirectory URLByAppendingPathComponent:[self databaseName]];
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
        NSLog(@"ERROR IN PERSISTENT STORE COORDINATOR! %@, %@", error, [error userInfo]);
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator) return _persistentStoreCoordinator;
    
    [self setUpPersistentStoreCoordinator];   
    return _persistentStoreCoordinator;
}


- (BOOL)saveContext {
	__block BOOL savedOK = NO;
	
	[self.managedObjectContext preformBlockAndWait:^{
		if (self.managedObjectContext == nil || ![self.managedObjectContext hasChanges]) return;
		
		NSError *error = nil;
		
		if (![self.managedObjectContext save:&error]) {
			NSLog(@"Unresolved error in saving context! %@, %@", error, [error userInfo]);
			return;
		}
		
		savedOK = YES;
	}];
    
    return savedOK;
}

#pragma mark - Application's Documents directory
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory 
                                                   inDomains:NSUserDomainMask] lastObject];
}


@end
