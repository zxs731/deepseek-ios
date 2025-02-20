#import "ToolsManager.h"
#import <AVFoundation/AVFoundation.h>


  
@interface ToolsManager () <AVCapturePhotoCaptureDelegate>
  
@property (nonatomic, strong) UIView *view;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, copy) void (^photoCompletionHandler)(UIImage *image, NSError *error);

  
@end
@implementation ToolsManager

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if (self) {
        _view = view;
    }
    return self;
}

- (NSString *)currentDatetime {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
    [dateFormatter setDateFormat:@"yyyy年MM月dd日 EEEE HH时mm分ss秒"];
    NSString *currentDateTime = [dateFormatter stringFromDate:[NSDate date]];
    NSLog(@"currentDatetime: %@", currentDateTime);
    return currentDateTime;
}
  
- (NSArray<Tool *> *)getTools {
    NSDictionary *functionDescription = @{
        @"name": @"currentDatetime",
        @"description": @"获取现在的日期和时间",
        @"parameters": @{
            @"type": @"object",
            @"properties": @{},
            @"required": @[]
        }
    };
      
    Tool *currentDatetimeTool = [[Tool alloc] initWithType:@"function" function:functionDescription];
    NSDictionary *openCameraDescription = @{
        @"name": @"openCamera",
        @"description": @"打开视觉系统",
        @"parameters": @{
            @"type": @"object",
            @"properties": @{},
            @"required": @[]
        }
    };
    Tool *openCameraTool = [[Tool alloc] initWithType:@"function" function:openCameraDescription];
    
    NSDictionary *closeCameraDescription = @{
        @"name": @"closeCamera",
        @"description": @"关闭视觉",
        @"parameters": @{
            @"type": @"object",
            @"properties": @{},
            @"required": @[]
        }
    };
    Tool *closeCameraTool = [[Tool alloc] initWithType:@"function" function:closeCameraDescription];
    
    NSDictionary *takePhotoDescription = @{
        @"name": @"takePhoto",
        @"description": @"拍照并采集",
        @"parameters": @{
            @"type": @"object",
            @"properties": @{},
            @"required": @[]
        }
    };
    Tool *takePhotoTool = [[Tool alloc] initWithType:@"function" function:takePhotoDescription];
    return @[currentDatetimeTool,openCameraTool,closeCameraTool,takePhotoTool];
}
- (NSString *)openCamera {
    __block NSString *result = @"打开摄像头失败！";
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
      
    dispatch_async(dispatch_get_main_queue(), ^{
        // 创建捕捉会话
        self.session = [[AVCaptureSession alloc] init];
          
        // 设置输入设备为默认的摄像头
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
          
        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (!input) {
            NSLog(@"Error: %@", error.localizedDescription);
            result = @"没有找到摄像头！";
            dispatch_semaphore_signal(semaphore);
            return;
        }
          
        [self.session addInput:input];
          
        // 创建预览图层
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.previewLayer.frame = self.view.bounds;
          
        [self.view.layer addSublayer:self.previewLayer];
        // 设置输出
        AVCapturePhotoOutput *output = [[AVCapturePhotoOutput alloc] init];
        if ([self.session canAddOutput:output]) {
            [self.session addOutput:output];
        }
        // 开始捕捉会话
        [self.session startRunning];
        self.photoOutput = output;
        
        // 开始捕捉会话
        [self.session startRunning];
        result = @"视觉已打开！";
        dispatch_semaphore_signal(semaphore);
    });
      
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return result;
}
  
