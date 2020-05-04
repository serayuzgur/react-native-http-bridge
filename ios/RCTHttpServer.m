#import "RCTHttpServer.h"
#import "React/RCTBridge.h"
#import "React/RCTLog.h"
#import "React/RCTEventDispatcher.h"

#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerDataRequest.h"
#import "GCDWebServerPrivate.h"
#include <stdlib.h>

@interface RCTHttpServer : NSObject <RCTBridgeModule> {
    GCDWebServer* _webServer;
    NSMutableDictionary* _completionBlocks;
}
@end

static RCTBridge *bridge;

@implementation RCTHttpServer

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();


- (void)initResponseReceivedFor:(GCDWebServer *)server forType:(NSString*)type {
    [server addDefaultHandlerForMethod:type
                          requestClass:[GCDWebServerDataRequest class]
                     asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock) {
        
        NSUUID  *UUID = [NSUUID UUID];
        NSString* requestId = [UUID UUIDString];
        
        _completionBlocks = [[NSMutableDictionary alloc] init];
         @synchronized (self) {
             [_completionBlocks setObject:completionBlock forKey:requestId];
         }

        @try {
            if ([GCDWebServerTruncateHeaderValue(request.contentType) isEqualToString:@"application/json"]) {
                GCDWebServerDataRequest* dataRequest = (GCDWebServerDataRequest*)request;
                [self.bridge.eventDispatcher sendAppEventWithName:@"httpServerResponseReceived"
                                                             body:@{@"requestId": requestId,
                                                                    @"postData": dataRequest.jsonObject,
                                                                    @"type": type,
                                                                    @"remoteAddess":request.remoteAddressString,
                                                                    @"url": request.URL.relativeString}];
            } else {
                [self.bridge.eventDispatcher sendAppEventWithName:@"httpServerResponseReceived"
                                                             body:@{@"requestId": requestId,
                                                                    @"type": type,
                                                                    @"remoteAddess":request.remoteAddressString,
                                                                    @"url": request.URL.relativeString}];
            }
        } @catch (NSException *exception) {
            [self.bridge.eventDispatcher sendAppEventWithName:@"httpServerResponseReceived"
                                                         body:@{@"requestId": requestId,
                                                                @"type": type,
                                                                @"remoteAddess":request.remoteAddressString,
                                                                @"url": request.URL.relativeString}];
        }
    }];
}

RCT_EXPORT_METHOD(start:(NSInteger) port
                  serviceName:(NSString *) serviceName)
{
    RCTLogInfo(@"Running HTTP bridge server: %ld", port);
    NSMutableDictionary *_requestResponses = [[NSMutableDictionary alloc] init];
    
    @try {
        dispatch_sync(dispatch_get_main_queue(), ^{
            _webServer = [[GCDWebServer alloc] init];
            
            [self initResponseReceivedFor:_webServer forType:@"POST"];
            [self initResponseReceivedFor:_webServer forType:@"PUT"];
            [self initResponseReceivedFor:_webServer forType:@"GET"];
            [self initResponseReceivedFor:_webServer forType:@"DELETE"];
            
            [_webServer startWithPort:port bonjourName:serviceName];
            [bridge.eventDispatcher sendAppEventWithName:@"httpServerStarted"body:@{@"result": @true}];

        });
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception.reason);
        [bridge.eventDispatcher sendAppEventWithName:@"httpServerStarted"body:@{@"result": @false, @"error":exception}];
    }
}

RCT_EXPORT_METHOD(stop)
{
    RCTLogInfo(@"Stopping HTTP bridge server");
    
    if (_webServer != nil) {
        @try {
            [_webServer stop];
            [_webServer removeAllHandlers];
            _webServer = nil;
            [bridge.eventDispatcher sendAppEventWithName:@"httpServerStopped"body:@{@"result": @true}];
        }
        @catch (NSException *exception) {
            NSLog(@"%@", exception.reason);
            [bridge.eventDispatcher sendAppEventWithName:@"httpServerStopped"body:@{@"result": @false, @"error":exception}];
        }
    }
}

RCT_EXPORT_METHOD(respond: (NSString *) requestId
                  code: (NSInteger) code
                  type: (NSString *) type
                  body: (NSString *) body)
{
    NSData* data = [body dataUsingEncoding:NSUTF8StringEncoding];
    GCDWebServerDataResponse* requestResponse = [[GCDWebServerDataResponse alloc] initWithData:data contentType:type];
    requestResponse.statusCode = code;

    GCDWebServerCompletionBlock completionBlock = nil;
    @synchronized (self) {
        completionBlock = [_completionBlocks objectForKey:requestId];
        [_completionBlocks removeObjectForKey:requestId];
    }

    if (completionBlock) {
        completionBlock(requestResponse);
    }
}

@end
