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

SPEC_BEGIN(AppNet_PipeTestsSpec)

describe(@"AppNet_PipeTests", ^{
    context(@"when newly created", ^{
        
        __block AGPipeline *appNetPipeline = nil;
        __block BOOL finishedFlag = NO;
        
        beforeEach(^{
            // setting up the pipeline for the WoW pipes:
            NSURL* baseURL = [NSURL URLWithString:@"https://alpha-api.app.net/stream/0/"];
            
            appNetPipeline = [AGPipeline pipelineWithBaseURL:baseURL];
        });
        
        afterEach(^{
            finishedFlag = NO;
        });
        
        it(@"should not be nil", ^{
            [appNetPipeline shouldNotBeNil];
        });
        
        it(@"should successfully read", ^{
            [appNetPipeline pipe:^(id<AGPipeConfig> config) {
                [config setName:@"globalStream"];
                [config setEndpoint: @"posts/stream/global"]; //endpoint with no trailing slash
                [config setType:@"REST"];
            }];
            
            id<AGPipe> statusPipe = [appNetPipeline pipeWithName:@"globalStream"];
            
            [statusPipe read:^(id responseObject) {
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