- (NSString *)closeCamera {
    __block NSString *result = @"关闭摄像头失败！";
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
      
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.session) {
            [self.session stopRunning];
            self.session = nil;
        }
          
        if (self.previewLayer) {
            [self.previewLayer removeFromSuperlayer];
            self.previewLayer = nil;
        }
          
        result = @"关闭了视觉采集。";
        dispatch_semaphore_signal(semaphore);
    });
      
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return result;
}
- (NSArray *)takePhoto {
    self.capturedImage = [self takePhoto2];
    [self closeCamera];
    return @"视觉信息已采集！";
}
- (UIImage *)takePhoto2 {
    __block UIImage *capturedImage = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  
    dispatch_async(dispatch_get_main_queue(), ^{
        AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
        if ([self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeJPEG]) {
                    settings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecTypeJPEG}];
                }  
        NSLog(@"==capturePhotoWithSettings=================================");
        [self.photoOutput capturePhotoWithSettings:settings delegate:self];
        NSLog(@"==photoCompletionHandler=================================");
        self.photoCompletionHandler = ^(UIImage *image, NSError *error) {
            capturedImage = image;
            NSLog(@"==dispatch_semaphore_signal=================================");
            dispatch_semaphore_signal(semaphore);
        };
    });
  
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return capturedImage;
}
- (NSData *)resizeAndCompressImage:(UIImage *)image compressionQuality:(CGFloat)compressionQuality {
    // 计算新的尺寸（宽度和高度都减半）
    CGSize newSize = CGSizeMake(image.size.width / 2, image.size.height / 2);
  
    // 创建一个新的图像上下文
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
  
    // 在新的尺寸下绘制原始图像
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
  
    // 获取调整尺寸后的图像
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
  
    // 结束图像上下文
    UIGraphicsEndImageContext();
  
    // 压缩调整尺寸后的图像
    NSData *imageData = UIImageJPEGRepresentation(resizedImage, compressionQuality);
  
    return imageData;
}
// 上传图像到 Azure Storage Blob 并返回 URL
- (NSString *)uploadImageToAzureBlob:(NSData *)imageData error:(NSError **)error {
    // 创建连接字符串
    NSString *sasToken = @"sv=2022-11-02&ss=bfqt&srt=sco&sp=rwdlacupiytfx&se=2024-06-22T07:23:36Z&st=2024-06-21T23:23:36Z&spr=https&sig=hpLDfMEUVEbhRBAtS8FKrYs4WeoP6VAzPXv8JovsmjA%3D";
    NSString *blobEndpoint = @"https://chatimg0622.blob.core.windows.net/";
    NSString *containerName = @"img";
  
    // 创建 blob 名称
    NSString *blobName = [NSString stringWithFormat:@"%@.jpg", [[NSUUID UUID] UUIDString]];
  
    // 创建上传 URL
    NSString *uploadUrlString = [NSString stringWithFormat:@"%@%@/%@?%@", blobEndpoint, containerName, blobName, sasToken];
    NSURL *uploadUrl = [NSURL URLWithString:uploadUrlString];
  
    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uploadUrl];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"BlockBlob" forHTTPHeaderField:@"x-ms-blob-type"];
    [request setValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:imageData];
  
    // 创建信号量
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  
    __block NSString *resultUrl = nil;
    __block NSError *uploadError = nil;
  
    //NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSLog(@"dataTask");
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"completionHandler");
        if (error) {
            uploadError = error;
            NSLog(@"%@", uploadError);
        } else {
            // 检查 HTTP 响应代码
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 201) { // HTTP 201 Created
                // 构建图片 URL
                resultUrl = [NSString stringWithFormat:@"%@?%@", [NSString stringWithFormat:@"%@%@/%@", blobEndpoint, containerName, blobName],sasToken];
            } else {
                // 处理非成功状态码
                NSString *errorMessage = [NSString stringWithFormat:@"上传失败，状态码: %ld", (long)httpResponse.statusCode];
                uploadError = [NSError errorWithDomain:@"AzureBlobUpload" code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
            }
        }
        // 发送信号，表示任务完成
        dispatch_semaphore_signal(semaphore);
    }];
     
       // 启动上传任务
       [dataTask resume];
    NSLog(@"dataTask resume");
       // 等待任务完成
       dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"after dispatch_semaphore_wait");
       // 检查是否有错误
       if (uploadError && error) {
           *error = uploadError;
       }
       NSLog(@"upload photo url: %@",  resultUrl);
       return resultUrl;
   }
#pragma mark - AVCapturePhotoCaptureDelegate
  
- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishProcessingPhoto:(AVCapturePhoto *)photo
                       error:(NSError *)error {
    if (error) {
        NSLog(@"Error capturing photo: %@", error.localizedDescription);
        if (self.photoCompletionHandler) {
            self.photoCompletionHandler(nil, error);
        }
        return;
    }
      
    NSData *imageData = [photo fileDataRepresentation];
    UIImage *image = [UIImage imageWithData:imageData];
      
    if (self.photoCompletionHandler) {
        self.photoCompletionHandler(image, nil);
    }
}
@end
