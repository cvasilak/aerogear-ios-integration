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

#import "AGAuthenticationModuleAdapter.h"
#import "AGHttpClient.h"

//----------------------------------------------------------------------------

/*
 * A custom Authentication Module that goes against Reddit service.
 *
 */
@interface AGRedditAuthenticationModule : NSObject <AGAuthenticationModuleAdapter>
@end

@implementation AGRedditAuthenticationModule {
    // as all other custom auth modules, (eg. AGRestAuthentication) we
    // internally use the AGHttpClient to perform http communication. This
    // allows us to have full access to the underlying http setup.
    // (e.g. setting custom headers etc.)
    AGHttpClient* _restClient;
}

@synthesize type = _type;
@synthesize baseURL = _baseURL;
@synthesize loginEndpoint = _loginEndpoint;
@synthesize logoutEndpoint = _logoutEndpoint;
@synthesize enrollEndpoint = _enrollEndpoint;

@synthesize authTokens = _authTokens;

- (id)init {
    self = [super init];
    if (self) {
        _type = @"REDDIT";
        _baseURL = @"http://www.reddit.com";
        _loginEndpoint = @"/api/login";
        _logoutEndpoint = @"/api/logout";
        
        _restClient = [AGHttpClient clientFor:[NSURL URLWithString:_baseURL]];
        // default to url serialization
        _restClient.requestSerializer = [AFHTTPRequestSerializer serializer];
    }
    
    return self;
}

- (NSString *)loginEndpoint {
    return [_baseURL stringByAppendingString:_loginEndpoint];
}

- (NSString *)logoutEndpoint {
    return [_baseURL stringByAppendingString:_logoutEndpoint];
}

- (NSString *)enrollEndpoint {
    return [_baseURL stringByAppendingString:_enrollEndpoint];
}

- (void)enroll:(id) userData
       success:(void (^)(id object))success
       failure:(void (^)(NSError *error))failure {
    
    @throw [NSException exceptionWithName:@"InvalidMessage"
                                   reason:@"enroll not applicable."
                                 userInfo:nil];
}

- (void)login:(NSString*) username
     password:(NSString*) password
      success:(void (^)(id object))success
      failure:(void (^)(NSError *error))failure DEPRECATED_ATTRIBUTE {
    
    [self login:@{@"user": username, @"passwd": password} success:success failure:failure];
}

