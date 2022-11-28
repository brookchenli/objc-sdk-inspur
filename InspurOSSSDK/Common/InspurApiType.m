//
//  InspurApiType.m
//  InspurOSSSDK
//
//  Created by Brook on 2022/11/15.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import "InspurApiType.h"

@implementation InspurApiType

+ (NSString *)actionTypeString:(InspurActionType)actionType {
    NSString *type = @"";
    switch (actionType) {
        case InspurActionTypeUploadByForm:
            type = @"form";
            break;
        case InspurActionTypeUploadByResumeV1:
            type = @"resume-v1";
            break;
        case InspurActionTypeUploadByResumeV2:
            type = @"resume-v2";
            break;
        default:
            break;
    }
    return type;
}

+ (NSArray <NSString *> *)apisWithActionType:(InspurActionType)actionType {
    NSArray *apis = nil;
    switch (actionType) {
        case InspurActionTypeUploadByForm:
            apis = @[@"up.formupload"];
            break;
        case InspurActionTypeUploadByResumeV1:
            apis = @[@"up.mkblk", @"up.bput", @"up.mkfile"];
            break;
        case InspurActionTypeUploadByResumeV2:
            apis = @[@"up.initparts", @"up.uploadpart", @"up.completeparts"];
            break;
        default:
            break;
    }
    return apis;
}

@end
