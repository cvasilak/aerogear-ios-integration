/*
 * JBoss, Home of Professional Open Source
 * Copyright Red Hat, Inc., and individual contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AGAbstractBaseTestClass.h"

@interface AGPagingWebLinking_GitHub : AGAbstractBaseTestClass
@end

@implementation AGPagingWebLinking_GitHub {
    AGPipeline* _ghPipeline;
    id<AGPipe> _gists;
}

-(void)setUp {
    [super setUp];
    
    // setting up the pipeline for the GitHub pipe
    NSURL* baseURL = [NSURL URLWithString:@"https://api.github.com/users/matzew/"];
    _ghPipeline = [AGPipeline pipelineWithBaseURL:baseURL];
    
    _gists = [_ghPipeline pipe:^(id<AGPipeConfig> config) {
        [config setName:@"gists"];
        
        [config setPageConfig:^(id<AGPageConfig> pageConfig) {
            [pageConfig setPreviousIdentifier:@"prev"]; // github uses different than the AG ctrl
            [pageConfig setParameterProvider:@{@"page" : @"1", @"per_page" : @"5"}];
        }];
    }];
}

-(void)tearDown {
    [super tearDown];
}

-(void)testNext {
    __block NSMutableArray *pagedResultSet;
    
    // fetch the first page
    [_gists readWithParams:@{@"page" : @"1", @"per_page" : @"1"} success:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // hold the "id" from the first page, so that
        // we can match with the result when we move
        // to the next page down in the test. (hopefully ;-))
        NSString* gist_id = [self extractGistId:responseObject];

        // move to the next page
        [pagedResultSet next:^(id responseObject) {
            
            STAssertFalse([gist_id isEqualToString:[self extractGistId:responseObject]], @"id's should not match.");
            
            [self setFinishRunLoop:YES];
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testPreviousFromFirstPage {
    __block NSMutableArray *pagedResultSet;
    
    // fetch the first page
    [_gists readWithParams:@{@"page" : @"1", @"per_page" : @"1"} success:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // move back from the first page
        [pagedResultSet previous:^(id responseObject) {
            
            // Note: although success is called
            // and we ask a non existing page
            // (prev identifier was missing from the response)
            // github responded with a list of results.
            
            // Some apis such as github respond even on the
            // invalid page but others may throw an error
            // (see Twitter and AGController case).
            
            [self setFinishRunLoop:YES];
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testMoveNextAndPrevious {
    __block NSMutableArray *pagedResultSet;
    
    // fetch the first page
    [_gists readWithParams:@{@"page" : @"0", @"per_page" : @"1"} success:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // hold the "id" from the first page, so that
        // we can match with the result when we move
        // backwards down in the test. (hopefully ;-))
        NSString* gist_id = [self extractGistId:responseObject];
        
        // move to the second page
        [pagedResultSet next:^(id responseObject) {
            
            // move backwards (aka. page 1)
            [pagedResultSet previous:^(id responseObject) {
                
                STAssertEqualObjects(gist_id, [self extractGistId:responseObject], @"id's must match.");
                
                [self setFinishRunLoop:YES];
            } failure:^(NSError *error) {
                [self setFinishRunLoop:YES];
                STFail(@"%@", error);
            }];
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testParameterProvider {
    id <AGPipe> gists = [_ghPipeline pipe:^(id<AGPipeConfig> config) {
        [config setName:@"gists"];
        
        [config setPageConfig:^(id<AGPageConfig> pageConfig) {
            [pageConfig setPreviousIdentifier:@"prev"];
            [pageConfig setParameterProvider:@{@"page" : @"1", @"per_page" : @"5"}];
        }];
    }];
    
    [gists readWithParams:nil success:^(id responseObject) {

        STAssertTrue([responseObject count] == 5, @"should be five");
        
        // override the results per page from parameter provider
        [gists readWithParams:@{@"page" : @"1", @"per_page" : @"2"} success:^(id responseObject) {
            
            STAssertTrue([responseObject count] == 2, @"size should be two");
            
            [self setFinishRunLoop:YES];
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];

    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testBogusNextIdentifier {
    id <AGPipe> gists = [_ghPipeline pipe:^(id<AGPipeConfig> config) {
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
            // the Twitter/AGController test case.
            // Github behaviour is an exception here.
            [self setFinishRunLoop:YES];
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
        }];
        
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testBogusPreviousIdentifier {
    id <AGPipe> gists = [_ghPipeline pipe:^(id<AGPipeConfig> config) {
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
            // the Twitter/AGController test case.
            // Github behaviour is an exception here.
            [self setFinishRunLoop:YES];
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
        }];
        
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testBogusMetadataLocation {
    id <AGPipe> gists = [_ghPipeline pipe:^(id<AGPipeConfig> config) {
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
            [self setFinishRunLoop:YES];
            
            // Note: succces is called here with default
            // response of 30 elements. This is the default
            // behaviour of github if invalid or no params are
            // passed. Note this is not always the case as seen in
            // the Twitter/AGController test case.
            // Github behaviour is an exception here.
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
        }];
        
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

// helper method to extract the "id" from the result set
-(NSString*)extractGistId:(NSArray*) responseObject {
    return [[responseObject objectAtIndex:0] objectForKey:@"id"];
}
@end

