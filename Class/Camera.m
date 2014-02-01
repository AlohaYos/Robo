
#import "Camera.h"

@interface Camera ()

@property (nonatomic, strong)AVCaptureSession			*frontCamSession;
@property (nonatomic, strong)AVCaptureMetadataOutput	*metadataOutput;
@property (nonatomic, strong)AVCaptureVideoPreviewLayer	*frontCamLayer;
@property (nonatomic, strong)UIImage					*faceSquare;

@property (nonatomic) NSTimer	*timer;
@property (nonatomic) BOOL		faceFound;
@property (nonatomic) BOOL		faceFoundLastTime;

@end

@implementation Camera

#pragma mark - AVFoundation sessions

- (id)init {
	
	// 顔認識結果のフラグをオフ
	_faceFound = NO;
	_faceFoundLastTime = NO;
	
	// 顔の位置を示すための四角形の画像を用意
	_faceSquare = [UIImage imageNamed:@"faceSquare"];
	
	return self;
}

-(void)dealloc {
	
    [_frontCamSession stopRunning];
}

- (void)setupSession
{
    // フロントカメラのビデオキャプチャを準備
    _frontCamSession = [[AVCaptureSession alloc] init];
    [_frontCamSession setSessionPreset:AVCaptureSessionPresetMedium];
	
	for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == AVCaptureDevicePositionFront) {
			AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:d error:nil];
			if ([_frontCamSession canAddInput:input]) {
				[_frontCamSession addInput:input];
			}
			break;
		}
	}
	
    // カメラから取り込んだビデオデータを即時プレビューするレイヤーを準備
    _frontCamLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_frontCamSession];
	_frontCamLayer.frame = _frontCamView.bounds;
    _frontCamLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_frontCamView.layer addSublayer:_frontCamLayer];
	
	// 顔認識用のMetadataOutputを準備
	_metadataOutput = [AVCaptureMetadataOutput new];
	[_metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
	[_frontCamSession addOutput:_metadataOutput];
	_metadataOutput.metadataObjectTypes = @[ AVMetadataObjectTypeFace ];	// 顔認識

	// セッションを開始
	[_frontCamSession startRunning];
	
	// 顔の出現/消失をチェックするタイマー処理
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerJob) userInfo:nil repeats:YES];
}


#pragma mark - Face detect job

// ビデオで顔を認識した場合にコールバックされる
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {

	// Viewへのフィードバックを行うために、メインスレッドで処理する
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self drawFaceBoxesForFeatures:metadataObjects];
	});
}

// 顔認識した部分に四角形の画像を表示する（顔を四角形が追い掛ける）
- (void)drawFaceBoxesForFeatures:(NSArray *)metadataObjects
{
	int faceCount = 0;
	float largeFaceCenterX = 0;
	float largeFaceWidth = 0;
	
	NSArray *sublayers = [NSArray arrayWithArray:[_frontCamLayer sublayers]];
	NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
	NSInteger featuresCount = [metadataObjects count];
	//NSInteger currentFeature = 0;
	
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];

	// 前回に表示した四角形を隠す
	for (CALayer *layer in sublayers) {
		if ( [[layer name] isEqualToString:@"FaceLayer"] )
			[layer setHidden:YES];
	}
	
	// 検出したオブジェクトの数がゼロなら処理しない
	if (featuresCount == 0) {
		[CATransaction commit];
		return; // early bail.
	}
	
	// 検出した全てのオブジェクトについて
	for(AVMetadataFaceObject *obj in metadataObjects) {
		
		// 顔認識についてのみ処理する
		if(![obj.type isEqualToString:AVMetadataObjectTypeFace])
			continue;
		
		faceCount++;
		
		// 顔の大きさを取得
		AVMetadataObject *tobj;
		tobj = [_frontCamLayer transformedMetadataObjectForMetadataObject:obj];
		CGRect faceRect = tobj.bounds;
		
		// 検出した中で一番大きな顔ならば
		if(faceRect.size.width > largeFaceWidth) {
			largeFaceCenterX = (faceRect.origin.x+faceRect.size.width/2) / _frontCamView.bounds.size.width;
			largeFaceCenterX -= 0.5;
			largeFaceWidth = faceRect.size.width / _frontCamView.frame.size.width;
			
			// 顔の位置と大きさをフェーズコントローラにコールバック
			[_delegate faceIsApprochingAtPosition:largeFaceCenterX width:largeFaceWidth];
			
		}
		
		// カメラビューのサブビューから "FaceLayer" を探す
		CALayer *featureLayer = nil;
		while ( !featureLayer && (currentSublayer < sublayersCount) ) {
			CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
			if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
				featureLayer = currentLayer;
				[currentLayer setHidden:NO];
			}
		}
		// 存在しない場合には新しい "FaceLayer" を追加する
		if ( !featureLayer ) {
			featureLayer = [CALayer new];
			[featureLayer setContents:(id)[_faceSquare CGImage]];
			[featureLayer setName:@"FaceLayer"];
			[_frontCamLayer addSublayer:featureLayer];
		}
		
		// "FaceLayer" に四角形を描画
		[featureLayer setFrame:faceRect];
		
	//	currentFeature++;
	}
	
	// 顔検出フラグをオン
	if(faceCount > 0)
		_faceFound = YES;
	
	[CATransaction commit];
}

#pragma mark - Timer Job

// 顔の出現/消失をチェックするタイマー処理
-(void)timerJob {
	
	if((_faceFoundLastTime == YES)&&(_faceFound == NO))	{	// 顔を見失った
		[_delegate faceWentOut];
	}
	if((_faceFoundLastTime == NO)&&(_faceFound == YES)) {	// 顔が現れた
		[_delegate faceComesIn];
	}
	_faceFoundLastTime = _faceFound;
	_faceFound = NO;
}


@end
