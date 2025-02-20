#import <Foundation/Foundation.h>
#import "Tool.h"
#import <UIKit/UIKit.h>  
  
@interface ToolsManager : NSObject
  
- (NSArray<Tool *> *)getTools;
- (instancetype)initWithView:(UIView *)view;
- (NSString *)openCamera;
- (NSString *)closeCamera;
- (NSString *)takePhoto;
- (NSString *)uploadImageToAzureBlob:(NSData *)imageData error:(NSError **)error;
@property UIImage *capturedImage;
  
@end