- (void)login:(NSDictionary*) loginData
      success:(void (^)(id object))success
      failure:(void (^)(NSError *error))failure {
    
    NSString* loginURL = [NSString stringWithFormat:@"%@", _loginEndpoint];
    
    [_restClient.requestSerializer setValue:[@"AeroGear iOS /u/" stringByAppendingString:loginData[@"user"]] forHTTPHeaderField:@"User-Agent"];
    
    NSDictionary* postData = @{@"api_type": @"json",
                               @"user": loginData[@"user"],
                               @"passwd": loginData[@"passwd"]};
    
    [_restClient POST:loginURL parameters:postData success:^(NSURLSessionDataTask *task, id responseObject) {
        
        // stash the auth token...:
        [self readAndStashToken:responseObject];
        
        if (success) {
            success(responseObject);
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        
        if (failure) {
            failure(error);
        }
    }];
}

- (void)logout:(void (^)())success
       failure:(void (^)(NSError *error))failure {
    
    @throw [NSException exceptionWithName:@"InvalidMessage"
                                   reason:@"logout not applicable."
                                 userInfo:nil];
}

- (void)cancel {
    // cancel all running http operations
    [_restClient.operationQueue cancelAllOperations];
}

// private method
- (void)readAndStashToken:(id) responseObject {
    _authTokens = [[NSMutableDictionary alloc] init];
    
    NSDictionary* data = [[responseObject objectForKey:@"json"] objectForKey:@"data"];
    
    // extract reddit authentication headers
    NSString* authToken = [data objectForKey:@"cookie"];
    NSString* modhash = [data objectForKey:@"modhash"];
    
    [_authTokens setObject:[@"reddit_session=" stringByAppendingString:authToken] forKey:@"Cookie"];
    [_authTokens setObject:modhash forKey:@"modhash"];
}

- (BOOL)isAuthenticated {
    return (nil != _authTokens);
}

- (void)deauthorize {
    _authTokens = nil;
}

@end

// Custom AGPageParameterExtractor for Reddit
@interface RedditPageParameterExtractor : NSObject<AGPageParameterExtractor>
@end

@implementation RedditPageParameterExtractor


- (NSDictionary *)parse:(id)response
                headers:(NSDictionary*)headers
                   next:(NSString*)nextIdentifier
                   prev:(NSString*)prevIdentifier {
    
    
    id element;
    
    NSMutableDictionary *mapOfLink = [NSMutableDictionary dictionary];
    
    // extract "next page" identifier
    element = [response copy];
    NSArray* nextIdentifiers = [nextIdentifier componentsSeparatedByString:@"."];
    for (NSString* identifier in nextIdentifiers) {
        element = [element objectForKey:identifier];
    }
    
    if (element && ![element isKindOfClass:[NSNull class]]) {
        [mapOfLink setObject:[NSDictionary dictionaryWithObjectsAndKeys:element, @"after",
                              [NSNumber numberWithInt:25], @"limit", nil] forKey:@"AG-next-key"];
    }
    
    // extract "previous page" identifier
    element = [response copy];
    NSArray* prevIdentifiers = [prevIdentifier componentsSeparatedByString:@"."];
    for (NSString* identifier in prevIdentifiers) {
        element = [element objectForKey:identifier];
    }
    
    if (element && ![element isKindOfClass:[NSNull class]]) {
        [mapOfLink setObject:[NSDictionary dictionaryWithObjectsAndKeys:element, @"before",
                              [NSNumber numberWithInt:25], @"limit", nil] forKey:@"AG-prev-key"];
    }
    
    return mapOfLink;
}

@end
//----------------------------------------------------------------------------

SPEC_BEGIN(AGPagingBody_RedditSpec)

// helper method to extract the post id from the result set
NSString* (^extractPostId) (NSArray *) = ^(NSArray *responseObject) {
    NSArray* results = [[[responseObject objectAtIndex:0] objectForKey:@"data"] objectForKey:@"children"];
    
    return [[[results objectAtIndex:0] objectForKey:@"data"] objectForKey:@"id"];
};

describe(@"AGPagingBody_Reddit", ^{
    context(@"when newly created", ^{
        
        __block AGPipeline* rdtPipeline;
        __block  id<AGPipe> rdt;
        
        __block id<AGAuthenticationModule> rdtAuth;
        __block BOOL finishedFlag = NO;

        beforeAll(^{
            // setting up the pipeline for the Reddit pipe
            NSURL* baseURL = [NSURL URLWithString:@"http://www.reddit.com"];
            
            rdtAuth = [[AGRedditAuthenticationModule alloc] init];
            
            // login to reddit
            [rdtAuth login:@{@"user": @"aerogear", @"passwd": @"123456"} success:^(id object) {
                
                rdtPipeline = [AGPipeline pipelineWithBaseURL:baseURL];
                
                rdt = [rdtPipeline pipe:^(id<AGPipeConfig> config) {
                    [config setAuthModule:rdtAuth];
                    [config setName:@".json"];
                    
                    [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                        [pageConfig setLimit:[NSNumber numberWithInt:25]];
                        [pageConfig setNextIdentifier:@"data.after"];
                        [pageConfig setPreviousIdentifier:@"data.before"];
                        [pageConfig setPageExtractor:[[RedditPageParameterExtractor alloc] init]];
                    }];
                    
                }];
                
                finishedFlag = YES;
                
            } failure:^(NSError *error) {
                fail(@"should have login");
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(4.0)] beYes];            
        });
        
        afterEach(^{
            finishedFlag = NO;
        });
        
        it(@"should successfully move to the next page", ^{
            __block NSMutableArray *pagedResultSet;
            
            // fetch the first page
            [rdt read:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // hold the "post id" from the first page, so that
                // we can match with the result when we move
                // to the next page down in the test. (hopefully ;-))
                NSString* post_id = extractPostId(responseObject);
                
                // move to the next page
                [pagedResultSet next:^(id responseObject) {
                    NSString* npost_id = extractPostId(responseObject);
                    
                    // id's should not match
                    [[post_id shouldNot] equal:npost_id];

                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    fail(@"should have read");
                    finishedFlag = YES;
                }];                
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(4.0)] beYes];
        });
        
        it(@"should successfully move back from the first page", ^{
            __block NSMutableArray *pagedResultSet;
            
            // fetch the first page
            [rdt read:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // move back to an invalid page
                [pagedResultSet previous:^(id responseObject) {
                    // Note: although success is called
                    // and we ask a non existing page
                    // (prev identifier was missing from the response)
                    // reddit responded with a list of results.
                    
                    // Some apis such as github respond even on the
                    // invalid page but others may throw an error
                    // (see AGController case).
                    
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    fail(@"should have read");
                    finishedFlag = YES;
                }];
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(4.0)] beYes];
        });
        
        it(@"should successfully move next and back", ^{
            __block NSMutableArray *pagedResultSet;
            
            // fetch the first page
            [rdt read:^(id responseObject) {
                pagedResultSet = responseObject;  // page 1
                
                // hold the "post id" from the first page, so that
                // we can match with the result when we move
                // to the next page down in the test. (hopefully ;-))
                NSString* post_id = extractPostId(responseObject);
                
                // move to the next page
                [pagedResultSet next:^(id responseObject) {
                    
                    // move backwards (aka. page 1)
                    [pagedResultSet previous:^(id responseObject) {
                        
                        NSString* npost_id = extractPostId(responseObject);
                        
                        // id's should match
                        [[post_id should] equal:npost_id];

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
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(4.0)] beYes];
        });
        
        it(@"should respect parameter provider settings", ^{
            id<AGPipe> rdt = [rdtPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@".json"];
                [config setAuthModule:rdtAuth];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setParameterProvider:@{@"limit" : @"10"}];
                    [pageConfig setNextIdentifier:@"data.after"];
                    [pageConfig setPreviousIdentifier:@"data.before"];
                    [pageConfig setPageExtractor:[[RedditPageParameterExtractor alloc] init]];
                }];
            }];
            
            // giving nil, should use the global (see above)
            [rdt readWithParams:nil success:^(id responseObject) {
                
                NSArray* results = [[[responseObject objectAtIndex:0] objectForKey:@"data"] objectForKey:@"children"];
                
                [[theValue([results count]) should] equal:theValue(10)];
                
                finishedFlag = YES;
                
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(4.0)] beYes];
        });
        
        it(@"should fail with bogus next identifier", ^{
            id<AGPipe> rdt = [rdtPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@".json"];
                [config setAuthModule:rdtAuth];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setParameterProvider:@{@"limit" : @"25"}];
                    // bogus identifier
                    [pageConfig setNextIdentifier:@"foo"];
                    [pageConfig setPreviousIdentifier:@"data.before"];
                    [pageConfig setPageExtractor:[[RedditPageParameterExtractor alloc] init]];
                }];
            }];
            
            __block NSMutableArray *pagedResultSet;
            
            [rdt read:^(id responseObject) {
                
                pagedResultSet = responseObject;
                
                [pagedResultSet next:^(id responseObject) {
                    
                    // Note: succces is called here with default
                    // response of currently 25 elements. This is the default
                    // behaviour of reddit if invalid params are
                    // passed. Note this is not always the case as seen in
                    // the AGController test case.
                    // Reddit behaviour is an exception here.
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    fail(@"should have read");
                    finishedFlag = YES;
                }];
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(4.0)] beYes];
        });

        it(@"should fail with bogus previous identifier", ^{
            id<AGPipe> rdt = [rdtPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@".json"];
                [config setAuthModule:rdtAuth];
                
                [config setPageConfig:^(id<AGPageConfig> pageConfig) {
                    [pageConfig setParameterProvider:@{@"limit" : @"25"}];
                    [pageConfig setNextIdentifier:@"data.after"];
                    // bogus identifier
                    [pageConfig setPreviousIdentifier:@"foo"];
                    [pageConfig setPageExtractor:[[RedditPageParameterExtractor alloc] init]];
                }];
            }];
            
            __block NSMutableArray *pagedResultSet;
            
            [rdt read:^(id responseObject) {
                
                pagedResultSet = responseObject;
                
                [pagedResultSet previous:^(id responseObject) {
                    
                    // Note: succces is called here with default
                    // response of currently 25 elements. This is the default
                    // behaviour of reddit if invalid params are
                    // passed. Note this is not always the case as seen in
                    // the AGController test case.
                    // Reddit behaviour is an exception here.
                    finishedFlag = YES;
                    
                } failure:^(NSError *error) {
                    fail(@"should have read");
                    finishedFlag = YES;
                }];
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(4.0)] beYes];
        });
    });
});

SPEC_END