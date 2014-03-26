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
#import <AeroGear.h>

SPEC_BEGIN(AGPagingWebLinking_AGControllerSpec)

describe(@"AGPagingWebLinking_AGController", ^{
    
    context(@"when newly created", ^{
        __block AGPipeline* agPipeline = nil;
        __block id<AGPipe> cars = nil;
        
        __block BOOL finishedFlag = NO;
        
        beforeEach(^{
            // setting up the pipeline for the AeroGear Controller pipe
            NSURL* baseURL = [NSURL URLWithString:@"https://controller-aerogear.rhcloud.com/aerogear-controller-demo"];
            
            agPipeline = [AGPipeline pipelineWithBaseURL:baseURL];
            
            cars = [agPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"cars"];
            }];
        });
        
        afterEach(^{
            finishedFlag = NO;
        });
        
        it(@"should successfully move to the next page", ^{
            __block NSMutableArray *pagedResultSet;
            
            // fetch the first page
            [cars readWithParams:@{@"color" : @"black", @"offset" : @"0", @"limit" : @1} success:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // hold the "car id" from the first page, so that
                // we can match with the result when we move
                // to the next page down in the test.
                NSString *car_id = [[[responseObject objectAtIndex:0] objectForKey:@"id"] stringValue];
                
                // move to the next page
                [pagedResultSet next:^(id responseObject) {
                    NSString *ncar_id = [[[responseObject objectAtIndex:0] objectForKey:@"id"] stringValue];
                    
                    // id's should not match
                    [[car_id shouldNot] equal:ncar_id];
                    
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    fail(@"should have read");
                    finishedFlag = YES;
                }];
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should successfully move back from the first page", ^{
            __block NSMutableArray *pagedResultSet;
            
            // fetch the first page
            [cars readWithParams:@{@"color" : @"black", @"offset" : @"0", @"limit" : @1} success:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // move back to an invalid page
                [pagedResultSet previous:^(id responseObject) {
                    
                    fail(@"should NOT have read");
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    finishedFlag = YES;
                    
                    // Note: "failure block" was called here
                    // because we were at the first page and we
                    // requested to go previous, that is to a non
                    // existing page ("AG-Links-Previous" indentifier
                    // was missing from the headers response and we
                    // got a 400 http error).
                    //
                    // Note that this is not always the case, cause some
                    // remote apis can send back either an empty list or
                    // list with results, instead of throwing an error(see GitHub testcase)
                }];
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should successfully move next and back", ^{
            __block NSMutableArray *pagedResultSet;
            
            // fetch the first page
            [cars readWithParams:@{@"color" : @"black", @"offset" : @"0", @"limit" : @1} success:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // hold the "car id" from the first page, so that
                // we can match with the result when we move
                // to the next page down in the test.
                NSString *car_id = [[[responseObject objectAtIndex:0] objectForKey:@"id"] stringValue];
                
                // move to the second page
                [pagedResultSet next:^(id responseObject) {
                    
                    // move backwards (aka. page 1)
                    [pagedResultSet previous:^(id responseObject) {
                        NSString *ncar_id = [[[responseObject objectAtIndex:0] objectForKey:@"id"] stringValue];
                        
                        // id's should match
                        [[car_id should] equal:ncar_id];
                        
                        finishedFlag = YES;
                        
                    } failure:^(NSError *error) {
                        fail(@"should have read");
                        finishedFlag = YES;
                    }];
                } failure:^(NSError *error) {
                    fail(@"should have read");
                    finishedFlag = YES;
                }];
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should respect parameter provider settings", ^{
            id<AGPipe> cars = [agPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"cars"];
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setParameterProvider:@{@"color" : @"black", @"offset" : @"0", @"limit" : @1}];
                }];
            }];
            
            [cars readWithParams:nil success:^(id responseObject) {
                
                [[theValue([responseObject count]) should] equal:theValue(1)];
                
                // override the results per page from parameter provider
                [cars readWithParams:@{@"color" : @"black", @"offset" : @"0", @"limit" : @4} success:^(id responseObject) {
                    
                    [[theValue([responseObject count]) should] equal:theValue(4)];
                    
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    fail(@"should have read");
                    finishedFlag = YES;
                }];
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should fail with bogus next identifier", ^{
            id<AGPipe> cars = [agPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"cars"];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setMetadataLocation:@"header"];
                    
                    // wrong setting:
                    [pageConfig setNextIdentifier:@"foo"];
                }];
            }];
            
            __block NSMutableArray *pagedResultSet;
            
            [cars readWithParams:@{@"color" : @"black", @"offset" : @"0", @"limit" : @1} success:^(id responseObject) {
                
                pagedResultSet = responseObject;
                
                [pagedResultSet next:^(id responseObject) {
                    
                    fail(@"should NOT have read");
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    // Note: failure is called cause the next identifier
                    // is invalid so we can't move to the next page
                    finishedFlag = YES;
                }];
                
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should fail with bogus previous identifier", ^{
            id<AGPipe> cars = [agPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"cars"];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setMetadataLocation:@"header"];
                    
                    // wrong setting:
                    [pageConfig setPreviousIdentifier:@"foo"];
                }];
            }];
            
            __block NSMutableArray *pagedResultSet;
            
            [cars readWithParams:@{@"color" : @"black", @"offset" : @"2", @"limit" : @1} success:^(id responseObject) {
                
                pagedResultSet = responseObject;
                
                [pagedResultSet previous:^(id responseObject) {
                    
                    fail(@"should NOT have read");
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    // Note: failure is called cause the previous identifier
                    // is invalid so we can't move to the previous page
                    
                    finishedFlag = YES;
                }];
                
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should fail with bogus metadata location", ^{
            id<AGPipe> cars = [agPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"cars"];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    // wrong setting:
                    [pageConfig setMetadataLocation:@"body"];
                }];
            }];
            
            __block NSMutableArray *pagedResultSet;
            
            [cars readWithParams:@{@"color" : @"black", @"offset" : @"2", @"limit" : @1} success:^(id responseObject) {
                
                pagedResultSet = responseObject;
                
                [pagedResultSet next:^(id responseObject) {
                    
                    fail(@"should NOT have read");
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    finishedFlag = YES;
                }];
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
    });
});

SPEC_END