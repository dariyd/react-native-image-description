#import "ImageDescriptionModule.h"
#import <React/RCTLog.h>
#import <Vision/Vision.h>
#import <UIKit/UIKit.h>

// ML Kit - use traditional imports (more reliable with CocoaPods)
@import MLKitImageLabeling;
@import MLKitVision;
@import MLKitCommon;
@import MLKitImageLabelingCommon;

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
            
            // Process Vision results
            NSArray<VNClassificationObservation *> *observations = request.results;
            NSLog(@"[ImageDescription] Vision: Total observations returned: %lu", (unsigned long)observations.count);
            
            // Store Vision labels in a dictionary for merging
            NSMutableDictionary<NSString *, NSNumber *> *labelsDict = [NSMutableDictionary dictionary];
            
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
                    labelsDict[observation.identifier] = @(observation.confidence);
                    NSLog(@"[ImageDescription] Vision label: %@ (confidence: %.3f)", observation.identifier, observation.confidence);
                }
            }
            
            NSLog(@"[ImageDescription] Vision filtered labels count: %lu", (unsigned long)labelsDict.count);

            // iOS option: include Google ML Kit results (default: YES)
            BOOL iosUseMlKit = YES;
            NSNumber *iosUseMlKitOpt = options[@"iosUseMlKit"];
            if (iosUseMlKitOpt != nil) {
                iosUseMlKit = [iosUseMlKitOpt boolValue];
            }

            if (iosUseMlKit) {
                // Now run ML Kit Image Labeling
                NSLog(@"[ImageDescription] Starting ML Kit Image Labeling (iosUseMlKit=true)...");
                MLKVisionImage *mlkitImage = [[MLKVisionImage alloc] initWithImage:image];
                mlkitImage.orientation = image.imageOrientation;
                
                MLKImageLabelerOptions *mlkitOptions = [[MLKImageLabelerOptions alloc] init];
                mlkitOptions.confidenceThreshold = @(minimumConfidence);
                
                MLKImageLabeler *labeler = [MLKImageLabeler imageLabelerWithOptions:mlkitOptions];
                
                NSError *mlkitError = nil;
                NSArray<MLKImageLabel *> *mlkitLabels = [labeler resultsInImage:mlkitImage error:&mlkitError];
                
                if (mlkitError) {
                    NSLog(@"[ImageDescription] WARNING: ML Kit labeling failed - %@", mlkitError.localizedDescription);
                    NSLog(@"[ImageDescription] Continuing with Vision results only");
                } else {
                    NSLog(@"[ImageDescription] ML Kit: Total labels returned: %lu", (unsigned long)mlkitLabels.count);
                    
                    // Merge ML Kit results
                    for (MLKImageLabel *mlkitLabel in mlkitLabels) {
                        NSString *identifier = mlkitLabel.text;
                        float confidence = mlkitLabel.confidence;
                        
                        // Check if we already have this label from Vision
                        NSNumber *existingConfidence = labelsDict[identifier];
                        if (existingConfidence) {
                            // Keep the higher confidence score
                            if (confidence > existingConfidence.floatValue) {
                                labelsDict[identifier] = @(confidence);
                                NSLog(@"[ImageDescription] Updated label: %@ (ML Kit confidence: %.3f > Vision: %.3f)", 
                                      identifier, confidence, existingConfidence.floatValue);
                            } else {
                                NSLog(@"[ImageDescription] Kept label: %@ (Vision confidence: %.3f > ML Kit: %.3f)", 
                                      identifier, existingConfidence.floatValue, confidence);
                            }
                        } else {
                            // New label from ML Kit
                            labelsDict[identifier] = @(confidence);
                            NSLog(@"[ImageDescription] ML Kit label: %@ (confidence: %.3f)", identifier, confidence);
                        }
                    }
                }
            } else {
                NSLog(@"[ImageDescription] Skipping ML Kit labeling (iosUseMlKit=false) - using Vision results only");
            }
            
            NSLog(@"[ImageDescription] Combined labels count: %lu", (unsigned long)labelsDict.count);
            
            // Convert dictionary to array and sort by confidence
            NSMutableArray *finalLabels = [NSMutableArray array];
            [labelsDict enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSNumber *confidence, BOOL *stop) {
                NSDictionary *label = @{
                    @"identifier": identifier,
                    @"confidence": confidence
                };
                [finalLabels addObject:label];
            }];
            
            // Sort by confidence (descending)
            [finalLabels sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                float confA = [a[@"confidence"] floatValue];
                float confB = [b[@"confidence"] floatValue];
                if (confA > confB) return NSOrderedAscending;
                if (confA < confB) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            
            // Apply max results limit
            if (maxResults > 0 && finalLabels.count > maxResults) {
                finalLabels = [[finalLabels subarrayWithRange:NSMakeRange(0, maxResults)] mutableCopy];
            }
            
            NSLog(@"[ImageDescription] Final labels count (after limit): %lu", (unsigned long)finalLabels.count);
            
            // Return result
            NSDictionary *result = @{
                @"success": @YES,
                @"labels": finalLabels
            };
            
            NSString *sourceSummary = iosUseMlKit ? @"Vision and ML Kit" : @"Vision";
            NSLog(@"[ImageDescription] Returning success result with %lu labels from %@", (unsigned long)finalLabels.count, sourceSummary);
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

