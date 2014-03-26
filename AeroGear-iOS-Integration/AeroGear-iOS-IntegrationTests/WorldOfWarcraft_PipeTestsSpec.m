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

SPEC_BEGIN(WorldOfWarcraft_PipeTestsSpec)

describe(@"WorldOfWarcraft_PipeTests", ^{
    context(@"when newly created", ^{
        
        __block AGPipeline* wowPipeline = nil;
        __block BOOL finishedFlag = NO;
        
        beforeEach(^{
            // setting up the pipeline for the WoW pipes:
            NSURL *baseURL = [NSURL URLWithString:@"http://us.battle.net/api/wow"];
            
            wowPipeline = [AGPipeline pipelineWithBaseURL:baseURL];
        });
        
        afterEach(^{
            finishedFlag = NO;
        });
        
        it(@"should not be nil", ^{
            [wowPipeline shouldNotBeNil];
        });
        
        it(@"should successfully retrieve WoW status", ^{
            [wowPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"status"];
                [config setEndpoint: @"realm/status"]; //endpoint with no trailing slash
                [config setType:@"REST"];
            }];
            
            id<AGPipe> wowStatusPipe = [wowPipeline pipeWithName:@"status"];
            
            [wowStatusPipe read:^(id responseObject) {
                finishedFlag = YES;
                
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should successfully retrieve WoW race", ^{
            [wowPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"races"];
                [config setEndpoint: @"data/character/races"]; //endpoint with no trailing slash
                [config setType:@"REST"];
            }];
            
            id<AGPipe> wowStatusPipe = [wowPipeline pipeWithName:@"races"];
            
            [wowStatusPipe read:^(id responseObject) {
                finishedFlag = YES;

            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
        
        it(@"should successfully retrieve WoW recipe", ^{
            [wowPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"recipe33994"];
                [config setEndpoint: @"recipe/33994"]; //endpoint with no trailing slash
                [config setType:@"REST"];
            }];
            
            id<AGPipe> wowStatusPipe = [wowPipeline pipeWithName:@"recipe33994"];
            
            [wowStatusPipe read:^(id responseObject) {
                finishedFlag = YES;
          
            } failure:^(NSError *error) {
                fail(@"should have read");
                finishedFlag = YES;
            }];
            
            [[expectFutureValue(theValue(finishedFlag)) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
        });
    });
});

SPEC_END