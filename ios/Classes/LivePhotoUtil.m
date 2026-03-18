#import "live_photo_plugin-Swift.h"
#import "LivePhotoUtil.h"
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>

@implementation LivePhotoUtil

+ (void)convertVideo:(NSString *)path complete:(void(^)(BOOL, NSString *))complete {
    NSBundle *pluginBundle = [NSBundle bundleForClass:NSClassFromString(@"LivePhotoPlugin")];
    NSURL *metaURL = [pluginBundle URLForResource:@"metadata" withExtension:@"mov"];

    if (!metaURL) {
        complete(NO, @"metadata.mov was not found in plugin bundle");
        return;
    }

    CGSize livePhotoSize = CGSizeMake(1080, 1920);
    CMTime livePhotoDuration = CMTimeMake(550, 600);
    NSString *assetIdentifier = NSUUID.UUID.UUIDString;

    NSString *tempDir = NSTemporaryDirectory();
    NSString *uuid = NSUUID.UUID.UUIDString;

    NSString *durationPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"duration_%@.mp4", uuid]];
    NSString *acceleratePath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"accelerate_%@.mp4", uuid]];
    NSString *resizePath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"resize_%@.mp4", uuid]];
    NSString *picturePath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"live_%@.heic", uuid]];
    NSString *videoPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"live_%@.mov", uuid]];

    [NSFileManager.defaultManager removeItemAtPath:durationPath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:acceleratePath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:resizePath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:picturePath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:videoPath error:nil];

    NSString *finalPath = resizePath;
    Converter4Video *converter = [[Converter4Video alloc] initWithPath:finalPath];

    [converter durationVideoAt:path outputPath:durationPath targetDuration:3 completion:^(BOOL success, NSError *error) {
        if (!success || error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                complete(NO, error.localizedDescription ?: @"Failed to adjust video duration");
            });
            return;
        }

        [converter accelerateVideoAt:durationPath to:livePhotoDuration outputPath:acceleratePath completion:^(BOOL success, NSError *error) {
            if (!success || error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(NO, error.localizedDescription ?: @"Failed to accelerate video");
                });
                return;
            }

            [converter resizeVideoAt:acceleratePath outputPath:resizePath outputSize:livePhotoSize completion:^(BOOL success, NSError *error) {
                if (!success || error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        complete(NO, error.localizedDescription ?: @"Failed to resize video");
                    });
                    return;
                }

                AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:finalPath] options:nil];
                AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
                generator.appliesPreferredTrackTransform = YES;
                generator.requestedTimeToleranceAfter = kCMTimeZero;
                generator.requestedTimeToleranceBefore = kCMTimeZero;

                NSMutableArray *times = [NSMutableArray array];
                CMTime time = CMTimeMakeWithSeconds(0.5, asset.duration.timescale);
                [times addObject:[NSValue valueWithCMTime:time]];

                dispatch_queue_t q = dispatch_queue_create("image", DISPATCH_QUEUE_SERIAL);
                __block BOOL didFinish = NO;

                [generator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
                    if (didFinish) {
                        return;
                    }

                    if (error) {
                        didFinish = YES;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            complete(NO, error.localizedDescription ?: @"Failed to generate preview image");
                        });
                        return;
                    }

                    if (!image) {
                        didFinish = YES;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            complete(NO, @"Failed to generate image from video");
                        });
                        return;
                    }

                    didFinish = YES;

                    Converter4Image *converter4Image = [[Converter4Image alloc] initWithImage:[UIImage imageWithCGImage:image]];

                    dispatch_async(q, ^{
                        [converter4Image writeWithDest:picturePath assetIdentifier:assetIdentifier];

                        [converter writeWithDest:videoPath assetIdentifier:assetIdentifier metaURL:metaURL completion:^(BOOL success, NSError *error) {
                            if (!success || error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    complete(NO, error.localizedDescription ?: @"Failed to write Live Photo video");
                                });
                                return;
                            }

                            [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
                                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                                NSURL *photoURL = [NSURL fileURLWithPath:picturePath];
                                NSURL *pairedVideoURL = [NSURL fileURLWithPath:videoPath];

                                [request addResourceWithType:PHAssetResourceTypePhoto fileURL:photoURL options:[PHAssetResourceCreationOptions new]];
                                [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:pairedVideoURL options:[PHAssetResourceCreationOptions new]];
                            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                                [NSFileManager.defaultManager removeItemAtPath:durationPath error:nil];
                                [NSFileManager.defaultManager removeItemAtPath:acceleratePath error:nil];
                                [NSFileManager.defaultManager removeItemAtPath:resizePath error:nil];
                                [NSFileManager.defaultManager removeItemAtPath:picturePath error:nil];
                                [NSFileManager.defaultManager removeItemAtPath:videoPath error:nil];

                                dispatch_async(dispatch_get_main_queue(), ^{
                                    complete(error == nil, error.localizedDescription);
                                });
                            }];
                        }];
                    });
                }];
            }];
        }];
    }];
}

@end
