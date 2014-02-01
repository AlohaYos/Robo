
#import <Foundation/Foundation.h>

@interface Motor : NSObject

@property (weak, nonatomic)	id delegate;

- (id)init;
- (void)stop;
- (void)forward;
- (void)backward;
- (void)leftSlow;
- (void)rightSlow;

@end
