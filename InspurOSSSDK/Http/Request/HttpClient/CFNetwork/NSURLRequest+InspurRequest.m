//
//  NSURLRequest+QNRequest.m
//  AppTest
//
//  Created by Brook on 2020/4/8.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import <objc/runtime.h>
#import "NSURLRequest+InspurRequest.h"


@implementation NSURLRequest(InspurRequest)

#define kInspurURLRequestHostKey @"Host"
#define kInspurURLRequestIPKey @"QNURLRequestIP"
#define kInspurURLRequestIdentifierKey @"QNURLRequestIdentifier"

- (NSString *)inspur_identifier{
    return self.allHTTPHeaderFields[kInspurURLRequestIdentifierKey];
}

- (NSString *)inspur_domain{
    NSString *host = self.allHTTPHeaderFields[kInspurURLRequestHostKey];
    if (host == nil) {
        host = self.URL.host;
    }
    return host;
}

- (NSString *)inspur_ip{
    return self.allHTTPHeaderFields[kInspurURLRequestIPKey];
}

- (NSDictionary *)inspur_allHTTPHeaderFields{
    NSDictionary *headerFields = [self.allHTTPHeaderFields copy];
    NSMutableDictionary *headerFieldsNew = [NSMutableDictionary dictionary];
    for (NSString *key in headerFields) {
        if (![key isEqualToString:kInspurURLRequestIdentifierKey]) {
            [headerFieldsNew setObject:headerFields[key] forKey:key];
        }
    }
    return [headerFieldsNew copy];
}

+ (instancetype)inspur_requestWithURL:(NSURL *)url{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:url.host forHTTPHeaderField:kInspurURLRequestHostKey];
    return request;
}


- (NSData *)inspur_getHttpBody{
    
    if (self.HTTPBody ||
        (![self.HTTPMethod isEqualToString:@"POST"] && ![self.HTTPMethod isEqualToString:@"PUT"])) {
        return self.HTTPBody;
    }
    
    NSInteger maxLength = 1024;
    uint8_t d[maxLength];
    
    NSInputStream *stream = self.HTTPBodyStream;
    NSMutableData *data = [NSMutableData data];
    
    [stream open];
    
    BOOL end = NO;
    
    while (!end) {
        NSInteger bytesRead = [stream read:d maxLength:maxLength];
        if (bytesRead == 0) {
            end = YES;
        } else if (bytesRead == -1){
            end = YES;
        } else if (stream.streamError == nil){
            [data appendBytes:(void *)d length:bytesRead];
       }
    }
    [stream close];
    return [data copy];
}

- (BOOL)inspur_isHttps{
    if ([self.URL.absoluteString rangeOfString:@"https://"].location != NSNotFound) {
        return YES;
    } else {
        return NO;
    }
}
@end


@implementation NSMutableURLRequest(InspurRequest)

- (void)setInspur_domain:(NSString *)inspur_domain{
    if (inspur_domain) {
        [self addValue:inspur_domain forHTTPHeaderField:kInspurURLRequestHostKey];
    } else {
        [self setValue:nil forHTTPHeaderField:kInspurURLRequestHostKey];
    }

    NSString *identifier = [NSString stringWithFormat:@"%p-%@", &self, inspur_domain];
    [self setInspur_identifier:identifier];
}

- (void)setInspur_ip:(NSString *)inspur_ip{
    if (inspur_ip) {
        [self addValue:inspur_ip forHTTPHeaderField:kInspurURLRequestIPKey];
    } else {
        [self setValue:nil forHTTPHeaderField:kInspurURLRequestIPKey];
    }
}

- (void)setInspur_identifier:(NSString *)inspur_identifier{
    if (inspur_identifier) {
        [self addValue:inspur_identifier forHTTPHeaderField:kInspurURLRequestIdentifierKey];
    } else {
        [self setValue:nil forHTTPHeaderField:kInspurURLRequestIdentifierKey];
    }
}

@end
