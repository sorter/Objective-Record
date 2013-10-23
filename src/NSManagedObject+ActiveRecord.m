//
//  NSManagedObject+ActiveRecord.m
//  WidgetPush
//
//  Created by Marin Usalj on 4/15/12.
//  Copyright (c) 2012 http://mneorr.com. All rights reserved.
//

#import "NSManagedObject+ActiveRecord.h"

@implementation NSManagedObjectContext (ActiveRecord)

+ (NSManagedObjectContext *)defaultContext {
	return [[CoreDataManager instance] managedObjectContext];
}
@end

@implementation NSManagedObject (ActiveRecord)

#pragma mark - Finders

+ (NSArray *)all {
	return [self allInContext:[NSManagedObjectContext defaultContext]];
}

+ (NSArray *)allInContext:(NSManagedObjectContext *)context {
	return [self fetchWithPredicate:nil inContext:context];
}

+ (NSArray *)whereFormat:(NSString *)format, ... {
	va_list va_arguments;
	va_start(va_arguments, format);
	NSString *condition = [[NSString alloc] initWithFormat:format arguments:va_arguments];
	va_end(va_arguments);
	
	return [self where:condition];
}

+ (NSArray *)inContext:(NSManagedObjectContext *)context WhereFormat:(NSString *)format, ... {
	va_list va_arguments;
	va_start(va_arguments, format);
	NSString *condition = [[NSString alloc] initWithFormat:format arguments:va_arguments];
	va_end(va_arguments);
	
	return [self where:condition inContext:context];
}

+ (NSArray *)where:(id)condition {
	return [self where:condition
			 inContext:[NSManagedObjectContext defaultContext]];
}

+ (NSArray *)where:(id)condition inContext:(NSManagedObjectContext *)context {
	NSPredicate *predicate = ([condition isKindOfClass:[NSPredicate class]]) ? condition :
	[self predicateFromStringOrDict:condition];
	
	return [self fetchWithPredicate:predicate
						  inContext:context];
}


#pragma mark - Creation / Deletion

+ (id)create {
	return [self createInContext:[NSManagedObjectContext defaultContext]];
}

+ (id)create:(NSDictionary *)attributes {
	return [self create:attributes
			  inContext:[NSManagedObjectContext defaultContext]];
}

+ (id)create:(NSDictionary *)attributes inContext:(NSManagedObjectContext *)context {
	NSManagedObject *newEntity = [self createInContext:context];
	
	[newEntity setValuesForKeysWithDictionary:attributes];
	return newEntity;
}

+ (id)createInContext:(NSManagedObjectContext *)context {
	__block NSEntityDescription *description;
	
	if (context.concurrencyType == NSMainQueueConcurrencyType && [[NSThread currentThread] isEqual:[NSThread mainThread]]) {
		description = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self)
													inManagedObjectContext:context];
	} else {
		[context performBlockAndWait:^{
			description = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self)
														inManagedObjectContext:context];
		}];
	}
	
	return description;
}

- (BOOL)save {
	return [self saveTheContext];
}

- (void)delete {
	[self.managedObjectContext deleteObject:self];
	[self saveTheContext];
}

+ (void)deleteAll {
	[self deleteAllInContext:[NSManagedObjectContext defaultContext]];
}

+ (void)deleteAllInContext:(NSManagedObjectContext *)context {
	
	[[self allInContext:context] each:^(id object) {
		[object delete];
	}];
}

#pragma mark - Private

+ (NSString *)queryStringFromDictionary:(NSDictionary *)conditions {
	NSMutableString *queryString = [NSMutableString new];
	
	[conditions each:^(id attribute, id value) {
		if ([value isKindOfClass:[NSString class]]) {
            if ([value isEqualToString:@"nil"]) 
                [queryString appendFormat:@"%@ = %@", attribute, value];
            else
			    [queryString appendFormat:@"%@ == '%@'", attribute, value];
        } else
			[queryString appendFormat:@"%@ == %@", attribute, value];
		
		if (attribute == conditions.allKeys.last) return;
		[queryString appendString:@" AND "];
	}];
	
	return queryString;
}

+ (NSPredicate *)predicateFromStringOrDict:(id)condition {
	
	if ([condition isKindOfClass:[NSString class]])
		return [NSPredicate predicateWithFormat:condition];
	
	else if ([condition isKindOfClass:[NSDictionary class]])
		return [NSPredicate predicateWithFormat:[self queryStringFromDictionary:condition]];
	
	return nil;
}

+ (NSFetchRequest *)createFetchRequestInContext:(NSManagedObjectContext *)context {
	
	NSFetchRequest *request = [NSFetchRequest new];
	NSEntityDescription *entity = [NSEntityDescription entityForName:NSStringFromClass(self)
											  inManagedObjectContext:context];
	[request setEntity:entity];
	return request;
}

+ (NSArray *)fetchWithPredicate:(NSPredicate *)predicate
					  inContext:(NSManagedObjectContext *)context {
	
	NSFetchRequest *request = [self createFetchRequestInContext:context];
	[request setPredicate:predicate];
	
	NSArray *fetchedObjects = [NSArray arrayWithArray:[context executeFetchRequest:request error:nil]];
	
	if (fetchedObjects.count > 0) return fetchedObjects;
	return nil;
}

- (BOOL)saveTheContext {
	
	__block BOOL savedOK = YES;
	
	if (self.managedObjectContext.concurrencyType == NSMainQueueConcurrencyType) {
		if (self.managedObjectContext == nil ||
			![self.managedObjectContext hasChanges]) return YES;
		
		NSError *error = nil;
		
		if (![self.managedObjectContext save:&error]) {
			NSLog(@"Unresolved error in saving context for entity: %@!\n Error: %@", self, error);
			return NO;
		}
		
	} else {
		[self.managedObjectContext performBlockAndWait:^{
			if (self.managedObjectContext != nil || [self.managedObjectContext hasChanges]) {
				NSError *error = nil;
				
				if (![self.managedObjectContext save:&error]) {
					NSLog(@"Unresolved error in saving context for entity: %@!\n Error: %@", self, error);
					savedOK = NO;
				}
			}
		}];
	}
	
	
	return savedOK;
}

@end
