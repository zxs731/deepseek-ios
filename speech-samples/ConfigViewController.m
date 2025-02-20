#import "ConfigViewController.h"
#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import <MicrosoftCognitiveServicesSpeech/SPXSpeechApi.h>

@interface ConfigViewController ()
@property (nonatomic, strong) UITextField *deepseekKeyField;
@property (nonatomic, strong) UITextField *azureSpeechKeyField;
@property (nonatomic, strong) UITextField *azureSpeechRegionField;
@end


@implementation ConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.deepseekKeyField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, 300, 40)];
    self.deepseekKeyField.placeholder = @"Deepseek Key";
    self.deepseekKeyField.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:self.deepseekKeyField];
    
    self.azureSpeechKeyField = [[UITextField alloc] initWithFrame:CGRectMake(20, 160, 300, 40)];
    self.azureSpeechKeyField.placeholder = @"Azure Speech Key";
    self.azureSpeechKeyField.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:self.azureSpeechKeyField];
    
    self.azureSpeechRegionField = [[UITextField alloc] initWithFrame:CGRectMake(20, 220, 300, 40)];
    self.azureSpeechRegionField.placeholder = @"Azure Speech Region";
    self.azureSpeechRegionField.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:self.azureSpeechRegionField];
    
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveButton.frame = CGRectMake(20, 280, 300, 40);
    [saveButton setTitle:@"Save" forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(saveConfiguration) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:saveButton];
}

- (void)saveConfiguration {
    NSString *deepseekKey = self.deepseekKeyField.text;
    NSString *azureSpeechKey = self.azureSpeechKeyField.text;
    NSString *azureSpeechRegion = self.azureSpeechRegionField.text;
    
    [[NSUserDefaults standardUserDefaults] setObject:deepseekKey forKey:@"DeepseekKey"];
    [[NSUserDefaults standardUserDefaults] setObject:azureSpeechKey forKey:@"AzureSpeechKey"];
    [[NSUserDefaults standardUserDefaults] setObject:azureSpeechRegion forKey:@"AzureSpeechRegion"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // 重新初始化 App
    bool valid=[self validateAzureSpeechKey:azureSpeechKey region:azureSpeechRegion];
    if(!valid){
        return;
    }else{
        [self.navigationController popViewControllerAnimated:YES];
    }
    
    //
}
- (bool)validateAzureSpeechKey:(NSString *)key region:(NSString *)region {
    @try {
        // 初始化语音配置
        SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:key region:region];
        if (!speechConfig) {
            NSLog(@"Failed to initialize speech configuration.");
            return false;
        }
        
        // 尝试初始化语音识别器
        SPXSpeechRecognizer* speechRecognizer = [[SPXSpeechRecognizer alloc]
                                                 init:speechConfig];
        if (!speechRecognizer) {
            NSLog(@"Failed to initialize speech recognizer.");
            return false;
        }
        
        NSLog(@"Azure Speech Key and Region are valid.");
        return true;
    }
    @catch (NSException *exception) {
        NSLog(@"Exception: %@", exception);
        NSLog(@"Reason: %@", exception.reason);
        NSLog(@"Azure Speech Key or Region is invalid.");
        return false;
    }
}
@end
