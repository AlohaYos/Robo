
#import "ViewController.h"

@interface ViewController () 

@property (strong, nonatomic) PhaseControll *phaseCtrl;
@property (weak,   nonatomic) IBOutlet UIView *frontCamView;

@end


@implementation ViewController


#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

	_phaseCtrl = [[PhaseControll alloc] init];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

	[_phaseCtrl setupCameraSessionWithView:_frontCamView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end


