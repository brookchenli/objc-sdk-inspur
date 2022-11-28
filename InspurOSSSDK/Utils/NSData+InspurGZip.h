//
//  NSData+InspurGZip.h
//  GZipTest
//
//  Created by Brook on 2020/8/12.
//  Copyright © 2020 yangsen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData(InspurGZip)

+ (NSData *)inspur_gZip:(NSData *)data;

+ (NSData *)inspur_gUnzip:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
