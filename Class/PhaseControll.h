
#import <Foundation/Foundation.h>
#import "Bluetooth.h"
#import "Camera.h"
#import "Motor.h"

@interface PhaseControll : NSObject <CameraDelegate>

-(id)init;
-(void)setupCameraSessionWithView:(UIView*)cameraView;

@end


