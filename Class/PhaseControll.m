
#import "PhaseControll.h"

#define FACE_WIDTH_NEAR			0.4		// 近づいたことを判断する顔の横幅（カメラフレームの横幅を1.0とした場合の比率）
#define FACE_WIDTH_TOO_CLOSE	0.6		// 近づきすぎたことを判断する顔の横幅
#define NEARBY_CENTER_DIFF		0.10	// カメラフレームの中央から顔が左右に振れた場合に、そちらに向き直る

typedef enum {	// ロボットの動作状況
	phaseWaitingForFace=0,	// 顔が現れるのを待っている
	phaseChasingFace,		// 顔を追い掛けている
	phaseApprochingToFace,	// 顔に近づいている
} RoboPhase;

typedef enum {	// 発生したイベント
	eventFaceComesIn=0,		// 顔が出現した
	eventFaceWentOut,		// 顔を見失った
	eventFaceIsNear,		// 顔が接近した
	eventFaceIsNotNear,		// 顔が遠ざかった
} RoboEvent;


@interface PhaseControll ()

@property (strong, nonatomic)	Bluetooth *ble;		// KONASHIと接続するためのオブジェクト
@property (strong, nonatomic)	Camera *camera;		// 顔認識するためのカメラオブジェクト
@property (strong, nonatomic)	Motor *motor;		// モーターを操作して走り回るためのオブジェクト

@property (nonatomic)	int		phase;				// ロボットの動作状況
@property (nonatomic)	BOOL	faceOnVideo;		// 顔が表示されているか
@property (nonatomic)	BOOL	followingFace;		// 顔を追い掛けているか
@property (nonatomic)	float	lastFaceCenterX;	// カメラ上の顔の位置　 : カメラ画面の中心を原点、幅を1.0とした時のX位置（-0.5から+0.5の範囲）
@property (nonatomic)	float	lastFaceWidth;		// カメラ上の顔の大きさ : カメラ画面の幅を1.0とした時の顔の幅

@end

@implementation PhaseControll

-(id)init {
	
	_ble    = [[Bluetooth alloc] init];
	[_ble autoFind];
	
	_camera = [[Camera alloc] init];
	_camera.delegate = self;

	_motor  = [[Motor alloc] init];
	_motor.delegate = self;
	
	_faceOnVideo = NO;
	_followingFace = YES;
	[self setPhase:phaseWaitingForFace];
	
	[NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(timerJob) userInfo:nil repeats:YES];
	
	return self;
}

#pragma mark - General timer job

-(void)timerJob {
	
	static unsigned long faceLostCount = 0;		// 顔認識のチャタリングを防ぐためのカウンター
	
	if(_faceOnVideo == NO)
		faceLostCount++;
	else
		faceLostCount = 0;
	
	if(faceLostCount == 5) {
		[self setEvent:eventFaceWentOut];	// 顔を見失った
	}

	// 顔を追い掛ける動作
	switch (_phase) {
		// 顔が現れるのを待っている状態では
		case phaseWaitingForFace:
			// 何もしない
			break;
		// 顔を追い掛けている状態では
		case phaseChasingFace:
			// 顔がまだ遠くにある場合はモーターを前進させる
			if(_lastFaceWidth < FACE_WIDTH_NEAR) {
			//	[self setEvent:eventFaceIsNotNear];
				// 顔が画面の左側にある場合には、右斜め前に移動する
				if(_lastFaceCenterX < -NEARBY_CENTER_DIFF) {		// face is a little right side of Robo
					[_motor rightSlow];
				}
				// 顔が画面の右側にある場合には、左斜め前に移動する
				else if(_lastFaceCenterX > NEARBY_CENTER_DIFF) {	// face is a little left side of Robo
					[_motor leftSlow];
				}
				// 顔が正面にある場合には、前進する
				else {
					[_motor forward];
				}
			}
			// 顔が近づいた場合はモーターを停止する
			else {
				[self setEvent:eventFaceIsNear];
				[_motor stop];
			}
			break;
		// 顔に近づいている状態では
		case phaseApprochingToFace:
			// さらに顔が近づいた場合にはバックする
			if(_lastFaceWidth > FACE_WIDTH_TOO_CLOSE) {
				[_motor backward];
			}
			// 少し離れた場合には停止する
			if(_lastFaceWidth < FACE_WIDTH_NEAR) {
				[self setEvent:eventFaceIsNotNear];
				[_motor stop];
			}
			break;
	}
}

#pragma mark - Camera setup job

-(void)setupCameraSessionWithView:(UIView*)cameraView
{
	// カメラ映像を映し出すViewを設定して、セッションを開始する
	_camera.frontCamView = cameraView;
	[_camera setupSession];
}


#pragma mark - Camera delegate job

// カメラで認識された顔の位置と大きさについてコールバックされる
-(void)faceIsApprochingAtPosition:(float)centerDelta width:(float)faceWidth {
	// centerDelta : カメラ画面の中心を原点、幅を1.0とした時のX位置（-0.5から+0.5の範囲）
	// faceWidth   : カメラ画面の幅を1.0とした時の顔の幅
	_lastFaceCenterX = centerDelta;
	_lastFaceWidth = faceWidth;
}

// 顔がカメラに入ってきた時にコールバックされる
-(void)faceComesIn {
	_faceOnVideo = YES;
	[self setEvent:eventFaceComesIn];
}

// 顔がカメラから出ていった時にコールバックされる
-(void)faceWentOut {
	_faceOnVideo = NO;
	[self setEvent:eventFaceWentOut];
}


#pragma mark - Request dispatch

// ロボットの動作状態を変更する
-(void)setPhase:(int)phase {
	_phase = phase;
	
	switch (_phase) {
		case phaseWaitingForFace:	// 顔が現れるのを待つ
			[_motor stop];
			break;
		case phaseChasingFace:		// 顔認識しながら追跡する
			[_motor stop];
			break;
		case phaseApprochingToFace:	// 停止する
			[_motor stop];
			break;
	}
}

// 発生したイベントによってロボットの動作状態を変更する
-(void)setEvent:(int)event {

	switch (_phase) {
		case phaseWaitingForFace:	// 顔が現れるのを待っている状態
			switch (event) {
				case eventFaceComesIn:	// 顔が出現したら
					[self setPhase:phaseChasingFace];	// 顔を追い掛ける
					break;
			}
			break;
		case phaseChasingFace:		// 顔を見つけて追い掛けている状態
			switch (event) {
				case eventFaceIsNear:	// 顔が接近したら
					[self setPhase:phaseApprochingToFace];	// 接近した状態に移行
					break;
				case eventFaceWentOut:	// 顔を見失ったら
					[self setPhase:phaseWaitingForFace];	// 顔が現れるのを待つ
					break;
			}
			break;
		case phaseApprochingToFace:	// 顔に接近した状態
			switch (event) {
				case eventFaceWentOut:	// 顔を見失ったら
					[self setPhase:phaseWaitingForFace];	// 顔が洗われるのを待つ
					break;
				case eventFaceIsNotNear:	// 顔が遠ざかったら
					[self setPhase:phaseChasingFace];		// 顔を追い掛ける
					break;
			}
			break;
	}
}

@end
