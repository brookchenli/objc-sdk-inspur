//
//  InspurUploadRequestState.h
//  InspurOSSSDK_Mac
//
//  Created by Brook on 2020/11/17.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadRequestState : NSObject

// old server 不验证tls sni
@property(nonatomic, assign)BOOL isUseOldServer;

// 用户是否取消
@property(nonatomic, assign)BOOL isUserCancel;

- (instancetype)copy;

@end

NS_ASSUME_NONNULL_END
