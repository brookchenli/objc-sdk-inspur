//
//  InspurApiType.h
//  InspurOSSSDK
//
//  Created by Brook on 2022/11/15.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, InspurActionType) {
    InspurActionTypeNone,
    InspurActionTypeUploadByForm,
    InspurActionTypeUploadByResumeV1,
    InspurActionTypeUploadByResumeV2,
};

@interface InspurApiType : NSObject

+ (NSString *)actionTypeString:(InspurActionType)actionType;

+ (NSArray <NSString *> *)apisWithActionType:(InspurActionType)actionType;

@end

NS_ASSUME_NONNULL_END
