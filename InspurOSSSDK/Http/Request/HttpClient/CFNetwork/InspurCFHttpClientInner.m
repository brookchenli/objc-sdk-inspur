//
//  InspurHttpClient.m
//  AppTest
//
//  Created by Brook on 2020/4/7.
//  Copyright © 2020 com.inspur. All rights reserved.
//

#import "InspurErrorCode.h"
#import "InspurDefine.h"
#import "InspurCFHttpClientInner.h"
#import "NSURLRequest+InspurRequest.h"
#import <sys/errno.h>

#define kInspurCFHttpClientErrorDomain @"CFNetwork"

@interface InspurCFHttpClientInner()<NSStreamDelegate>

@property(nonatomic, assign)BOOL isCallFinishOrError;
@property(nonatomic, assign)BOOL isCompleted;
@property(nonatomic, strong)NSMutableURLRequest *request;
@property(nonatomic, strong)NSDictionary *connectionProxy;
@property(nonatomic, assign)BOOL isReadResponseHeader;
@property(nonatomic, assign)BOOL isReadResponseBody;
@property(nonatomic, assign)BOOL isInputStreamEvaluated;
@property(nonatomic, strong)NSInputStream *inputStream;

// 上传进度
@property(nonatomic, strong)NSTimer *progressTimer; // 进度定时器
@property(nonatomic, assign)int64_t totalBytesSent; // 已上传大小
@property(nonatomic, assign)int64_t totalBytesExpectedToSend; // 总大小

@end
@implementation InspurCFHttpClientInner

+ (instancetype)client:(NSURLRequest *)request connectionProxy:(nonnull NSDictionary *)connectionProxy{
    if (!request) {
        return nil;
    }
    InspurCFHttpClientInner *client = [[InspurCFHttpClientInner alloc] init];
    client.connectionProxy = connectionProxy;
    client.request = [request mutableCopy];
    client.isCompleted = false;
    return client;
}

- (void)main {
    [self prepare];
    [self openInputStream];
    [self startProgress];
}

- (void)prepare {
    @autoreleasepool {
        self.inputStream = [self createInputStream:self.request];
    }
    
    NSString *host = [self.request inspur_domain];
    if ([self.request inspur_isHttps]) {
       [self setInputStreamSNI:self.inputStream sni:host];
    }
    
    [self setupProgress];
}

- (void)releaseResource{
    [self endProgress:YES];
    [self closeInputStream];
}

- (void)cancel {
    [self releaseResource];
    [self delegate_onError:[self createError:NSURLErrorCancelled errorDescription:@"user cancel"]];
}

//MARK: -- request -> stream
- (NSInputStream *)createInputStream:(NSURLRequest *)urlRequest{

    CFReadStreamRef readStream = NULL;
    @autoreleasepool {
        CFStringRef urlString = (__bridge CFStringRef) [urlRequest.URL absoluteString];
        CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault,
                                             urlString,
                                             NULL);
        CFStringRef httpMethod = (__bridge CFStringRef) urlRequest.HTTPMethod;
        CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault,
                                                              httpMethod,
                                                              url,
                                                              kCFHTTPVersion1_1);
        CFRelease(url);

        NSDictionary *headFieldInfo = self.request.inspur_allHTTPHeaderFields;
        for (NSString *headerField in headFieldInfo) {
            CFStringRef headerFieldP = (__bridge CFStringRef)headerField;
            CFStringRef headerFieldValueP = (__bridge CFStringRef)(headFieldInfo[headerField]);
            CFHTTPMessageSetHeaderFieldValue(request, headerFieldP, headerFieldValueP);
        }
        
        NSData *httpBody = [self.request inspur_getHttpBody];
        if (httpBody) {
            CFDataRef bodyData = (__bridge CFDataRef) httpBody;
            CFHTTPMessageSetBody(request, bodyData);
        }
        
        readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, request);
        CFRelease(request);
    }
    
    @autoreleasepool {
        if (self.connectionProxy) {
            for (NSString *key in self.connectionProxy.allKeys) {
                NSObject *value = self.connectionProxy[key];
                if (key.length > 0) {
                    CFReadStreamSetProperty(readStream, (__bridge CFTypeRef _Null_unspecified)key, (__bridge CFTypeRef _Null_unspecified)(value));
                }
            }
        }
    }
    return (__bridge_transfer NSInputStream *) readStream;
}

