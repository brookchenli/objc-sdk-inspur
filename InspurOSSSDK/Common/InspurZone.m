//
//  InspurZone.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/16.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurZone.h"
#import "InspurUpToken.h"
#import "InspurZoneInfo.h"

@implementation InspurZone

- (InspurZonesInfo *)getZonesInfoWithToken:(InspurUpToken *)token {
    return [self getZonesInfoWithToken:token actionType:InspurActionTypeNone];
}

- (InspurZonesInfo *)getZonesInfoWithToken:(InspurUpToken * _Nullable)token
                            actionType:(InspurActionType)actionType {
    return nil;
}

- (void)preQuery:(InspurUpToken *)token
              on:(InspurPrequeryReturn)ret {
    [self preQuery:token actionType:InspurActionTypeNone on:ret];
}

- (void)preQuery:(InspurUpToken *)token
      actionType:(InspurActionType)actionType
              on:(InspurPrequeryReturn)ret {
    ret(0, nil, nil);
}

@end
