//
//  QNUploadServerFreezeManager.m
//  QiniuSDK
//
//  Created by Brook on 2020/6/2.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurConfiguration.h"
#import "InspurUploadServerFreezeManager.h"

@interface InspurUploadServerFreezeItem : NSObject
@property(nonatomic,   copy)NSString *type;
@property(nonatomic, strong)NSDate *freezeDate;
@end
@implementation InspurUploadServerFreezeItem
+ (instancetype)item:(NSString *)type{
    InspurUploadServerFreezeItem *item = [[InspurUploadServerFreezeItem alloc] init];
    item.type = type;
    return item;
}
- (BOOL)isFrozenByDate:(NSDate *)date{
    BOOL isFrozen = YES;
    @synchronized (self) {
        if (!self.freezeDate || [self.freezeDate timeIntervalSinceDate:date] < 0){
            isFrozen = NO;
        }
    }
    return isFrozen;
}
- (void)freeze:(NSInteger)frozenTime{
    @synchronized (self) {
        self.freezeDate = [NSDate dateWithTimeIntervalSinceNow:frozenTime];
    }
}
@end

@interface InspurUploadServerFreezeManager()

@property(nonatomic, strong)NSMutableDictionary *freezeInfo;

@end
@implementation InspurUploadServerFreezeManager

- (instancetype)init{
    if (self = [super init]) {
        _freezeInfo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)isTypeFrozen:(NSString * _Nullable)type {
    if (!type || type.length == 0) {
        return true;
    }
    
    BOOL isFrozen = true;
    InspurUploadServerFreezeItem *item = nil;
    @synchronized (self) {
        item = self.freezeInfo[type];
    }
    
    if (!item || ![item isFrozenByDate:[NSDate date]]) {
        isFrozen = false;
    }
    
    return isFrozen;
}

- (void)freezeType:(NSString * _Nullable)type frozenTime:(NSInteger)frozenTime {
    if (!type || type.length == 0) {
        return;
    }
    
    InspurUploadServerFreezeItem *item = nil;
    @synchronized (self) {
        item = self.freezeInfo[type];
        if (!item) {
            item = [InspurUploadServerFreezeItem item:type];
            self.freezeInfo[type] = item;
        }
    }
    
    [item freeze:frozenTime];
}

- (void)unfreezeType:(NSString * _Nullable)type {
    if (!type || type.length == 0) {
        return;
    }
    
    @synchronized (self) {
        [self.freezeInfo removeObjectForKey:type];
    }
}

@end