- (void)setInputStreamSNI:(NSInputStream *)inputStream sni:(NSString *)sni{
    if (!sni || sni.length == 0) {
        return;
    }
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings setObject:NSStreamSocketSecurityLevelNegotiatedSSL
                 forKey:NSStreamSocketSecurityLevelKey];
    [settings setObject:sni
                 forKey:(NSString *)kCFStreamSSLPeerName];
    [inputStream setProperty:settings forKey:(NSString *)CFBridgingRelease(kCFStreamPropertySSLSettings)];
}


//MARK: -- stream action
- (void)openInputStream{
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    self.inputStream.delegate = self;
    [self.inputStream open];
}

- (void)closeInputStream {
    @synchronized (self) {
        if (self.inputStream) {
            [self.inputStream close];
            [self.inputStream setDelegate:nil];
            [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            self.inputStream = nil;
        }
    }
}

- (BOOL)shouldEvaluateInputStreamServerTrust{
    if (![self.request inspur_isHttps] || self.isInputStreamEvaluated) {
        return NO;
    } else {
        return YES;
    }
}

- (void)inputStreamGetAndNotifyHttpResponse{
    @synchronized (self) {
        if (self.isReadResponseHeader) {
            return;
        }
        self.isReadResponseHeader = YES;
    }
    

    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.inputStream;
    CFHTTPMessageRef httpMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    
    CFDictionaryRef headerFields = CFHTTPMessageCopyAllHeaderFields(httpMessage);
    NSDictionary *headInfo = (__bridge_transfer NSDictionary *)headerFields;
    
    CFStringRef httpVersion = CFHTTPMessageCopyVersion(httpMessage);
    NSString *httpVersionInfo = (__bridge_transfer NSString *)httpVersion;
    
    CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(httpMessage);
    
    if (![self isHttpRedirectStatusCode:statusCode]) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:statusCode HTTPVersion:httpVersionInfo headerFields:headInfo];
        [self delegate_onReceiveResponse:response httpVersion:httpVersionInfo];
    }
    
    CFRelease(httpMessage);
}

- (void)inputStreamGetAndNotifyHttpData{
    @synchronized (self) {
        if (self.isReadResponseBody) {
            return;
        }
        self.isReadResponseBody = YES;
    }
    
    UInt8 buffer[16 * 1024];
    UInt8 *buf = NULL;
    NSUInteger length = 0;
    
    if (![self.inputStream getBuffer:&buf length:&length]) {
        NSInteger amount = [self.inputStream read:buffer maxLength:sizeof(buffer)];
        buf = buffer;
        length = amount;
    }
    
    NSData *data = [[NSData alloc] initWithBytes:buf length:length];
    [self delegate_didLoadData:data];
}

- (BOOL)isInputStreamHttpResponseHeaderComplete{
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.inputStream;
    CFHTTPMessageRef responseMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    BOOL isComplete = CFHTTPMessageIsHeaderComplete(responseMessage);
    CFRelease(responseMessage);
    return isComplete;
}

- (BOOL)shouldInputStreamRedirect{
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.inputStream;
    CFHTTPMessageRef responseMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(responseMessage);
    CFRelease(responseMessage);
    return [self isHttpRedirectStatusCode:statusCode];
}

- (BOOL)isHttpRedirectStatusCode:(NSInteger)code{
    if (code == 301 || code == 302 || code == 303 || code == 307) {
        return YES;
    } else {
        return NO;
    }
}

