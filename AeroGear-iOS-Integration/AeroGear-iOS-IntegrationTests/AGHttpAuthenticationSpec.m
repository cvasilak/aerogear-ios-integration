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

static NSString *const PASSING_USERNAME = @"agnes";
static NSString *const FAILING_USERNAME = @"fail";

static NSString *const LOGIN_PASSWORD = @"123";

SPEC_BEGIN(AGHttpAuthenticationSpec)

describe(@"AGHttpAuthentication", ^{
    context(@"when newly created", ^{
        
        __block NSURL *_baseURL = nil;
        __block AGPipeline *_pipeline = nil;
        __block BOOL finishedFlag = NO;
        
        beforeEach(^{
            // the remote server is configured with 'HTTP Digest' authentication
            _baseURL = [NSURL URLWithString:@"http://controller-aerogear.rhcloud.com/aerogear-controller-demo"];
            
            // set up the pipeline
            _pipeline = [AGPipeline pipelineWithBaseURL:_baseURL];
        });
        
        afterEach(^{
            NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            NSArray *cookies = [cookieStorage cookiesForURL:_baseURL];
            for (NSHTTPCookie *cookie in cookies) {
                [cookieStorage deleteCookie:cookie];
            }
            
            finishedFlag = NO;
        });
        
        it(@"should successfully login", ^{
            id <AGPipe> pipe = [_pipeline pipe:^(id <AGPipeConfig> config) {
                [config setName:@"autobots"];
                // correct credentials
                [config setCredential:[NSURLCredential
                                       credentialWithUser:PASSING_USERNAME password:LOGIN_PASSWORD persistence:NSURLCredentialPersistenceNone]];
            }];
            
            [pipe read:^(id responseObject) {
                finishedFlag = YES;
 
            }  failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should fail to login with wrong credentials", ^{
            id <AGPipe> pipe = [_pipeline pipe:^(id <AGPipeConfig> config) {
                [config setName:@"autobots"];
                // wrong credentials
                [config setCredential:[NSURLCredential
                                       credentialWithUser:FAILING_USERNAME password:LOGIN_PASSWORD persistence:NSURLCredentialPersistenceNone]];
            }];
            
            [pipe read:^(id responseObject) {
                fail(@"should NOT have read");
                finishedFlag = YES;
                
            }  failure:^(NSError *error) {
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
    });
});

SPEC_END