
#import "Motor.h"
#import "Konashi.h"
#import "PhaseControll.h"

								// モーター駆動基板
#define MOTOR_MOVE_FREE		0		// フリーコマンド
#define MOTOR_MOVE_FWD		1		// 前進コマンド
#define MOTOR_MOVE_BACK		2		// 後退コマンド
#define MOTOR_MOVE_STOP		3		// 停止コマンド

									// コントロールレジスタ
#define MOTOR_01_CTRL		0b1100000	// 基板のアドレス
#define MOTOR_CMD_INTERVAL	0.05	// コマンド送信のインターバル
#define MOTOR_SPEED			0x14	// モーターのスピード設定電圧（1.61V）

@interface Motor ()

@end


@implementation Motor

- (id)init {

	[self stop];
	return self;
}

#pragma mark - Motor switching

- (void)stop {
	NSLog(@"motor:ストップ");
	[self moveMotor0:0 motor1:0];
}
- (void)forward {
	NSLog(@"motor:前進");
	[self moveMotor0:MOTOR_SPEED motor1:MOTOR_SPEED];
}
- (void)backward {
	NSLog(@"motor:後退");
	[self moveMotor0:-MOTOR_SPEED motor1:-MOTOR_SPEED];
}
- (void)leftSlow {
	NSLog(@"motor:左折スロー");
	[self moveMotor0:MOTOR_SPEED motor1:MOTOR_SPEED-3];
}
- (void)rightSlow {
	NSLog(@"motor:右折スロー");
	[self moveMotor0:MOTOR_SPEED-3 motor1:MOTOR_SPEED];
}

#pragma mark - Motor control

// 左右のモーターをコントロール
- (void)moveMotor0:(int)speed0 motor1:(int)speed1 {
	
	unsigned char command0, command1;
	
	// モーター駆動基板のコマンドに変換する
	if(speed0 == 0) {
		command0 = MOTOR_MOVE_STOP;
	}
	else if(speed0 < 0){
		speed0 = -speed0;
		command0 = MOTOR_MOVE_BACK;
	}
	else {
		command0 = MOTOR_MOVE_FWD;
	}
	if(speed1 == 0) {
		command1 = MOTOR_MOVE_STOP;
	}
	else if(speed1 < 0){
		speed1 = -speed1;
		command1 = MOTOR_MOVE_BACK;
	}
	else {
		command1 = MOTOR_MOVE_FWD;
	}
	
	command0 = (speed0<<2)+command0;
	command1 = (speed1<<2)+command1;

	// 左右それぞれのコマンドを送信
	[self writeCtrl:command0 motorAddress:MOTOR_01_CTRL+0];
	[self writeCtrl:command1 motorAddress:MOTOR_01_CTRL+1];
}

// I2Cプロトコルを使って、Konashiからモーター駆動基板に動作コマンドを送る
- (void) writeCtrl:(unsigned char)ctrlValue motorAddress:(unsigned char)adrs
{
	// コントロールレジスタにコマンドを設定
    unsigned char t[2];
    t[0] = 0;
    t[1] = ctrlValue;
	
	// I2Cプロトコルに合わせてコマンド列を送信
    [NSThread sleepForTimeInterval:MOTOR_CMD_INTERVAL];
    [Konashi i2cStartCondition];
    [NSThread sleepForTimeInterval:MOTOR_CMD_INTERVAL];
    int ret = [Konashi i2cWrite:2 data:t address:adrs];
	if(ret != 0) {
		NSLog(@"i2cWrite(%02x,%02x) ret=%d", (int)ctrlValue, (int)adrs, ret);
	}
    [NSThread sleepForTimeInterval:MOTOR_CMD_INTERVAL];
    [Konashi i2cStopCondition];
    [NSThread sleepForTimeInterval:MOTOR_CMD_INTERVAL];
}

@end
