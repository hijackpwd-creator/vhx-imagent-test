#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <math.h>
#include <stdint.h>

static void Record(NSString *message) {
    NSLog(@"[VHXImagentTest] %@", message);
    NSString *line = [NSString stringWithFormat:@"%@\n%@\n", [NSDate date], message];
    NSError *error = nil;
    BOOL written = [line writeToFile:@"/var/mobile/Library/Logs/VHXImagentTest.log"
                         atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!written) NSLog(@"[VHXImagentTest] Log file unavailable: %@", error);
}

__attribute__((constructor)) static void StartTest(void) {
    @autoreleasepool {
        if (![[NSProcessInfo processInfo].processName isEqualToString:@"imagent"]) return;
        NSLog(@"[VHXImagentTest] Loaded into imagent pid=%d", [NSProcessInfo processInfo].processIdentifier);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            @autoreleasepool {
                NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:
                    @"/var/mobile/Library/Preferences/local.vhx.imagenttest.plist"];
                if (![config isKindOfClass:NSDictionary.class]) {
                    Record(@"No readable configuration; no request sent.");
                    return;
                }
                NSString *base = config[@"BaseURL"];
                NSNumber *timeoutValue = config[@"Timeout"];
                NSNumber *statusValue = config[@"ExpectedStatus"];
                if (![base isKindOfClass:NSString.class] ||
                    (timeoutValue && ![timeoutValue isKindOfClass:NSNumber.class]) ||
                    (statusValue && ![statusValue isKindOfClass:NSNumber.class])) {
                    Record(@"Invalid configuration types; no request sent."); return;
                }
                double timeout = timeoutValue ? timeoutValue.doubleValue : 5;
                NSInteger expected = statusValue ? statusValue.integerValue : 200;
                NSURL *url = [NSURL URLWithString:[base stringByAppendingString:@"/vhx"]];
                if (!base.length || !url.host.length ||
                    !([url.scheme.lowercaseString isEqualToString:@"http"] || [url.scheme.lowercaseString isEqualToString:@"https"]) ||
                    !isfinite(timeout) || timeout <= 0 || timeout > 120 || expected < 100 || expected > 599) {
                    Record(@"Invalid URL, timeout or status; no request sent."); return;
                }
                __block NSData *bodyData = nil;
                __block NSURLResponse *reply = nil;
                __block NSError *failure = nil;
                __block BOOL success = NO;
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                request.HTTPMethod = @"GET";
                request.timeoutInterval = timeout;
                NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
                NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                        bodyData = data; reply = response; failure = error;
                        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
                        if (!error && http && http.statusCode == expected && data.length) {
                            NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                            NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                            success = trimmed != nil && [trimmed caseInsensitiveCompare:@"ok"] == NSOrderedSame;
                        }
                        dispatch_semaphore_signal(semaphore);
                    }];
                [task resume];
                long wait = dispatch_semaphore_wait(semaphore,
                    dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 2) * NSEC_PER_SEC)));
                double elapsed = NSProcessInfo.processInfo.systemUptime - start;
                if (wait) {
                    [task cancel];
                    Record([NSString stringWithFormat:@"RESULT=false URL=%@ elapsed=%.3f; wait timed out, task cancelled", url, elapsed]);
                    return;
                }
                NSHTTPURLResponse *http = [reply isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)reply : nil;
                NSString *text = [[NSString alloc] initWithData:bodyData ?: [NSData data] encoding:NSUTF8StringEncoding];
                NSString *preview = text ? [text substringToIndex:MIN(text.length, (NSUInteger)4096)] : @"(invalid UTF-8)";
                Record([NSString stringWithFormat:@"RESULT=%@\nURL=%@\nFinalURL=%@\nelapsed=%.3f\nHTTP=%ld expected=%ld\nbytes=%lu\nError=%@\nErrorDetails=%@\nBody=%@",
                    success ? @"true" : @"false", url, reply.URL.absoluteString ?: @"(none)", elapsed,
                    (long)http.statusCode, (long)expected, (unsigned long)bodyData.length,
                    failure ?: @"(none)", failure.userInfo ?: @{}, preview]);
            }
        });
    }
}
