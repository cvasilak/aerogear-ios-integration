/*
 * JBoss, Home of Professional Open Source.
 * Copyright Red Hat, Inc., and individual contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Kiwi/Kiwi.h>
#import <AeroGear/AeroGear.h>

static NSString *const kSalt = @"e5ecbaaf33bd751a1ac728d45e6";
static NSString *const kSaltFail = @"bweywsaf3bbdf5121nc72he412ex";
static NSString *const kPassphrase = @"PASSPHRASE";
static NSString *const kPassphraseFail = @"FAIL_PASSPHRASE";

SPEC_BEGIN(AGEncryptedSQLiteStorageSpec)

describe(@"AGEncryptedSQLiteStorage", ^{
    
    context(@"when newly created", ^{
        
        __block id<AGStore> sqliteStorage = nil;
        __block id<AGEncryptionService> encService = nil;
        
        beforeAll(^{
            AGPassphraseCryptoConfig *cryptoConfig = [[AGPassphraseCryptoConfig alloc] init];
            [cryptoConfig setSalt:[kSalt dataUsingEncoding:NSUTF8StringEncoding]];
            [cryptoConfig setPassphrase:kPassphrase];
            
            encService = [[AGKeyManager manager] keyService:cryptoConfig];
        });
        
        beforeEach(^{
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];
        });
        
        afterEach(^{
            // remove all elements from the store
            // so next test starts fresh
            [sqliteStorage reset:nil];
        });

        it(@"should not be nil", ^{
            //[sqliteStorage shouldNotBeNil];
        });

        it(@"should save a single object ", ^{
            NSMutableDictionary* user = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Corinne", @"name", nil];

            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(YES)];
        });

        it(@"shouldn't save a non serialisable object ", ^{
            NSThread *_thread;
            NSMutableDictionary* user = [NSMutableDictionary dictionaryWithObjectsAndKeys:_thread, @"name", nil];

            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(NO)];
        });

        it(@"should save a single object with id set", ^{
            NSMutableDictionary* user = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Matthias", @"name", nil];

            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            [[user valueForKey:@"id"] shouldNotBeNil];
            [[[user valueForKey:@"id"] should] equal:@"1"];

        });

        it(@"should save a single object with custom id set", ^{
            NSMutableDictionary* user = [NSMutableDictionary
                    dictionaryWithObjectsAndKeys:@"Robert", @"name", nil];

            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                // apply a custom ID config...
                [config setRecordId:@"myId"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // save should have set custom ID
            [[user valueForKey:@"myId"] shouldNotBeNil];
            [[[user valueForKey:@"myId"] should] equal:@"1"];
        });

        it(@"should save an object with embedded aggregate", ^{
            NSMutableDictionary *user = [@{@"id" : @"1",
                                            @"name" : @"Robert",
                                            @"city" : @"Boston",
                                            @"salary" : @2100,
                                            @"department" : @{@"name" : @"Software", @"address" : @"Cornwell"},
                                            @"experience" : @[@{@"language" : @"Java", @"level" : @"advanced"},
                                                              @{@"language" : @"C", @"level" : @"advanced"}]
                                            } mutableCopy];

            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            [[user valueForKey:@"id"] shouldNotBeNil];
            [[[user valueForKey:@"id"] should] equal:@"1"];
        });

        it(@"should save an object without id and read it", ^{
            NSMutableDictionary* user = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Matthias", @"name", nil];

            // store it
            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(YES)];


            NSMutableDictionary* object = [sqliteStorage read:@"1"];
            [[object[@"name"] should] equal:@"Matthias"];

        });

        it(@"should save an object with id and read it", ^{
            NSMutableDictionary* user = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Matthias", @"name", @"11", @"id", nil];

            // store it
            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(YES)];


            NSMutableDictionary* object = [sqliteStorage read:@"11"];
            [[object[@"name"] should] equal:@"Matthias"];

        });

        it(@"should read an object _after_ storing it", ^{
            NSMutableDictionary* user = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Matthias", @"name", nil];

            // store it
            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // read it
            NSMutableDictionary* object = [sqliteStorage read:@"1"];
            [[object[@"name"] should] equal:@"Matthias"];

            [sqliteStorage save:object error:nil];
            [[theValue(success) should] equal:theValue(YES)];
            
            //read it
            NSArray* objects = [sqliteStorage readAll];
            [[objects should] haveCountOf:1];
        });

        it(@"should read an object with customId", ^{
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                // apply a custom ID config...
                [config setRecordId:@"myCustomId"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            [sqliteStorage reset:nil];

            NSMutableDictionary* user = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Matthias", @"name", nil];

            // store it
            BOOL success = [sqliteStorage save:user error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                // apply a custom ID config...
                [config setRecordId:@"myCustomId"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // read it
            NSMutableDictionary* object = [sqliteStorage read:@"1"];
            [[object[@"name"] should] equal:@"Matthias"];

        });

        it(@"should read nothing out of an empty store", ^{
            // read it
            NSArray* objects = [sqliteStorage readAll];

            [[objects should] beEmpty];
        });

        it(@"should read nothing out of an empty store", ^{
            // read it, should be empty
            [[theValue([sqliteStorage isEmpty]) should] equal:theValue(YES)];

        });

        it(@"shouldn't read object out of an empty store", ^{
            NSMutableDictionary *object = [sqliteStorage read:@"someId"];

            [object shouldBeNil];
        });

        it(@"should read and save multiple objects", ^{
            NSMutableDictionary* user1 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"Matthias", @"name", nil];
            NSMutableDictionary* user2 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"abstractj", @"name", nil];
            NSMutableDictionary* user3 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"qmx", @"name", nil];

            NSArray* users = @[user1, user2, user3];

            // store it
            BOOL success = [sqliteStorage save:users error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // read it
            NSArray* objects = [sqliteStorage readAll];

            [[objects should] haveCountOf:(NSUInteger)3];
        });

        it(@"should not be empty after storing objects", ^{
            NSMutableDictionary* user1 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"Matthias", @"name", nil];
            NSMutableDictionary* user2 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"abstractj", @"name", nil];
            NSMutableDictionary* user3 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"qmx", @"name", nil];

            NSArray* users = @[user1, user2, user3];

            // store it
            [sqliteStorage save:users error:nil];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // check if empty:
            [[theValue([sqliteStorage isEmpty]) should] equal:theValue(NO)];
        });

        it(@"should read nothing after reset", ^{
            NSMutableDictionary* user1 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"Matthias",@"name",@"123",@"id", nil];
            NSMutableDictionary* user2 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"abstractj",@"name",@"456",@"id", nil];
            NSMutableDictionary* user3 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"qmx",@"name",@"5",@"id", nil];

            NSArray* users = @[user1, user2, user3];

            NSArray* objects;
            BOOL success;

            // store it
            success = [sqliteStorage save:users error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // read it
            objects = [sqliteStorage readAll];
            [[objects should] haveCountOf:(NSUInteger)3];

            success = [sqliteStorage reset:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // read from the empty store...
            objects = [sqliteStorage readAll];

            [[objects should] haveCountOf:(NSUInteger)0];
        });

        it(@"should be able to do bunch of read, save, reset operations", ^{
            NSMutableDictionary* user1 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"Matthias",@"name",@"33",@"age", nil];
            NSMutableDictionary* user2 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"abstractj",@"name",@"22",@"age", nil];
            NSMutableDictionary* user3 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"qmx",@"name",@"25",@"age", nil];

            NSArray* users = @[user1, user2, user3];

            NSArray* objects;

            BOOL success;

            // store it
            success = [sqliteStorage save:users error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // read it
            objects = [sqliteStorage readAll];
            [[objects should] haveCountOf:(NSUInteger)3];

            [sqliteStorage reset:nil];

            // read from the empty store...
            objects = [sqliteStorage readAll];
            [[objects should] haveCountOf:(NSUInteger)0];

            // store it again...
            success = [sqliteStorage save:users error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // read it again ...
            objects = [sqliteStorage readAll];
            [[objects should] haveCountOf:(NSUInteger)3];

        });

        it(@"should retrieve only one element when we save an object without id, read all and update it", ^{
            NSMutableDictionary* user1 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"Christos", @"name", nil];

            BOOL success;

            success = [sqliteStorage save:user1 error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // read all
            NSArray *object = [sqliteStorage readAll];
            [[(object[0])[@"name"] should] equal:@"Christos"];

            // update newly created element
            success = [sqliteStorage save:object[0] error:nil];

            // read all the store and count
            NSArray* objects = [sqliteStorage readAll];
            [[objects should] haveCountOf:(NSUInteger)1];
        });

        it(@"should fails if not Plist serialization compatible", ^{
            NSMutableDictionary* user1 = [@{@"name":@"toto", @"age":[NSNull null]} mutableCopy];

            BOOL success;
            success = [sqliteStorage save:user1 error:nil];
            [[theValue(success) should] equal:theValue(NO)];

            // read all
            NSArray* objects = [sqliteStorage readAll];
            [[objects should] haveCountOf:(NSUInteger)0];

        });

        it(@"should not read a remove object", ^{
            NSMutableDictionary* user1 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"Sebi", @"name", nil];

            BOOL success;

            success = [sqliteStorage save:user1 error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // read it
            NSMutableDictionary *object = [sqliteStorage read:@"1"];
            [[object[@"name"] should] equal:@"Sebi"];

            // remove the above user:
            success = [sqliteStorage remove:user1 error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // read from the empty store...
            NSArray* objects = [sqliteStorage readAll];
            [[objects should] haveCountOf:(NSUInteger)0];
        });

        it(@"should not remove a non-existing object", ^{
            NSMutableDictionary* user1 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"Matthias", @"name", @"1", @"oid", nil];

            BOOL success;

            success = [sqliteStorage save:user1 error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // read it
            NSMutableDictionary *object = [sqliteStorage read:@"1"];
            [[object[@"name"] should] equal:@"Matthias"];

            NSMutableDictionary* user2 = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Matthias", @"name" ,@"2", @"oid", nil];

            // try to remove the user with the id '1':
            success = [sqliteStorage remove:user2 error:nil];
            [[theValue(success) should] equal:theValue(NO)];

            // should contain the first object
            NSArray* objects = [sqliteStorage readAll];

            [[objects should] haveCountOf:1];
        });

        it(@"should not be able to remove a nil object", ^{
            NSError *error;
            BOOL success;

            success = [sqliteStorage remove:nil error:&error];

            [[theValue(success) should] equal:theValue(NO)];
            [[error.localizedDescription should] equal:@"remove a nil id not possible"];


            success = [sqliteStorage remove:[NSNull null] error:&error];

            [[theValue(success) should] equal:theValue(NO)];
            [[error.localizedDescription should] equal:@"remove a nil id not possible"];
        });

        it(@"should not be able to remove an object with no 'recordId' set", ^{
            NSMutableDictionary* user1 = [NSMutableDictionary
                                          dictionaryWithObjectsAndKeys:@"Matthias",@"name",@"123",@"bogudIdName", nil];

            NSError *error;
            BOOL success = [sqliteStorage remove:user1 error:&error];

            [[theValue(success) should] equal:theValue(NO)];
            [[error.localizedDescription should] equal:@"remove a nil id not possible"];
        });

        it(@"should perform filtering using an NSPredicate", ^{
            NSMutableDictionary *user1 = [@{@"id" : @"0",
                    @"name" : @"Robert",
                    @"city" : @"Boston",
                    @"salary" : @2100,
                    @"department" : @{@"name" : @"Software", @"address" : @"Cornwell"},
                    @"experience" : @[@{@"language" : @"Java", @"level" : @"advanced"},
                            @{@"language" : @"C", @"level" : @"advanced"}]
            } mutableCopy];

            NSMutableDictionary *user2 = [@{@"id" : @"1",
                    @"name" : @"David",
                    @"city" : @"New York",
                    @"salary" : @1400,
                    @"department" : @{@"name" : @"Hardware", @"address" : @"Cornwell"},
                    @"experience" : @[@{@"language" : @"Java", @"level" : @"advanced"},
                            @{@"language" : @"Python", @"level" : @"intermediate"}]
            } mutableCopy];

            NSMutableDictionary *user3 = [@{@"id" : @"2",
                    @"name" : @"Peter",
                    @"city" : @"New York",
                    @"salary" : @1800,
                    @"department" : @{@"name" : @"Software", @"address" : @"Branton"},
                    @"experience" : @[@{@"language" : @"Java", @"level" : @"advanced"},
                            @{@"language" : @"C", @"level" : @"intermediate"}]
            } mutableCopy];

            NSMutableDictionary *user4 = [@{@"id" : @"3",
                    @"name" : @"John",
                    @"city" : @"Boston",
                    @"salary" : @1700,
                    @"department" : @{@"name" : @"Software", @"address" : @"Norwell"},
                    @"experience" : @[@{@"language" : @"Java", @"level" : @"intermediate"},
                            @{@"language" : @"JavaScript", @"level" : @"advanced"}]
            } mutableCopy];

            NSMutableDictionary *user5 = [@{@"id" : @"4",
                    @"name" : @"Graham",
                    @"city" : @"Boston",
                    @"salary" : @2400,
                    @"department" : @{@"name" : @"Software", @"address" : @"Underwood"},
                    @"experience" : @[@{@"language" : @"Java", @"level" : @"advanced"},
                            @{@"language" : @"Python", @"level" : @"advanced"}]
            } mutableCopy];

            NSArray *users = @[user1, user2, user3, user4, user5];

            // save objects
            BOOL success = [sqliteStorage save:users error:nil];
            [[theValue(success) should] equal:theValue(YES)];

            // reload store
            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            NSPredicate *predicate;
            NSArray *results;

            // filter objects
            predicate = [NSPredicate
                    predicateWithFormat:@"city = 'Boston' AND department.name = 'Software' \
                      AND SUBQUERY(experience, $x, $x.language = 'Java' AND $x.level = 'advanced').@count > 0"];

            results = [sqliteStorage filter:predicate];

            // validate size
            [[results should] haveCountOf:2];

            // validate each object
            for (NSDictionary *user in results) {
                [[user[@"city"] should] equal:@"Boston"];
                [[user[@"department"][@"name"] should] equal:@"Software"];

                BOOL contains = [user[@"experience"] containsObject:@{@"language" : @"Java", @"level" : @"advanced"}];
                [[theValue(contains) should] equal:(theValue(YES))];
            }

            // retrieve only users with knowledge of BOTH Java AND Ruby (should be none)
            predicate = [NSPredicate
                    predicateWithFormat:@"SUBQUERY(experience, $x, $x.language IN {'Java', 'Ruby'}).@count = 2"];

            results = [sqliteStorage filter:predicate];

            // validate size
            [[results should] haveCountOf:0];

            // retrieve users with the specified salaries
            predicate = [NSPredicate
                    predicateWithFormat:@"department.name = 'Software' AND salary BETWEEN {1500, 2000}"];

            results = [sqliteStorage filter:predicate];

            // validate size
            [[results should] haveCountOf:2];

            // validate each object
            for (NSDictionary *user in results) {
                [[user[@"department"][@"name"] should] equal:@"Software"];
                [[theValue([user[@"salary"] intValue]) should] beBetween:theValue(1500) and:theValue(2000)];
            }
        });
    });
    
    context(@"should fail to reload with corrupted crypto params", ^{
        
        __block id<AGStore> sqliteStorage = nil;
        __block id<AGEncryptionService> encService = nil;

        NSMutableDictionary * const user = [NSMutableDictionary
                                            dictionaryWithObjectsAndKeys:@"Matthias",@"name",@"0",@"id", nil];
        
        beforeEach(^{
            AGPassphraseCryptoConfig *cryptoConfig = [[AGPassphraseCryptoConfig alloc] init];
            [cryptoConfig setSalt:[kSalt dataUsingEncoding:NSUTF8StringEncoding]];
            [cryptoConfig setPassphrase:kPassphrase];
            
            encService = [[AGKeyManager manager] keyService:cryptoConfig];

            sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                [config setName:@"Users"];
                [config setType:@"ENCRYPTED_SQLITE"];
                [config setEncryptionService:encService];
            }];

            // initialize store with an element
            [sqliteStorage save:user error:nil];
        });
        
        afterEach(^{
            // remove all elements from the store
            // so next test starts fresh
            [sqliteStorage reset:nil];
        });
        
         context(@"should fail to reload with corrupted salt", ^{
             
             beforeEach(^{
                 // re-initialize store with a bogus salt
                 AGPassphraseCryptoConfig *cryptoConfig = [[AGPassphraseCryptoConfig alloc] init];
                 [cryptoConfig setSalt:[kSaltFail dataUsingEncoding:NSUTF8StringEncoding]];
                 [cryptoConfig setPassphrase:kPassphrase];
                 
                 encService = [[AGKeyManager manager] keyService:cryptoConfig];
                 
                 sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                     [config setName:@"Users"];
                     [config setType:@"ENCRYPTED_SQLITE"];
                     [config setEncryptionService:encService];
                 }];
             });
             
            it(@"on (read)", ^{
                // try to read it
                NSMutableDictionary *object = [sqliteStorage read:@"0"];
                // should fail
                [object shouldBeNil];
            });
            
            it(@"on (readAll)", ^{
                // try to read all
                NSArray *objects = [sqliteStorage readAll];
                // should fail
                [objects shouldBeNil];
            });
         });
        
        context(@"should fail to reload with corrupted passphrase", ^{
            
            beforeEach(^{
                // re-initialize store with a bogus salt
                AGPassphraseCryptoConfig *cryptoConfig = [[AGPassphraseCryptoConfig alloc] init];
                [cryptoConfig setSalt:[kSalt dataUsingEncoding:NSUTF8StringEncoding]];
                [cryptoConfig setPassphrase:kPassphraseFail];
                
                encService = [[AGKeyManager manager] keyService:cryptoConfig];
                
                sqliteStorage = [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
                    [config setName:@"Users"];
                    [config setType:@"ENCRYPTED_SQLITE"];
                    [config setEncryptionService:encService];
                }];
            });
            
            it(@"on (read)", ^{
                // try to read it
                NSMutableDictionary* object = [sqliteStorage read:@"0"];
                // should fail
                [object shouldBeNil];
            });
            
            it(@"on (readAll)", ^{
                // try to read all
                NSArray *objects = [sqliteStorage readAll];
                // should fail
                [objects shouldBeNil];
            });
        });
    });
});

SPEC_END