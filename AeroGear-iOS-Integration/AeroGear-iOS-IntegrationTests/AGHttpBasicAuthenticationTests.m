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

#import "AGAbstractBaseTestClass.h"

static NSString *const PASSING_USERNAME = @"john";
static NSString *const FAILING_USERNAME = @"fail";

static NSString *const LOGIN_PASSWORD = @"123";
static NSString *const ENROLL_PASSWORD = @"123";

@interface AGHttpBasicAuthenticationTests : AGAbstractBaseTestClass

@end

@implementation AGHttpBasicAuthenticationTests {
    id<AGAuthenticationModule> _authModule;

    id<AGPipe> _pipe;
}

-(void)setUp {
    [super setUp];
    
    // setting up authenticator
    NSURL*baseURL = [NSURL URLWithString:@"http://localhost:8080/aerogear-controller-demo/"];
    
    // create the authenticator
    AGAuthenticator* authenticator = [AGAuthenticator authenticator];
    _authModule = [authenticator auth:^(id<AGAuthConfig> config) {
        [config setName:@"myModule"];
        [config setBaseURL:baseURL];
        [config setType:@"Basic"];
        [config setRealm:@"PicketLink Default Realm"];
    }];

    // set up the pipeline and assign the authenticator
    AGPipeline* pipeline = [AGPipeline pipelineWithBaseURL:baseURL];
    [pipeline pipe:^(id<AGPipeConfig> config) {
        [config setName:@"autobots"];
        [config setBaseURL:baseURL];
        [config setAuthModule:_authModule];
    }];

    // get access to the projects pipe
    _pipe = [pipeline pipeWithName:@"autobots"];
}

-(void)tearDown {
    [super tearDown];
}

-(void)testHttpBasicAuthenticationCreation {
    STAssertNotNil(_authModule, @"module should not be nil");
}

-(void)testLoginSuccess {
    [_authModule login:PASSING_USERNAME password:LOGIN_PASSWORD success:^(id responseObject) {

        [_pipe read:^(id responseObject) {

            [_authModule logout:^{
                [self setFinishRunLoop:YES];
            } failure:^(NSError *error) {
                [self setFinishRunLoop:YES];
                STFail(@"should have logout", error);
            }];

        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"should have read", error);
        }];


    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"should have login", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testLoginFails {
    [_authModule login:FAILING_USERNAME password:LOGIN_PASSWORD success:^(id responseObject) {

        [_pipe read:^(id responseObject) {
            [self setFinishRunLoop:YES];
            STFail(@"should NOT have been called");

        } failure:^(NSError *error) {
            [_authModule logout:^{
                [self setFinishRunLoop:YES];
            } failure:^(NSError *error) {
                [self setFinishRunLoop:YES];
                STFail(@"should have logout", error);
            }];
        }];

    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"should NOT have been called");
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

@end
