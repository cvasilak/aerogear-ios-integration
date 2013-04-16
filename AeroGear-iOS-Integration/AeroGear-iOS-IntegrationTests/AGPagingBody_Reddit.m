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

#import "AGAuthenticationModule.h"
#import "AGHttpClient.h"

/*
 * custom AGAuthenticationModule for Reddit
 */
@interface AGRedditAuthenticationModule : NSObject <AGAuthenticationModule>
@end

@implementation AGRedditAuthenticationModule {
    // ivars
    AGHttpClient* _restClient;
    
    NSMutableDictionary *_authHeaderParams;
}

@synthesize type = _type;
@synthesize baseURL = _baseURL;
@synthesize loginEndpoint = _loginEndpoint;
@synthesize logoutEndpoint = _logoutEndpoint;
@synthesize enrollEndpoint = _enrollEndpoint;

-(id)init {
    self = [super init];
    if (self) {
        _type = @"REDDIT";
        _baseURL = @"http://www.reddit.com";
        _loginEndpoint = @"/api/login";
        _logoutEndpoint = @"/api/logout";
        
        _restClient = [AGHttpClient clientFor:[NSURL URLWithString:_baseURL]];
        _restClient.parameterEncoding = AFFormURLParameterEncoding;
    }
    
    return self;
}

-(NSString*) loginEndpoint {
    return [_baseURL stringByAppendingString:_loginEndpoint];
}

-(NSString*) logoutEndpoint {
    return [_baseURL stringByAppendingString:_logoutEndpoint];
}

-(NSString*) enrollEndpoint {
    return [_baseURL stringByAppendingString:_enrollEndpoint];
}

-(void) enroll:(id) userData
       success:(void (^)(id object))success
       failure:(void (^)(NSError *error))failure {
    
}

-(void) login:(NSString*) username
     password:(NSString*) password
      success:(void (^)(id object))success
      failure:(void (^)(NSError *error))failure {

    //NSString* loginURL = [NSString stringWithFormat:@"%@/%@", _loginEndpoint, username];
    NSString* loginURL = [NSString stringWithFormat:@"%@", _loginEndpoint];
    
    [_restClient setDefaultHeader:@"User-Agent" value:[@"AeroGear iOS /u/" stringByAppendingString:username]];

    NSDictionary* loginData = [NSDictionary
                                dictionaryWithObjectsAndKeys:@"json", @"api_type",
                                                            username, @"user",
                                                            password, @"passwd", nil];

    [_restClient postPath:loginURL parameters:loginData success:^(AFHTTPRequestOperation *operation, id responseObject) {

        _authHeaderParams = [[NSMutableDictionary alloc] init];
        
        NSDictionary* data = [[responseObject objectForKey:@"json"] objectForKey:@"data"];
        
        NSString* authToken = [data objectForKey:@"cookie"];
        NSString* modhash = [data objectForKey:@"modhash"];
        
        [_authHeaderParams setObject:[@"reddit_session=" stringByAppendingString:authToken] forKey:@"Cookie"];
        [_authHeaderParams setObject:modhash forKey:@"modhash"];
        
        if (success) {
            success(responseObject);
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        if (failure) {
            failure(error);
        }
    }];
}

-(void) logout:(void (^)())success
       failure:(void (^)(NSError *error))failure {
    // throw exception
}

-(BOOL)isAuthenticated {
    return (nil != _authHeaderParams);
}

-(void) cancel {
    // cancel all running http operations
    [_restClient.operationQueue cancelAllOperations];
}

-(NSDictionary*)authHeaderParams {
    return [_authHeaderParams copy];
}

-(NSDictionary*)authQueryParams {
    return nil;
}

@end

// Custom AGPageParameterExtractor for Reddit
@interface RedditPageParameterExtractor : NSObject<AGPageParameterExtractor>
@end

@implementation RedditPageParameterExtractor

- (NSDictionary*) parse:(id)response
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
                         [NSNumber numberWithInt:25], @"count", nil] forKey:@"AG-next-key"];
    }
    
    // extract "previous page" identifier
    element = [response copy];
    NSArray* prevIdentifiers = [prevIdentifier componentsSeparatedByString:@"."];
    for (NSString* identifier in prevIdentifiers) {
        element = [element objectForKey:identifier];
    }
    
    if (element && ![element isKindOfClass:[NSNull class]]) {
        [mapOfLink setObject:[NSDictionary dictionaryWithObjectsAndKeys:element, @"before",
                          [NSNumber numberWithInt:25], @"count", nil] forKey:@"AG-prev-key"];
    }

    return mapOfLink;
}

@end

@interface AGPagingBody_Reddit : AGAbstractBaseTestClass
@end

@implementation AGPagingBody_Reddit {
    AGPipeline* _rdtPipeline;
    id<AGPipe> _rdt;
    
    id<AGAuthenticationModule> _rdtAuth;
}

