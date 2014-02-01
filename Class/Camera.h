
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface Camera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (strong, nonatomic) id delegate;
@property (weak,   nonatomic) UIView *frontCamView;

- (id)init;
- (void)setupSession;

@end

@protocol CameraDelegate
-(void)faceIsApprochingAtPosition:(float)centerDelta width:(float)faceWidth;
-(void)faceComesIn;
-(void)faceWentOut;
@end
