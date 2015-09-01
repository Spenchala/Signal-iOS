//
//  AFSecurityPolicyNone.m
//  Signal
//
//  Created by Fred on 01/09/15.
//  Copyright © 2015 Open Whisper Systems. All rights reserved.
//

#import "AFSecurityOWSPolicy.h"
#import <AssertMacros.h>

@implementation AFSecurityOWSPolicy

+ (instancetype)OWS_PinningPolicy {
    static AFSecurityOWSPolicy *sharedMyManager = nil;
    @synchronized(self) {
        if (sharedMyManager == nil)
            sharedMyManager = [[self alloc] initWithOWSPolicy];
    }
    return sharedMyManager;
}

- (instancetype)initWithOWSPolicy {
    self = [[super class] defaultPolicy];
    
    if (self) {
        self.pinnedCertificates = @[[self certificateForService:@"textsecure"],
                                    [self certificateForService:@"redphone"]];
    }
    
    return self;
}

- (NSData*)certificateForService:(NSString*)service
{
    NSString *path = [NSBundle.mainBundle pathForResource:service ofType:@"cer"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        @throw [NSException exceptionWithName:@"Missing server certificate"
                                       reason:[NSString stringWithFormat:@"Missing signing certificate for service %@", service]
                                     userInfo:nil];
    }
    
    NSData *certificateData = [NSData dataWithContentsOfFile:path];
    SecCertificateRef certRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(certificateData));
    return (__bridge_transfer NSData *)SecCertificateCopyData(certRef);
}


- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
{
    NSMutableArray *policies = [NSMutableArray array];
    [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    
    if (SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies) != errSecSuccess){
        DDLogError(@"The trust policy couldn't be set.");
        return NO;
    }
    
    NSMutableArray *pinnedCertificates = [NSMutableArray array];
    for (NSData *certificateData in self.pinnedCertificates) {
        [pinnedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
    }
    
    if (SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)pinnedCertificates) != errSecSuccess){
        DDLogError(@"The anchor certificates couldn't be set.");
        return NO;
    }
    
    if (!AFServerTrustIsValid(serverTrust)) {
        return NO;
    }
    
    return YES;
}


static BOOL AFServerTrustIsValid(SecTrustRef serverTrust) {
    BOOL isValid = NO;
    SecTrustResultType result;
    __Require_noErr_Quiet(SecTrustEvaluate(serverTrust, &result), _out);
    
    isValid = (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
    
_out:
    return isValid;
}

@end
