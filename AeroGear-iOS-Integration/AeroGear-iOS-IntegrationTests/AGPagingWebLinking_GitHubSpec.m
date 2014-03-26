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

SPEC_BEGIN(AGPagingWebLinking_GitHubSpec)

describe(@"AGPagingWebLinking_GitHub", ^{
    context(@"when newly created", ^{
        
        __block AGPipeline *ghPipeline = nil;
        __block id<AGPipe> gists = nil;
        
        __block BOOL finishedFlag = NO;

        beforeEach(^{
            // setting up the pipeline for the GitHub pipe
            NSURL *baseURL = [NSURL URLWithString:@"https://api.github.com/users/matzew/"];
            
            ghPipeline = [AGPipeline pipelineWithBaseURL:baseURL];
            
            gists = [ghPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"gists"];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setPreviousIdentifier:@"prev"]; // github uses different than the AG ctrl
                    [pageConfig setParameterProvider:@{@"page" : @"1", @"per_page" : @"5"}];
                }];
            }];
        });
        
        afterEach(^{
            finishedFlag = NO;
        });
        
        it(@"should successfully move to the next page", ^{
            __block NSMutableArray *pagedResultSet;
            
            // fetch the first page
            [gists readWithParams:@{@"page" : @"1", @"per_page" : @"1"} success:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // hold the "id" from the first page, so that
                // we can match with the result when we move
                // to the next page down in the test. (hopefully ;-))
                NSString *gist_id = [[responseObject objectAtIndex:0] objectForKey:@"id"];
                
                // move to the next page
                [pagedResultSet next:^(id responseObject) {
                    NSString* ngist_id = [[responseObject objectAtIndex:0] objectForKey:@"id"];
                    
                    // id's should not match
                    [[gist_id shouldNot] equal:ngist_id];
               
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
            [gists readWithParams:@{@"page" : @"1", @"per_page" : @"1"} success:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // move back from the first page
                [pagedResultSet previous:^(id responseObject) {
                    
                    // Note: although success is called
                    // and we ask a non existing page
                    // (prev identifier was missing from the response)
                    // github responded with a list of results.
                    
                    // Some apis such as github respond even on the
                    // invalid page but others may throw an error

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
        
        it(@"should successfully move next and back", ^{
            __block NSMutableArray *pagedResultSet;
            
            // fetch the first page
            [gists readWithParams:@{@"page" : @"0", @"per_page" : @"1"} success:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // hold the "id" from the first page, so that
                // we can match with the result when we move
                // backwards down in the test. (hopefully ;-))
                NSString *gist_id = [[responseObject objectAtIndex:0] objectForKey:@"id"];
                
                // move to the next page
                [pagedResultSet next:^(id responseObject) {
                    // move backwards (aka. page 1)
                    [pagedResultSet previous:^(id responseObject) {
                        
                        NSString* ngist_id = [[responseObject objectAtIndex:0] objectForKey:@"id"];
                        
                        // id's should match
                        [[gist_id should] equal:ngist_id];
                     
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
            id <AGPipe> gists = [ghPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"gists"];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setPreviousIdentifier:@"prev"];
                    [pageConfig setParameterProvider:@{@"page" : @"1", @"per_page" : @"5"}];
                }];
            }];
            
            [gists readWithParams:nil success:^(id responseObject) {
                
                [[theValue([responseObject count]) should] equal:theValue(5)];
                
                // override the results per page from parameter provider
                [gists readWithParams:@{@"page" : @"1", @"per_page" : @"2"} success:^(id responseObject) {
                    
                   [[theValue([responseObject count]) should] equal:theValue(2)];
                    
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
            id <AGPipe> gists = [ghPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"gists"];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    // invalid setting:
                    [pageConfig setNextIdentifier:@"foo"];
                }];
            }];
            
            __block NSMutableArray *pagedResultSet;
            
            [gists readWithParams:@{@"page" : @"1", @"per_page" : @"5"} success:^(id responseObject) {
                
                pagedResultSet = responseObject;
                
                [pagedResultSet next:^(id responseObject) {
                    
                    // Note: succces is called here with default
                    // response of currently 30 elements. This is the default
                    // behaviour of github if invalid params are
                    // passed. Note this is not always the case as seen in
                    // the AGController test case.
                    // Github behaviour is an exception here.
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
        
        it(@"should fail with bogus previous identifier", ^{
            id <AGPipe> gists = [ghPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"gists"];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    // invalid setting:
                    [pageConfig setPreviousIdentifier:@"foo"];
                }];
            }];
            
            __block NSMutableArray *pagedResultSet;
            
            [gists readWithParams:@{@"page" : @"2", @"per_page" : @"5"} success:^(id responseObject) {
                
                pagedResultSet = responseObject;
                
                [pagedResultSet previous:^(id responseObject) {
                    
                    // Note: succces is called here with default
                    // response of currently 30 elements. This is the default
                    // behaviour of github if invalid params are
                    // passed. Note this is not always the case as seen in
                    // the AGController test case.
                    // Github behaviour is an exception here.
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
        
        it(@"should fail with bogus metadata location", ^{
            id <AGPipe> gists = [ghPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"gists"];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setPreviousIdentifier:@"prev"];
                    
                    // invalid setting:
                    [pageConfig setMetadataLocation:@"body"];
                }];
                
            }];
            
            __block NSMutableArray *pagedResultSet;
            
            [gists readWithParams:@{@"page" : @"1", @"per_page" : @"5"} success:^(id responseObject) {
                
                pagedResultSet = responseObject;
                
                [pagedResultSet next:^(id responseObject) {
                    finishedFlag = YES;
                    
                    // Note: succces is called here with default
                    // response of 30 elements. This is the default
                    // behaviour of github if invalid or no params are
                    // passed. Note this is not always the case as seen in
                    // the AGController test case.
                    // Github behaviour is an exception here.
                    
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
    });
});

SPEC_END