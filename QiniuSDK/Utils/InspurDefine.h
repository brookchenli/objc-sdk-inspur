//
//  QNDefine.h
//  QiniuSDK
//
//  Created by Brook on 2020/9/4.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kInspurWeakSelf __weak typeof(self) weak_self = self
#define kInspurStrongSelf __strong typeof(self) self = weak_self

#define kInspurWeakObj(object) __weak typeof(object) weak_##object = object
#define kInspurStrongObj(object) __strong typeof(object) object = weak_##object
