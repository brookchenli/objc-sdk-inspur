//
//  InspurConcurrentResumeUpload.m
//  InspurOSSSDK
//
//  Created by WorkSpace_Sun on 2019/7/15.
//  Copyright © 2019 Inspur. All rights reserved.
//

#import "InspurLogUtil.h"
#import "InspurConcurrentResumeUpload.h"

@interface InspurConcurrentResumeUpload()

@property(nonatomic, strong) dispatch_group_t uploadGroup;
@property(nonatomic, strong) dispatch_queue_t uploadQueue;

@end

@implementation InspurConcurrentResumeUpload

- (int)prepareToUpload{
    self.uploadGroup = dispatch_group_create();
    self.uploadQueue = dispatch_queue_create("com.qiniu.concurrentUpload", DISPATCH_QUEUE_SERIAL);
    return [super prepareToUpload];
}

- (void)uploadRestData:(dispatch_block_t)completeHandler {
    InspurLogInfo(@"key:%@ 并发分片", self.key);
    
    for (int i = 0; i < self.config.concurrentTaskCount; i++) {
        dispatch_group_enter(self.uploadGroup);
        dispatch_group_async(self.uploadGroup, self.uploadQueue, ^{
            [super performUploadRestData:^{
                dispatch_group_leave(self.uploadGroup);
            }];
        });
    }
    dispatch_group_notify(self.uploadGroup, self.uploadQueue, ^{
        completeHandler();
    });
}

@end
