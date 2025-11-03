#import "ImageDescriptionModule.h"
#import <React/RCTLog.h>
#import <Vision/Vision.h>
#import <UIKit/UIKit.h>

@implementation ImageDescriptionModule

RCT_EXPORT_MODULE(ImageDescription)

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSLog(@"[ImageDescription] Module initialized successfully");
    }
    return self;
}

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[];
}

RCT_EXPORT_METHOD(classifyImage:(NSString *)imageUri
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[ImageDescription] classifyImage called with URI: %@", imageUri);
    
    @try {
        // Check iOS version
        if (@available(iOS 15.0, *)) {
            // Parse options
            double minimumPrecision = [options[@"minimumPrecision"] doubleValue] ?: 0.1;
            double recallThreshold = [options[@"recallThreshold"] doubleValue] ?: 0.8;
            double minimumConfidence = [options[@"minimumConfidence"] doubleValue] ?: 0.0;
            NSInteger maxResults = [options[@"maxResults"] integerValue] ?: 0;
            
            NSLog(@"[ImageDescription] Options - precision: %.2f, recall: %.2f, confidence: %.2f, maxResults: %ld", 
                  minimumPrecision, recallThreshold, minimumConfidence, (long)maxResults);
            
            // Convert URI to URL
            NSURL *imageURL = [self urlFromImageUri:imageUri];
            if (!imageURL) {
                NSLog(@"[ImageDescription] ERROR: Invalid URI");
                reject(@"invalid_uri", @"Invalid image URI", nil);
                return;
            }
            
            NSLog(@"[ImageDescription] Image path: %@", imageURL.path);
            
            // Load image
            UIImage *image = [UIImage imageWithContentsOfFile:imageURL.path];
            if (!image) {
                NSLog(@"[ImageDescription] ERROR: Failed to load image from path: %@", imageURL.path);
                reject(@"image_load_failed", [NSString stringWithFormat:@"Failed to load image from path: %@", imageURL.path], nil);
                return;
            }
            
            NSLog(@"[ImageDescription] Image loaded successfully, size: %.0fx%.0f", image.size.width, image.size.height);
            
#if TARGET_OS_SIMULATOR
            NSLog(@"[ImageDescription] WARNING: Running on iOS Simulator - Vision classification may not work");
            NSLog(@"[ImageDescription] Please test on a real device for full functionality");
#endif
            
            // Create image request handler
            NSLog(@"[ImageDescription] Creating VNImageRequestHandler...");
            VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage
                                                                                    options:@{}];
            
            // Create classification request
            NSLog(@"[ImageDescription] Creating VNClassifyImageRequest...");
            VNClassifyImageRequest *request = [[VNClassifyImageRequest alloc] init];
            
            // Perform the request
            NSLog(@"[ImageDescription] Performing Vision classification request...");
            NSError *error = nil;
            [handler performRequests:@[request] error:&error];
            
            if (error) {
                NSLog(@"[ImageDescription] ERROR: Vision request failed - %@", error.localizedDescription);
                NSLog(@"[ImageDescription] Error domain: %@, code: %ld", error.domain, (long)error.code);
                NSLog(@"[ImageDescription] Error userInfo: %@", error.userInfo);
                
#if TARGET_OS_SIMULATOR
                NSString *errorMessage = [NSString stringWithFormat:@"Vision classification requires a real iOS device. Error: %@\n\nThe iOS Simulator doesn't support the Neural Engine needed for image classification. Please test on a physical iPhone or iPad.", error.localizedDescription];
                reject(@"simulator_not_supported", errorMessage, error);
#else
                reject(@"classification_failed", error.localizedDescription, error);
#endif
                return;
            }
            
            NSLog(@"[ImageDescription] Vision request completed successfully");
            
            // Process results
            NSArray<VNClassificationObservation *> *observations = request.results;
            NSLog(@"[ImageDescription] Total observations returned: %lu", (unsigned long)observations.count);
            
            NSMutableArray *filteredLabels = [NSMutableArray array];
            
            for (VNClassificationObservation *observation in observations) {
                // Apply filters
                BOOL meetsThreshold = YES;
                
                // Check minimum confidence
                if (observation.confidence < minimumConfidence) {
                    continue;
                }
                
                // Check precision/recall thresholds
                if ([observation respondsToSelector:@selector(hasMinimumPrecision:forRecall:)]) {
                    meetsThreshold = [observation hasMinimumPrecision:minimumPrecision forRecall:recallThreshold];
                }
                
                if (meetsThreshold) {
                    NSDictionary *label = @{
                        @"identifier": observation.identifier,
                        @"confidence": @(observation.confidence)
                    };
                    [filteredLabels addObject:label];
                    NSLog(@"[ImageDescription] Added label: %@ (confidence: %.3f)", observation.identifier, observation.confidence);
                }
                
                // Check max results
                if (maxResults > 0 && filteredLabels.count >= maxResults) {
                    break;
                }
            }
            
            NSLog(@"[ImageDescription] Filtered labels count: %lu", (unsigned long)filteredLabels.count);
            
            // Return result
            NSDictionary *result = @{
                @"success": @YES,
                @"labels": filteredLabels
            };
            
            NSLog(@"[ImageDescription] Returning success result with %lu labels", (unsigned long)filteredLabels.count);
            resolve(result);
            
        } else {
            NSLog(@"[ImageDescription] ERROR: iOS version < 15.0");
            reject(@"unsupported_version", @"iOS 15.0 or later is required for image classification", nil);
        }
    } @catch (NSException *exception) {
        NSLog(@"[ImageDescription] EXCEPTION caught: %@", exception.reason);
        NSLog(@"[ImageDescription] Exception stack: %@", exception.callStackSymbols);
        reject(@"exception", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(describeImage:(NSString *)imageUri
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[ImageDescription] describeImage called (not supported on iOS)");
    // Image description is not supported on iOS
    NSDictionary *result = @{
        @"success": @NO,
        @"description": @"",
        @"error": @"Image description is not available on iOS. Use classifyImage() for classification labels.",
        @"modelStatus": @"not_supported"
    };
    resolve(result);
}

RCT_EXPORT_METHOD(checkDescriptionModelStatus:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[ImageDescription] checkDescriptionModelStatus called (not supported on iOS)");
    // Not supported on iOS
    resolve(@"not_supported");
}

RCT_EXPORT_METHOD(downloadDescriptionModel:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[ImageDescription] downloadDescriptionModel called (not supported on iOS)");
    // Not supported on iOS
    resolve(@NO);
}

RCT_EXPORT_METHOD(isAvailable:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[ImageDescription] isAvailable called");
    if (@available(iOS 15.0, *)) {
        NSLog(@"[ImageDescription] iOS 15.0+ available - returning YES");
        resolve(@YES);
    } else {
        NSLog(@"[ImageDescription] iOS version < 15.0 - returning NO");
        resolve(@NO);
    }
}

#pragma mark - Helper Methods

- (NSURL *)urlFromImageUri:(NSString *)imageUri
{
    if ([imageUri hasPrefix:@"file://"]) {
        return [NSURL URLWithString:imageUri];
    } else {
        return [NSURL fileURLWithPath:imageUri];
    }
}

@end