- (void)inputStreamRedirect{
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.inputStream;
    CFHTTPMessageRef responseMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    
    CFDictionaryRef headerFields = CFHTTPMessageCopyAllHeaderFields(responseMessage);
    NSDictionary *headInfo = (__bridge_transfer NSDictionary *)headerFields;
    
    NSString *urlString = headInfo[@"Location"];
    if (!urlString) {
        urlString = headInfo[@"location"];
    }
    if (!urlString) {
        return;
    }
    
    CFStringRef httpVersion = CFHTTPMessageCopyVersion(responseMessage);
    NSString *httpVersionString = (__bridge_transfer NSString *)httpVersion;
    
    CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(responseMessage);
    
    NSDictionary *requestHeader = self.request.allHTTPHeaderFields;
    if (statusCode == 303) {
        NSMutableDictionary *header = [NSMutableDictionary dictionary];
        if (requestHeader[@"User-Agent"]) {
            header[@"User-Agent"] = requestHeader[@"User-Agent"];
        }
        if (requestHeader[@"Accept"]) {
            header[@"Accept"] = requestHeader[@"Accept"];
        }
        requestHeader = [header copy];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request setAllHTTPHeaderFields:requestHeader];
    NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                          statusCode:statusCode
                                                         HTTPVersion:httpVersionString
                                                        headerFields:headInfo];
    
    [self releaseResource];
    [self delegate_redirectedToRequest:request redirectResponse:response];
    
    CFRelease(responseMessage);
}

//MARK: -- NSStreamDelegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    @autoreleasepool {
        switch (eventCode) {
            case NSStreamEventHasBytesAvailable:{
                if (![self isInputStreamHttpResponseHeaderComplete]) {
                    break;
                }
                
                [self inputStreamGetAndNotifyHttpResponse];
                [self inputStreamGetAndNotifyHttpData];
            }
                break;
            case NSStreamEventHasSpaceAvailable:
                break;
            case NSStreamEventErrorOccurred:{
                [self releaseResource];
                [self endProgress: YES];
                [self delegate_onError:[self translateCFNetworkErrorIntoUrlError:[aStream streamError]]];
            }
                break;
            case NSStreamEventEndEncountered:{
                if ([self shouldInputStreamRedirect]) {
                    [self inputStreamRedirect];
                } else {
                    
                    [self inputStreamGetAndNotifyHttpResponse];
                    [self inputStreamGetAndNotifyHttpData];
                    
                    [self releaseResource];
                    [self endProgress: NO];
                    [self delegate_didFinish];
                }
            }
                break;
            default:
                break;
        }
    }
}

//MARK: -- progress and timer action
- (void)setupProgress{
    self.totalBytesExpectedToSend = [self.request.inspur_getHttpBody length];
}

- (void)startProgress{
    [self createTimer];
}

- (void)endProgress:(BOOL)hasError{
    
    [self invalidateTimer];
    
    if (!hasError) {
        [self delegate_didSendBodyData:self.totalBytesExpectedToSend - self.totalBytesSent
                        totalBytesSent:self.totalBytesExpectedToSend
              totalBytesExpectedToSend:self.totalBytesExpectedToSend];
    }
}

- (void)createTimer{
    
    if (_progressTimer) {
        [self invalidateTimer];
    }
    
    kInspurWeakSelf;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.3
                                             target:weak_self
                                           selector:@selector(timerAction)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    
    [self timerAction];
    _progressTimer = timer;
}

