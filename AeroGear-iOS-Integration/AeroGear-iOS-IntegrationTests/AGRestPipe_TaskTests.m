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

@interface AGRestPipe_TaskTests : AGAbstractBaseTestClass
@end

@implementation AGRestPipe_TaskTests {
    id<AGAuthenticationModule> _authModule;
    id<AGPipe> _tasks;
}

//hack:
NSString* __createId;

-(void)setUp {
    [super setUp];
    
    // setting up authenticator, pipeline and the pipe for the projects:
    // basic setup, for every test
    
    NSURL* projectsURL = [NSURL URLWithString:@"http://localhost:8080/todo-server/"];
    
    // create the authenticator
    AGAuthenticator* authenticator = [AGAuthenticator authenticator];
    _authModule = [authenticator auth:^(id<AGAuthConfig> config) {
        [config setName:@"myModule"];
        [config setBaseURL:projectsURL];
    }];
    
    // set up the pipeline for the tasks
    AGPipeline* todo = [AGPipeline pipeline];
    [todo pipe:^(id<AGPipeConfig> config) {
        [config setName:@"tasks"];
        [config setBaseURL:projectsURL];
        [config setAuthModule:_authModule];
        [config setType:@"REST"];
        [config setRecordId:@"id"];
    }];
    
    // get access to the tasks pipe
    _tasks = [todo pipeWithName:@"tasks"];
}

-(void)tearDown {
    [super tearDown];
}

// CREATE
-(void)testCreateTask {
    
    // login....
    [_authModule login:@"john" password:@"123" success:^(id object) {
   
    // a new task object, structure looks like:
    // {
    //     date = "2012-11-26";
    //     description = "Desk Task 1";
    //     id = 5;
    //     tags = (
    //     );
    //     title = "Task 1";
    // }
    NSMutableDictionary* task = [NSMutableDictionary dictionary];
    [task setValue:@"2012-11-26" forKey:@"date"];
    [task setValue:@"created by a test-case" forKey:@"description"];
    [task setValue:@"itest task" forKey:@"title"];
    
    // save task
    [_tasks save:task success:^(id responseObject) {
        STAssertEqualObjects(@"itest task", [responseObject valueForKey:@"title"], @"did create task");

        // store the id for this newly created object        
        __createId = [[responseObject valueForKey:@"id"] stringValue];
        
        [self setFinishRunLoop:YES];
        
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

// READ
-(void)testReadTasks {
    // login....
    [_authModule login:@"john" password:@"123" success:^(id object) {
        
        // read all tasks
        [_tasks read:^(id responseObject) {
            NSLog(@"%@", responseObject);
            STAssertTrue(0 < [responseObject count], @"should NOT be empty...");
            
            [self setFinishRunLoop:YES];
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];
        
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testReadTasksWithTimeout {
    NSURL* projectsURL = [NSURL URLWithString:@"http://localhost:8080/todo-server/"];
    
    // set up the pipeline for the tasks
    AGPipeline* todo = [AGPipeline pipeline];
    [todo pipe:^(id<AGPipeConfig> config) {
        [config setName:@"tasks"];
        [config setBaseURL:projectsURL];
        [config setAuthModule:_authModule];
        [config setType:@"REST"];
        [config setRecordId:@"id"];
        [config setTimeoutInterval:1]; // set to a "really" low interval
    }];
    
    // get access to the tasks pipe
    id<AGPipe> tasks = [todo pipeWithName:@"tasks"];

    // login....
    [_authModule login:@"john" password:@"123" success:^(id object) {
        // read all tasks
        [tasks read:^(id responseObject) {
            STFail(@"%@", @"should NOT have been called");
            
            [self setFinishRunLoop:YES];
        } failure:^(NSError *error) {
            STAssertEquals(-1001, [error code], @"should be equal to code -1001 [request time out]");
            [self setFinishRunLoop:YES];
        }];
    
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testReadSingleTask {
    // login....
    [_authModule login:@"john" password:@"123" success:^(id object) {
        
        // save the updated project on server
        [_tasks read:__createId success:^(id responseObject) {
            STAssertEqualObjects(__createId,
                                 [[responseObject valueForKey:@"id"] stringValue], @"did read single project");
            
            [self setFinishRunLoop:YES];
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];
        
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
}

// UPDATE
-(void)testUpdateTask {
    // login....
    [_authModule login:@"john" password:@"123" success:^(id object) {

    // a new task object, structure looks like:
    // {
    //     date = "2012-11-26";
    //     description = "Desk Task 1";
    //     id = 5;
    //     tags = (
    //     );
    //     title = "Task 1";
    // }
    NSMutableDictionary* task = [NSMutableDictionary dictionary];
    [task setValue:@"1979-02-03" forKey:@"date"];
    [task setValue:@"updated by a test-case" forKey:@"description"];
    [task setValue:__createId forKey:@"id"];
    
    // save the updated task on server        
    [_tasks save:task success:^(id responseObject) {
        STAssertEqualObjects(__createId, [[responseObject valueForKey:@"id"] stringValue], @"did update task");

        [self setFinishRunLoop:YES];
        
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];

    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];

    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

// DELETE:
// awful name... but this needs to run after UPDATE...
-(void)test_DeleteTask {
    // login....
    [_authModule login:@"john" password:@"123" success:^(id object) {

    NSMutableDictionary* task = [NSMutableDictionary dictionary];
    [task setValue:__createId forKey:@"id"];
        
    // remove task
    [_tasks remove:task success:^(id responseObject) {

        // see if the read is empty now.....
        [_tasks read:^(id responseObject) {
            STAssertTrue(0 == [responseObject count], @"should be empty...");
            
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
    
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
        
}

@end