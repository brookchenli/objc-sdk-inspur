//
//  QNUploadRequestState.m
//  QiniuSDK_Mac
//
//  Created by yangsen on 2020/11/17.
//  Copyright © 2020 Qiniu. All rights reserved.
//

#import "InspurIUploadServer.h"
#import "InspurUploadRequestState.h"

@implementation InspurUploadRequestState
- (instancetype)init{
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData{
    _isUserCancel = NO;
    _isUseOldServer = NO;
}

- (instancetype)copy {
    InspurUploadRequestState *state = [[InspurUploadRequestState alloc] init];
    state.isUserCancel = self.isUserCancel;
    state.isUseOldServer = self.isUseOldServer;
    return state;
}

@end
