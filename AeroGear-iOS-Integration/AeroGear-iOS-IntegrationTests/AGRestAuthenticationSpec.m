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

static NSString *const PASSING_USERNAME = @"john";
static NSString *const FAILING_USERNAME = @"fail";

static NSString *const LOGIN_PASSWORD = @"123";
static NSString *const ENROLL_PASSWORD = @"123";


SPEC_BEGIN(AGRestAuthenticationSpec)

// helper method to extract the post id from the result set
NSString* (^generateUUID)() = ^() {
    CFUUIDRef UUID = CFUUIDCreate(NULL);
    NSString *UUIDString = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, UUID);
    CFRelease(UUID);
    
    return UUIDString;
};

describe(@"AGRestAuthentication", ^{
    context(@"when newly created", ^{
        
        __block id<AGAuthenticationModule> _authModule = nil;
        __block BOOL finishedFlag = NO;
        
        beforeAll(^{
            NSURL* projectsURL = [NSURL URLWithString:@"http://jaxrs-aerogear.rhcloud.com/aerogear-jaxrs-demo/rest/"];
            
            // create the authenticator
            AGAuthenticator* authenticator = [AGAuthenticator authenticator];
            _authModule = [authenticator auth:^(id<AGAuthConfig> config) {
                [config setName:@"myModule"];
                [config setBaseURL:projectsURL];
                [config setEnrollEndpoint:@"admin/create"];
            }];
        });
        
        afterEach(^{
            finishedFlag = NO;
        });
        
        it(@"should not be nil", ^{
            [(id)_authModule shouldNotBeNil];
        });
        
        it(@"should successfully login", ^{
            [_authModule login:@{@"loginName":PASSING_USERNAME, @"password":LOGIN_PASSWORD} success:^(id responseObject) {
                [[PASSING_USERNAME should] equal:[responseObject valueForKey:@"loginName"]];
                
                [_authModule logout:^{
                    finishedFlag = YES;
                } failure:^(NSError *error) {
                    fail(@"should have logout");
                    finishedFlag = YES;
                }];
                
            } failure:^(NSError *error) {
                fail(@"should have login");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should fail to login", ^{
            [_authModule login:@{@"username":FAILING_USERNAME, @"password":LOGIN_PASSWORD} success:^(id responseObject) {
                fail(@"should NOT have login");
                
                finishedFlag = YES;
            } failure:^(NSError *error) {
                finishedFlag = YES;
            }];
        });
        
        it(@"should fail to logout without login", ^{
            [_authModule logout:^{
                fail(@"should NOT have logout");
                finishedFlag = YES;
            } failure:^(NSError *error) {
                finishedFlag = YES;
            }];

            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        /*
        it(@"should successfully enroll", ^{
            // we need to login with admin privileges to perform 'enroll'
            [_authModule login:@{@"loginName":PASSING_USERNAME, @"password":LOGIN_PASSWORD} success:^(id responseObject) {

                // setup registration payload
                NSMutableDictionary* registerPayload = [NSMutableDictionary dictionary];
                
                // generate a 'unique' username otherwise server will throw
                // an error if we reuse an existing username
                NSString* username = generateUUID();
                
                [registerPayload setValue:@"John" forKey:@"firstname"];
                [registerPayload setValue:@"Doe" forKey:@"lastname"];
                [registerPayload setValue:@"emaadsil@mssssse.com" forKey:@"email"];
                [registerPayload setValue:username forKey:@"loginName"];
                [registerPayload setValue:LOGIN_PASSWORD forKey:@"password"];
                [registerPayload setValue:@"simple" forKey:@"role"];
                
                [_authModule enroll:registerPayload success:^(id responseObject) {
                    [[PASSING_USERNAME should] equal:[responseObject valueForKey:@"loginName"]];
                    
                    [_authModule logout:^{
                        finishedFlag = YES;
                    } failure:^(NSError *error) {
                        fail(@"should have logout");
                        finishedFlag = YES;
                    }];
                    
                } failure:^(NSError *error) {
                    fail(@"should have enroll");
                    finishedFlag = YES;
                }];
                
            } failure:^(NSError *error) {
                fail(@"should have login");
                finishedFlag = YES;                
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should fail to enroll", ^{
            // we need to login with admin privileges to perform 'enroll'
            [_authModule login:@{@"loginName":PASSING_USERNAME, @"password":LOGIN_PASSWORD} success:^(id responseObject) {
                
                // setup registration payload
                NSMutableDictionary* registerPayload = [NSMutableDictionary dictionary];
                
                // registration fields are missing (see testEnroll)
                [registerPayload setValue:@"Bogus" forKey:@"bogus"];
                
                [_authModule enroll:registerPayload success:^(id responseObject) {
                    fail(@"should NOT have enroll");
                    finishedFlag = YES;

                } failure:^(NSError *error) {
                    finishedFlag = YES;
                }];
                
            } failure:^(NSError *error) {
                fail(@"should have login");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];            
        });
         
         */
    });
});

SPEC_END