- (void)invalidateTimer{
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

- (void)timerAction{
    long long totalBytesSent = [(NSNumber *)CFBridgingRelease(CFReadStreamCopyProperty((CFReadStreamRef)[self inputStream], kCFStreamPropertyHTTPRequestBytesWrittenCount)) longLongValue];
    long long bytesSent = totalBytesSent - self.totalBytesSent;
    self.totalBytesSent = totalBytesSent;
    if (bytesSent > 0 && self.totalBytesSent <= self.totalBytesSent) {
        [self delegate_didSendBodyData:bytesSent
                        totalBytesSent:self.totalBytesSent
              totalBytesExpectedToSend:self.totalBytesExpectedToSend];
    }
}

- (NSError *)translateCFNetworkErrorIntoUrlError:(NSError *)cfError{
    if (cfError == nil) {
        return nil;
    }
    
    NSInteger errorCode = kInspurNetworkError;
    NSString *errorInfo = [NSString stringWithFormat:@"cf client:[%ld] %@", (long)cfError.code, cfError.localizedDescription];
    switch (cfError.code) {
        case ENOENT: /* No such file or directory */
            errorCode = NSFileNoSuchFileError;
            break;
        case EIO: /* Input/output error */
            errorCode = kInspurLocalIOError;
            break;
        case E2BIG: /* Argument list too long */
            break;
        case ENOEXEC: /* Exec format error */
            errorCode = kInspurLocalIOError;
            break;
        case EBADF: /* Bad file descriptor */
            errorCode = kInspurLocalIOError;
            break;
        case ECHILD: /* No child processes */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EDEADLK: /* Resource deadlock avoided */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ENOMEM: /* Cannot allocate memory */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EACCES: /* Permission denied */
            errorCode = NSURLErrorNoPermissionsToReadFile;
            break;
        case EFAULT: /* Bad address */
            errorCode = NSURLErrorBadURL;
            break;
        case EBUSY: /* Device / Resource busy */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EEXIST: /* File exists */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ENODEV: /* Operation not supported by device */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EISDIR: /* Is a directory */
            errorCode = NSURLErrorFileIsDirectory;
            break;
        case ENOTDIR: /* Not a directory */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EINVAL: /* Invalid argument */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ENFILE: /* Too many open files in system */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EMFILE: /* Too many open files */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EFBIG: /* File too large */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ENOSPC: /* No space left on device */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ESPIPE: /* Illegal seek */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EMLINK: /* Too many links */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EPIPE: /* Broken pipe */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EDOM: /* Numerical argument out of domain */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ERANGE: /* Result too large */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EAGAIN: /* Resource temporarily unavailable */
            break;
        case ENOTSOCK: /* Socket operation on non-socket */
            break;
        case EDESTADDRREQ: /* Destination address required */
            errorCode = NSURLErrorBadURL;
            break;
        case EMSGSIZE: /* Message too long */
            break;
        case EPROTOTYPE: /* Protocol wrong type for socket */
            break;
        case ENOPROTOOPT: /* Protocol not available */
            break;
        case EPROTONOSUPPORT: /* Protocol not supported */
            break;
        case ENOTSUP: /* Operation not supported */
            break;
        case EPFNOSUPPORT: /* Protocol family not supported */
            break;
        case EAFNOSUPPORT: /* Address family not supported by protocol family */
            break;
        case EADDRINUSE: /* Address already in use */
            break;
        case EADDRNOTAVAIL: /* Can't assign requested address */
            break;
        case ENETDOWN: /* Network is down */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case ENETUNREACH: /* Network is unreachable */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case ENETRESET: /* Network dropped connection on reset */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case ECONNABORTED: /* Software caused connection abort */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case ECONNRESET: /* Connection reset by peer */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case ENOBUFS: /* No buffer space available */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EISCONN: /* Socket is already connected */
            break;
        case ENOTCONN: /* Socket is not connected */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case ESHUTDOWN: /* Can't send after socket shutdown */
            break;
        case ETOOMANYREFS: /* Too many references: can't splice */
            break;
        case ETIMEDOUT: /* Operation timed out */
            errorCode = NSURLErrorTimedOut;
            break;
        case ECONNREFUSED: /* Connection refused */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case ELOOP: /* Too many levels of symbolic links */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ENAMETOOLONG: /* File name too long */
            break;
        case EHOSTDOWN: /* Host is down */
            break;
        case EHOSTUNREACH: /* No route to host */
            break;
        case ENOTEMPTY: /* Directory not empty */
            break;
        case EPROCLIM: /* Too many processes */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EUSERS: /* Too many users */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EDQUOT: /* Disc quota exceeded */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ESTALE: /* Stale NFS file handle */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EREMOTE: /* Too many levels of remote in path */
            break;
        case EBADRPC: /* RPC struct is bad */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ERPCMISMATCH: /* RPC version wrong */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EPROGUNAVAIL: /* RPC prog. not avail */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EPROGMISMATCH: /* Program version wrong */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EPROCUNAVAIL: /* Bad procedure for program */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ENOLCK: /* No locks available */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ENOSYS: /* Function not implemented */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EFTYPE: /* Inappropriate file type or format */
            break;
        case EAUTH: /* Authentication error */
            break;
        case ENEEDAUTH: /* Need authenticator */
            break;
        case EPWROFF: /* Device power is off */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EDEVERR: /* Device error, e.g. paper out */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EOVERFLOW: /* Value too large to be stored in data type */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EBADEXEC: /* Bad executable */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EBADARCH: /* Bad CPU type in executable */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ESHLIBVERS: /* Shared library version mismatch */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EBADMACHO: /* Malformed Macho file */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case ECANCELED: /* Operation canceled */
            errorCode = NSURLErrorCancelled;
            break;
        case EIDRM: /* Identifier removed */
            break;
        case ENOMSG: /* No message of desired type */
            break;
        case EILSEQ: /* Illegal byte sequence */
            break;
        case ENOATTR: /* Attribute not found */
            break;
        case EBADMSG: /* Bad message */
            break;
        case EMULTIHOP: /* Reserved */
            break;
        case ENODATA: /* No message available on STREAM */
            break;
        case ENOLINK: /* Reserved */
            break;
        case ENOSR: /* No STREAM resources */
            break;
        case ENOSTR: /* Not a STREAM */
            break;
        case EPROTO: /* Protocol error */
            break;
        case ETIME: /* STREAM ioctl timeout */
            errorCode = NSURLErrorTimedOut;
            break;
        case EOPNOTSUPP: /* Operation not supported on socket */
            break;
        case ENOPOLICY: /* No such policy registered */
            break;
        case ENOTRECOVERABLE: /* State not recoverable */
            break;
        case EOWNERDEAD: /* Previous owner died */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case EQFULL: /* Interface output queue is full */
            break;
        case -9800:    /* SSL protocol error */
            errorCode = NSURLErrorSecureConnectionFailed;
            break;
        case -9801:    /* Cipher Suite negotiation failure */
            errorCode = NSURLErrorSecureConnectionFailed;
            break;
        case -9802:    /* Fatal alert */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case -9803:    /* I/O would block (not fatal) */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case -9804:    /* attempt to restore an unknown session */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case -9805:    /* connection closed gracefully */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case -9806:    /* connection closed via error */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case -9807:    /* invalid certificate chain */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9808:    /* bad certificate format */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9809:    /* underlying cryptographic error */
            errorCode = NSURLErrorSecureConnectionFailed;
            break;
        case -9810:    /* Internal error */
            errorCode = NSURLErrorNotConnectedToInternet;
            break;
        case -9811:    /* module attach failure */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case -9812:    /* valid cert chain, untrusted root */
            errorCode = NSURLErrorServerCertificateHasUnknownRoot;
            break;
        case -9813:    /* cert chain not verified by root */
            errorCode = NSURLErrorServerCertificateHasUnknownRoot;
            break;
        case -9814:    /* chain had an expired cert */
            errorCode = NSURLErrorServerCertificateHasBadDate;
            break;
        case -9815:    /* chain had a cert not yet valid */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9816:    /* server closed session with no notification */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case -9817:    /* insufficient buffer provided */
            errorCode = NSURLErrorCannotDecodeRawData;
            break;
        case -9818:    /* bad SSLCipherSuite */
            errorCode = NSURLErrorClientCertificateRejected;
            break;
        case -9819:    /* unexpected message received */
            errorCode = NSURLErrorNotConnectedToInternet;
            break;
        case -9820:    /* bad MAC */
            errorCode = NSURLErrorNotConnectedToInternet;
            break;
        case -9821:    /* decryption failed */
            errorCode = NSURLErrorNotConnectedToInternet;
            break;
        case -9822:    /* record overflow */
            errorCode = NSURLErrorDataLengthExceedsMaximum;
            break;
        case -9823:    /* decompression failure */
            errorCode = NSURLErrorDownloadDecodingFailedMidStream;
            break;
        case -9824:    /* handshake failure */
            errorCode = NSURLErrorClientCertificateRejected;
            break;
        case -9825:    /* misc. bad certificate */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9826:    /* bad unsupported cert format */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9827:    /* certificate revoked */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9828:    /* certificate expired */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9829:    /* unknown certificate */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9830:    /* illegal parameter */
            errorCode = NSURLErrorCannotDecodeRawData;
            break;
        case -9831:    /* unknown Cert Authority */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9832:    /* access denied */
            errorCode = NSURLErrorClientCertificateRejected;
            break;
        case -9833:    /* decoding error */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9834:    /* decryption error */
            errorCode = NSURLErrorCannotDecodeRawData;
            break;
        case -9835:    /* export restriction */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case -9836:    /* bad protocol version */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case -9837:    /* insufficient security */
            errorCode = NSURLErrorClientCertificateRejected;
            break;
        case -9838:    /* internal error */
            errorCode = NSURLErrorTimedOut;
            break;
        case -9839:    /* user canceled */
            errorCode = NSURLErrorCancelled;
            break;
        case -9840:    /* no renegotiation allowed */
            errorCode = NSURLErrorCannotConnectToHost;
            break;
        case -9841:    /* peer cert is valid, or was ignored if verification disabled */
            errorCode = NSURLErrorServerCertificateNotYetValid;
            break;
        case -9842:    /* server has requested a client cert */
            errorCode = NSURLErrorClientCertificateRejected;
            break;
        case -9843:    /* peer host name mismatch */
            errorCode = NSURLErrorNotConnectedToInternet;
            break;
        case -9844:    /* peer dropped connection before responding */
            errorCode = NSURLErrorNetworkConnectionLost;
            break;
        case -9845:    /* decryption failure */
            errorCode = NSURLErrorCannotDecodeRawData;
            break;
        case -9846:    /* bad MAC */
            errorCode = NSURLErrorNotConnectedToInternet;
            break;
        case -9847:    /* record overflow */
            errorCode = NSURLErrorDataLengthExceedsMaximum;
            break;
        case -9848:    /* configuration error */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case -9849:    /* unexpected (skipped) record in DTLS */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case -9850:   /* weak ephemeral dh key  */
            errorCode = kInspurUnexpectedSysCallError;
            break;
        case -9851:    /* SNI */
            errorCode = NSURLErrorClientCertificateRejected;
            break;
        default:
            break;
    }
    
    return [NSError errorWithDomain:NSURLErrorDomain code:errorCode userInfo:@{@"UserInfo" : errorInfo ?: @""}];
}


//MARK: -- delegate action
- (void)delegate_redirectedToRequest:(NSURLRequest *)request
                    redirectResponse:(NSURLResponse *)redirectResponse{
    if ([self.delegate respondsToSelector:@selector(redirectedToRequest:redirectResponse:)]) {
        [self.delegate redirectedToRequest:request redirectResponse:redirectResponse];
    }
}

- (void)delegate_onError:(NSError *)error{
    @synchronized (self) {
        if (self.isCallFinishOrError) {
            return;
        }
        self.isCallFinishOrError = YES;
    }
    
    if ([self.delegate respondsToSelector:@selector(onError:)]) {
        [self.delegate onError:error];
    }
}

- (void)delegate_didSendBodyData:(int64_t)bytesSent
                  totalBytesSent:(int64_t)totalBytesSent
        totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    if ([self.delegate respondsToSelector:@selector(didSendBodyData:
                                                    totalBytesSent:
                                                    totalBytesExpectedToSend:)]) {
        [self.delegate didSendBodyData:bytesSent
                        totalBytesSent:totalBytesSent
              totalBytesExpectedToSend:totalBytesExpectedToSend];
    }
}
- (void)delegate_onReceiveResponse:(NSURLResponse *)response httpVersion:(NSString *)httpVersion{
    if ([self.delegate respondsToSelector:@selector(onReceiveResponse:httpVersion:)]) {
        [self.delegate onReceiveResponse:response httpVersion:httpVersion];
    }
}

- (void)delegate_didLoadData:(NSData *)data{
    if ([self.delegate respondsToSelector:@selector(didLoadData:)]) {
        [self.delegate didLoadData:data];
    }
}

- (void)delegate_didFinish{
    @synchronized (self) {
        if (self.isCallFinishOrError) {
            return;
        }
        self.isCallFinishOrError = YES;
    }
    
    if ([self.delegate respondsToSelector:@selector(didFinish)]) {
        [self.delegate didFinish];
    }
}


// MARK: error
- (NSError *)createError:(NSInteger)errorCode errorDescription:(NSString *)errorDescription {
    if (errorDescription) {
        return [NSError errorWithDomain:kInspurCFHttpClientErrorDomain
                                   code:errorCode
                               userInfo:@{@"userInfo":errorDescription}];
    } else {
        return [NSError errorWithDomain:kInspurCFHttpClientErrorDomain
                                   code:NSURLErrorSecureConnectionFailed
                               userInfo:nil];
    }
}

@end
