//
//  InspurUserAgent.h
//  InspurOSSSDK
//
//  Created by Brook on 14-9-29.
//  Copyright (c) 2014年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *    UserAgent
 *
 */

#define kInspurUserAgent [InspurUserAgent sharedInstance]
@interface InspurUserAgent : NSObject

/**
 *    用户id
 */
@property (copy, nonatomic, readonly) NSString *id;

/**
 *    UserAgent 字串
 */
- (NSString *)description;

/**
 *    UserAgent + AK 字串
 *    @param access access信息
 */
- (NSString *)getUserAgent:(NSString *)access;

/**
 *  单例
 */
+ (instancetype)sharedInstance;
@end