-(void)setUp {
    [super setUp];
    
    // setting up the pipeline for the Reddit pipe
    NSURL* baseURL = [NSURL URLWithString:@"http://www.reddit.com"];

    _rdtAuth = [[AGRedditAuthenticationModule alloc] init];
    
    [_rdtAuth login:@"aerogear" password:@"123456" success:^(id object) {

        _rdtPipeline = [AGPipeline pipelineWithBaseURL:baseURL];
        
        _rdt = [_rdtPipeline pipe:^(id<AGPipeConfig> config) {
            [config setAuthModule:_rdtAuth];
            [config setName:@".json"];
            
            [config setLimit:[NSNumber numberWithInt:25]];
            [config setNextIdentifier:@"data.after"];
            [config setPreviousIdentifier:@"data.before"];
            [config setPageExtractor:[[RedditPageParameterExtractor alloc] init]];
        }];
        
        [self setFinishRunLoop:YES];
        
    } failure:^(NSError *error) {
        //
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
   [self setFinishRunLoop:NO];

}

-(void)tearDown {
    [super tearDown];
}

-(void)testNext {
  __block NSMutableArray *pagedResultSet;
    
    // fetch the first page
    [_rdt read:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // hold the "post id" from the first page, so that
        // we can match with the result when we move
        // to the next page down in the test. (hopefully ;-))
        NSString* post_id = [self extractPostId:responseObject];
        
        // move to the next page
        [pagedResultSet next:^(id responseObject) {
            
            STAssertFalse([post_id isEqualToString:[self extractPostId:responseObject]], @"id's should not match.");
            
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
    [_rdt read:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // move back to an invalid page
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
    [_rdt read:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // hold the "post id" from the first page, so that
        // we can match with the result when we move
        // to the next page down in the test. (hopefully ;-))
        NSString* post_id = [self extractPostId:responseObject];
        
        // move to the next page
        [pagedResultSet next:^(id responseObject) {
            
            // move backwards (aka. page 1)
            [pagedResultSet previous:^(id responseObject) {
                
                STAssertEqualObjects(post_id, [self extractPostId:responseObject], @"id's must match.");
                
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
    
    NSLog(@"end");
}

-(void)testParameterProvider {
    id<AGPipe> rdt = [_rdtPipeline pipe:^(id<AGPipeConfig> config) {
        [config setName:@".json"];
        [config setAuthModule:_rdtAuth];
        
        [config setParameterProvider:@{@"count" : @"25"}];
        [config setNextIdentifier:@"data.after"];
        [config setPreviousIdentifier:@"data.before"];
        [config setPageExtractor:[[RedditPageParameterExtractor alloc] init]];
    }];
    
    // giving nil, should use the global (see above)
    [rdt readWithParams:nil success:^(id responseObject) {
        
        NSArray* results = [[[responseObject objectAtIndex:0] objectForKey:@"data"] objectForKey:@"children"];
        
        STAssertTrue([results count] == 25, @"size should be 25");
        
        [self setFinishRunLoop:YES];
        /* TODO test count why is not honoured??
        // override the results per page from parameter provider
        [rdt readWithParams:@{@"count" : @"20"} success:^(id responseObject) {
            
            NSArray* results = [[[responseObject objectAtIndex:0] objectForKey:@"data"] objectForKey:@"children"];
            
            STAssertTrue([results count] == 10, @"size should be 10");
            
            [self setFinishRunLoop:YES];
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];
        */
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
    id<AGPipe> rdt = [_rdtPipeline pipe:^(id<AGPipeConfig> config) {
        [config setName:@".json"];
        [config setAuthModule:_rdtAuth];
        
        [config setParameterProvider:@{@"count" : @"25"}];
        // bogus identifier
        [config setNextIdentifier:@"foo"];
        [config setPreviousIdentifier:@"data.before"];
        [config setPageExtractor:[[RedditPageParameterExtractor alloc] init]];
    }];
    
    __block NSMutableArray *pagedResultSet;
    
    [rdt read:^(id responseObject) {
        
        pagedResultSet = responseObject;
        
        [pagedResultSet next:^(id responseObject) {
            
            // Note: succces is called here with default
            // response of currently 25 elements. This is the default
            // behaviour of reddit if invalid params are
            // passed. Note this is not always the case as seen in
            // the Twitter/AGController test case.
            // Reddit behaviour is an exception here.
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
    id<AGPipe> rdt = [_rdtPipeline pipe:^(id<AGPipeConfig> config) {
        [config setName:@".json"];
        [config setAuthModule:_rdtAuth];
        
        [config setParameterProvider:@{@"count" : @"25"}];
        [config setNextIdentifier:@"data.after"];
        // bogus identifier
        [config setPreviousIdentifier:@"foo"];
        [config setPageExtractor:[[RedditPageParameterExtractor alloc] init]];
    }];
    
    __block NSMutableArray *pagedResultSet;
    
    [rdt read:^(id responseObject) {
        
        pagedResultSet = responseObject;
        
        [pagedResultSet previous:^(id responseObject) {
            
            // Note: succces is called here with default
            // response of currently 25 elements. This is the default
            // behaviour of reddit if invalid params are
            // passed. Note this is not always the case as seen in
            // the Twitter/AGController test case.
            // Reddit behaviour is an exception here.
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

// helper method to extract the post id from the result set
-(NSString*)extractPostId:(NSArray*) responseObject {
    NSArray* results = [[[responseObject objectAtIndex:0] objectForKey:@"data"] objectForKey:@"children"];
    
    return [[[results objectAtIndex:0] objectForKey:@"data"] objectForKey:@"id"];
}

@end