//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for full license information.
//

#import "ViewController.h"
#import "AudioRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import <MicrosoftCognitiveServicesSpeech/SPXSpeechApi.h>
#import <Foundation/Foundation.h>
#import "ToolsManager.h"
#import "Tool.h"
#import "ConfigViewController.h"


@interface ViewController () <AVCapturePhotoCaptureDelegate>



@property (strong, nonatomic) IBOutlet UILabel *recognitionResultLabel;
@property (strong, nonatomic) IBOutlet UILabel *messageLabel;
@property ToolsManager *toolManager;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, copy) void (^photoCompletionHandler)(UIImage *image, NSError *error);
@property UIImage *capturedImage;
@end

@implementation ViewController
NSString *deepseekKey;
NSString *speechKey;
NSString *serviceRegion;
NSString *pronunciationAssessmentReferenceText;
bool isRunning;
AudioRecorder *recorder;


- (bool)validateAzureSpeechKey:(NSString *)key region:(NSString *)region {
    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:key region:region];
    speechConfig.speechRecognitionLanguage=@"zh-CN";
    speechConfig.speechSynthesisLanguage=@"zh-CN";
    if (!speechConfig) {
        NSLog(@"Could not load speech config");
        [self updateRecognitionErrorText:(@"Speech Config Error")];
        return FALSE;
    }
    NSArray *languages = @[@"en-US", @"zh-CN"];
    SPXAutoDetectSourceLanguageConfiguration *autoDetectConfig = [[SPXAutoDetectSourceLanguageConfiguration alloc] init:languages];
    [self updateRecognitionStatusText:(@"Validate...")];
    SPXSpeechRecognizer* speechRecognizer = [[SPXSpeechRecognizer alloc]
                                             init:speechConfig];
    if (!speechRecognizer) {
        NSLog(@"Could not create speech recognizer");
        [self updateRecognitionErrorText:(@"Speech Recognition Error")];
        return FALSE;
    }
    
    SPXSpeechRecognitionResult *speechResult = [speechRecognizer recognizeOnce];
    if (SPXResultReason_Canceled == speechResult.reason) {
        SPXCancellationDetails *details = [[SPXCancellationDetails alloc] initFromCanceledRecognitionResult:speechResult];
        NSLog(@"Speech recognition was canceled: %@. Did you pass the correct key/region combination?", details.errorDetails);
        return  FALSE;
    } else if (SPXResultReason_RecognizedSpeech == speechResult.reason) {
        NSLog(@"Speech recognition result received: %@", speechResult.text);
        return  TRUE;
        
    } else if (SPXResultReason_NoMatch == speechResult.reason) {
        NSLog(@"No match found.");
        return  TRUE;
        
    } else {
        NSLog(@"There was an error.");
        return  FALSE;
    }
    
}
- (void)openConfig {
    ConfigViewController *configVC = [[ConfigViewController alloc] init];
    [self.navigationController pushViewController:configVC animated:YES];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    deepseekKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DeepseekKey"];
    speechKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"AzureSpeechKey"];
    serviceRegion = [[NSUserDefaults standardUserDefaults] objectForKey:@"AzureSpeechRegion"];
    
    if (deepseekKey && speechKey && serviceRegion) {
        //NSLog(@"Deepseek Key: %@", deepseekKey);
        //NSLog(@"Azure Speech Key: %@", speechKey);
        //NSLog(@"Azure Speech Region: %@", serviceRegion);
        // Start keyword recognition
        bool valid=[self validateAzureSpeechKey:speechKey region:serviceRegion];
        if(valid){
            if(!isRunning){
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                    [self recognizeKeywordFromFile];
                });
                isRunning=TRUE;
            }
        }else{
            [self openConfig];
        }

        
        // 使用这些值进行后续操作
    } else {
        NSLog(@"Configuration not set.");
        [self openConfig];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    deepseekKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DeepseekKey"];
    speechKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"AzureSpeechKey"];
    serviceRegion = [[NSUserDefaults standardUserDefaults] objectForKey:@"AzureSpeechRegion"];
    
    
    
    // 添加“更多”按钮
    UIBarButtonItem *moreButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis"] style:UIBarButtonItemStylePlain target:self action:@selector(openConfig)];
    self.navigationItem.rightBarButtonItem = moreButton;
    
    pronunciationAssessmentReferenceText = @"Hello world.";

    // 创建新的UIScrollView
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
      
    // 创建新的UILabel
    self.messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel.textAlignment = NSTextAlignmentLeft; // 确保文本居中
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.accessibilityIdentifier = @"message_label";
    [self.messageLabel setText:@""];
    
    
    // 添加UILabel到UIScrollView
    [scrollView addSubview:self.messageLabel];
      
    // 添加UIScrollView到父视图
    [self.view addSubview:scrollView];
      
    // 创建UIScrollView的约束
    [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
      
    // 创建UILabel的约束
    [self.messageLabel.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor].active = YES;
    [self.messageLabel.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor].active = YES;
    [self.messageLabel.topAnchor constraintEqualToAnchor:scrollView.topAnchor].active = YES;
    [self.messageLabel.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor].active = YES;
    [self.messageLabel.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor].active = YES;
      
    // 强制布局以获取messageLabel的实际高度
    [scrollView layoutIfNeeded];
      
    // 获取messageLabel的高度和scrollView的高度
    CGFloat labelHeight = self.messageLabel.frame.size.height;
    CGFloat scrollViewHeight = scrollView.frame.size.height;
      
    // 设置内容偏移和内容大小
    CGFloat verticalPadding = MAX((scrollViewHeight - labelHeight) / 2, 0);
    scrollView.contentInset = UIEdgeInsetsMake(verticalPadding, 0, verticalPadding, 0);
    scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, labelHeight);

    
    self.recognitionResultLabel = [[UILabel alloc] initWithFrame:CGRectMake(50.0, 500.0, 300.0, 300.0)];
    self.recognitionResultLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.recognitionResultLabel.numberOfLines = 0;
    self.recognitionResultLabel.accessibilityIdentifier = @"result_label";
    [self.recognitionResultLabel setText:@"Press a button!"];

    [self.view addSubview:self.recognitionResultLabel];
    // 创建ToolsManager的实例，并传入self.view
    self.toolManager = [[ToolsManager alloc] initWithView:self.view];
    self.title = @"DeepSeek Voice Assistant";
    bool valid=[self validateAzureSpeechKey:speechKey region:serviceRegion];
    if (deepseekKey && speechKey && serviceRegion && valid && (!isRunning)) {
        //NSLog(@"Deepseek Key: %@", deepseekKey);
        //NSLog(@"Azure Speech Key: %@", speechKey);
        //NSLog(@"Azure Speech Region: %@", serviceRegion);
        // Start keyword recognition
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            [self recognizeKeywordFromFile];
        });
        isRunning=TRUE;
        // 使用这些值进行后续操作
    } else {
        NSLog(@"Configuration not set.");
        [self openConfig];
        isRunning=FALSE;
    }
    // 设置导航栏标题
    

}



/*
 * Performs speech recognition on audio data from the default microphone.
 */
- (void)recognizeFromMicrophone {
    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
    speechConfig.speechRecognitionLanguage=@"zh-CN";
    speechConfig.speechSynthesisLanguage=@"zh-CN";
    if (!speechConfig) {
        NSLog(@"Could not load speech config");
        [self updateRecognitionErrorText:(@"Speech Config Error")];
        return;
    }

    [self synthesisToSpeaker:(@"我在听请讲！")];
    [self updateRecognitionResultText:(@"我在听请讲！")];
    NSArray *languages = @[@"en-US", @"zh-CN"];
    SPXAutoDetectSourceLanguageConfiguration *autoDetectConfig = [[SPXAutoDetectSourceLanguageConfiguration alloc] init:languages];
      
    
    int noMatchCount = 0;
      
    while (noMatchCount < 200) {
        [self updateRecognitionStatusText:(@"Listening...")];
        SPXSpeechRecognizer* speechRecognizer = [[SPXSpeechRecognizer alloc]
                                                 init:speechConfig];
            //initWithSpeechConfiguration:speechConfig
            //autoDetectSourceLanguageConfiguration:autoDetectConfig];
        
        if (!speechRecognizer) {
            NSLog(@"Could not create speech recognizer");
            [self updateRecognitionErrorText:(@"Speech Recognition Error")];
            return;
        }
        
        SPXSpeechRecognitionResult *speechResult = [speechRecognizer recognizeOnce];
        if (SPXResultReason_Canceled == speechResult.reason) {
            SPXCancellationDetails *details = [[SPXCancellationDetails alloc] initFromCanceledRecognitionResult:speechResult];
            NSLog(@"Speech recognition was canceled: %@. Did you pass the correct key/region combination?", details.errorDetails);
            [self updateRecognitionErrorText:([NSString stringWithFormat:@"Canceled: %@", details.errorDetails ])];
        } else if (SPXResultReason_RecognizedSpeech == speechResult.reason) {
            NSLog(@"Speech recognition result received: %@", speechResult.text);
            [self updateRecognitionResultText:(speechResult.text)];
            [self updateRecognitionStatusText:(@"Recognized!")];
            __block NSString *resultContent = nil;
            __block NSError *blockError = nil;
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [self generateTextWithPrompt:speechResult.text completion:^(NSString *content, NSError *error) {
                NSLog(@"generateTextWithPrompt => content: %@, error: %@",content, error);
                if (error) {
                    blockError = error;
                    [self synthesisToSpeaker:(@"大模型出错了，请重启后再试一下")];
                    [self updateRecognitionErrorText:(@"AI LLM generateText error!")];
                } else {
                    resultContent = content;
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            // 在这里处理 resultContent 的个别句子
                            [self updateRecognitionResultText:(content)];
                        });
                    
                    //[self synthesisToSpeaker:(content)];
                }
                dispatch_semaphore_signal(semaphore);
                
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
        } else if (SPXResultReason_NoMatch == speechResult.reason) {
            NSLog(@"No match found.");
            [self updateRecognitionStatusText:(@"Cannot recognize!")];
            //[self updateRecognitionResultText:(@"我没听清，您还在说话吗？")];
            if (noMatchCount % 6 == 0)
            {
                [self synthesisToSpeaker:(@"我还在呢，我在听请讲。")];
            }
            noMatchCount++;
            
        } else {
            NSLog(@"There was an error.");
            [self updateRecognitionErrorText:(@"Speech Recognition Error")];
        }
    }
    [self updateRecognitionResultText:(@"我先退下了，您可以再次唤醒我说'Computer'")];
    [self updateRecognitionStatusText:(@"Quit!")];
    
    [self synthesisToSpeaker:(@"我先退下了，您可以再次唤醒我说'Computer'")];
    
}
- (void)synthesisToSpeaker:(NSString *)inputText{
    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
    if (!speechConfig) {
        NSLog(@"Could not load speech config");
        [self updateRecognitionErrorText:(@"Speech Config Error")];
        return;
    }
    // Sets the synthesis language.
    // The full list of supported language can be found here:
    // https://docs.microsoft.com/azure/cognitive-services/speech-service/language-support#text-to-speech
    speechConfig.speechSynthesisLanguage = @"zh-CN";
    
    // Sets the voice name
    // e.g. "en-GB-RyanNeural".
    // The full list of supported voices can be found here:
    // https://aka.ms/csspeech/voicenames
    // And, you can try getVoices method to get all available voices.
    speechConfig.speechSynthesisVoiceName = @"zh-CN-XiaoxiaoMultilingualNeural";
    // Sets the synthesis output format.
    // The full list of supported format can be found here:
    // https://docs.microsoft.com/azure/cognitive-services/speech-service/rest-text-to-speech#audio-outputs
    [speechConfig setSpeechSynthesisOutputFormat:SPXSpeechSynthesisOutputFormat_Riff16Khz16BitMonoPcm];
    // If you are using Custom Voice (https://aka.ms/customvoice),
    // uncomment the following line to set the endpoint id of your Custom Voice model.
    // speechConfig.EndpointId = @"YourEndpointId";
    NSLog(@"Synthesizing...");
    [self updateRecognitionStatusText:(@"Speaking...")];

    SPXSpeechSynthesizer *synthesizer = [[SPXSpeechSynthesizer alloc] init:speechConfig];
    if (!synthesizer) {
        NSLog(@"Could not create speech synthesizer");
        [self updateRecognitionErrorText:(@"Speech Synthesis Error")];
        return;
    }

    //SPXSpeechSynthesisResult *speechResult = [synthesizer speakText:inputText];
    NSString *voiceName = @"zh-CN-XiaoxiaoMultilingualNeural"; // Replace with the desired voice name
    NSString *resultString = [inputText stringByReplacingOccurrencesOfString:@"*" withString:@""];
    NSString *resultString2 = [resultString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    NSString *ssmlText = [NSString stringWithFormat:
                          @"<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>"
                           "<voice name='%@'>"
                            "<prosody rate='+14%%'>%@</prosody>"
                           "</voice>"
                          "</speak>", voiceName, resultString2];
      
    // Perform speech synthesis with SSML
    SPXSpeechSynthesisResult *speechResult = [synthesizer speakSsml:ssmlText];
    // Checks result.
    if (SPXResultReason_Canceled == speechResult.reason) {
        SPXSpeechSynthesisCancellationDetails *details = [[SPXSpeechSynthesisCancellationDetails alloc] initFromCanceledSynthesisResult:speechResult];
        NSLog(@"Speech synthesis was canceled: %@. Did you pass the correct key/region combination?", details.errorDetails);
        [self updateRecognitionErrorText:([NSString stringWithFormat:@"Canceled: %@", details.errorDetails])];
    } else if (SPXResultReason_SynthesizingAudioCompleted == speechResult.reason) {
        NSLog(@"Speech synthesis was completed");
        [self updateRecognitionStatusText:@"Speech speaking was completed."];
    } else {
        NSLog(@"Speech synthesis error.");
        [self updateRecognitionErrorText:(@"Speech synthesis error.")];
    }
}

/*
 * Performs keyword recognition from a wav file using kws.table keyword model
 */
- (void)recognizeKeywordFromFile {
    NSBundle *mainBundle = [NSBundle mainBundle];
    //NSString *kwsWeatherFile = [mainBundle pathForResource: @"kws_whatstheweatherlike" ofType:@"wav"];
    //NSLog(@"kws_weatherFile path: %@", kwsWeatherFile);
    /*
    if (!kwsWeatherFile) {
        NSLog(@"Cannot find audio file!");
        [self updateRecognitionErrorText:(@"Cannot find audio file")];
        return;
    }
    */
    while(true)
    {
    //SPXAudioConfiguration* audioFileInput = [[SPXAudioConfiguration alloc] initWithWavFileInput:kwsWeatherFile];
    SPXAudioConfiguration* audioFileInput = [[SPXAudioConfiguration alloc] init];

    if (!audioFileInput) {
        NSLog(@"Loading audio file failed!");
        [self updateRecognitionErrorText:(@"Audio Error")];
        return;
    }

    NSString *keywordModelFile = [mainBundle pathForResource: @"kws" ofType:@"table"];
    NSLog(@"keyword model file path: %@", keywordModelFile);
    if (!keywordModelFile) {
        NSLog(@"Cannot find keyword model file!");
        [self updateRecognitionErrorText:(@"Cannot find keyword model file")];
        return;
    }

    SPXKeywordRecognitionModel* keywordRecognitionModel = [[SPXKeywordRecognitionModel alloc] initFromFile:keywordModelFile];

    SPXKeywordRecognizer* keywordRecognizer = [[SPXKeywordRecognizer alloc] init:audioFileInput];
    if (!keywordRecognizer) {
        NSLog(@"Could not create keyword recognizer");
        [self updateRecognitionResultText:(@"Keyword Recognition Error")];
        return;
    }
    [self updateRecognitionResultText:(@"您好，请叫我Computer。")];
    [self synthesisToSpeaker:(@"您好，您可以唤醒我说Computer。")];
    
        

        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block SPXKeywordRecognitionResult * keywordResult;
        [keywordRecognizer recognizeOnceAsync: ^ (SPXKeywordRecognitionResult *srresult) {
            keywordResult = srresult;
            dispatch_semaphore_signal(semaphore);
        }keywordModel:keywordRecognitionModel];
        
        [self updateRecognitionStatusText:(@"Waiting for wakeup...")];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        if (SPXResultReason_Canceled == keywordResult.reason) {
            SPXCancellationDetails *details = [[SPXCancellationDetails alloc] initFromCanceledRecognitionResult:keywordResult];
            NSLog(@"Keyword recognition was canceled: %@.", details.errorDetails);
            [self updateRecognitionErrorText:([NSString stringWithFormat:@"Canceled: %@", details.errorDetails ])];
        } else if (SPXResultReason_RecognizedKeyword == keywordResult.reason) {
            NSLog(@"Keyword recognition result received: %@", keywordResult.text);
            [self updateRecognitionResultText:(@"Hello! I'm back...")];
            [self updateRecognitionStatusText:(keywordResult.text)];
        } else {
            NSLog(@"There was an error.");
            [self updateRecognitionErrorText:(@"Keyword Recognition Error")];
        }
        [self recognizeFromMicrophone];
    }
}



- (void)updateRecognitionResultText:(NSString *) resultText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.messageLabel.textColor = UIColor.whiteColor;
        self.messageLabel.text=resultText;
        //self.recognitionResultLabel.textColor = UIColor.whiteColor;
        //self.recognitionResultLabel.text = resultText;
    });
}

- (void)updateRecognitionErrorText:(NSString *) errorText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recognitionResultLabel.textColor = UIColor.redColor;
        self.recognitionResultLabel.text = errorText;
    });
}

- (void)updateRecognitionStatusText:(NSString *) statusText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recognitionResultLabel.textColor = UIColor.yellowColor;
        self.recognitionResultLabel.text = statusText;
    });
}

- (void)getLLMResponseWithMessages:(NSArray *)messages tools:(NSArray *)tools completion:(void (^)(NSDictionary *response, NSError *error))completion {
    __block NSInteger i = 20;
    __block NSArray *messagesAI = [messages subarrayWithRange:NSMakeRange(MAX((NSInteger)messages.count - i, 0), MIN(i, messages.count))];
      
    while (messagesAI.count > 0 && [messagesAI.firstObject[@"role"] isEqualToString:@"tool"]) {
        i++;
        messagesAI = [messages subarrayWithRange:NSMakeRange(MAX((NSInteger)messages.count - i, 0), MIN(i, messages.count))];
    }
      
    NSDictionary *sysmesg = @{@"role": @"system",@"content": @"你是AI助手，会尽力帮助人解决问题。"};
    NSMutableArray *finalMessages = [NSMutableArray arrayWithObject:sysmesg];
    [finalMessages addObjectsFromArray:messagesAI];
      
    NSDictionary *parameters = @{
        @"model": @"deepseek-chat",
        @"messages": finalMessages,
        @"temperature": @0.6,
        @"max_tokens": @300,
        @"stream": @YES,  // 启用流式输出
        @"stop": @[@"null"],
        @"top_p": @0.7,
        @"top_k": @50,
        @"frequency_penalty": @0.5,
        @"n": @1,
        @"response_format": @{@"type": @"text"}
    };
      
    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
      
    if (error) {
        completion(nil, error);
        return;
    }

    NSURL *url = [NSURL URLWithString:@"https://api.deepseek.com/chat/completions"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString *authorizationHeaderValue = [NSString stringWithFormat:@"Bearer %@", deepseekKey];
    [request setValue:authorizationHeaderValue forHTTPHeaderField:@"Authorization"];
    
    [request setHTTPBody:postData];
    // 初始化全局变量
    self.resultAll = [NSMutableString string];
    // 保存 completion 回调
    self.completionBlock = completion;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
    [dataTask resume];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!dataString) return;

    // 按行分割数据
    NSArray *lines = [dataString componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if ([line hasPrefix:@"data: "]) {
            NSString *jsonString = [line substringFromIndex:6]; // 去掉 "data: "
            if ([jsonString isEqualToString:@"[DONE]"]) {
                // 流式传输结束
                [self flushBuffer];
                return;
            }

            NSError *error;
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
            if (error) {
                NSLog(@"Error parsing JSON: %@", error);
                continue;
            }

            NSString *content = jsonResponse[@"choices"][0][@"delta"][@"content"];
            if (content) {
                [self processContent:content];
            }
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"Request failed with error: %@", error);
        if (self.completionBlock) {
            self.completionBlock(nil, error);
        }
    } else {
        NSLog(@"Request completed successfully");
        /*
        // 将累积结果保存到 messages 中
        NSDictionary *assistantMessage = @{@"role": @"assistant", @"content": self.resultAll};
        // 假设 messages 是一个全局变量或可以通过其他方式访问
        [messages addObject:assistantMessage];
        */
        if (self.completionBlock) {
            NSDictionary *response = @{@"role": @"assistant", @"content": self.resultAll};
            self.completionBlock(response, nil);
        }
    }
}

#pragma mark - Content Processing

- (void)processContent:(NSString *)content {
    static NSMutableString *resultBuffer = nil;
    if (!resultBuffer) {
        resultBuffer = [NSMutableString string];
    }

    [resultBuffer appendString:content];
    [self.resultAll appendString:content]; // 将内容追加到全局变量中
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 在这里处理 resultContent 的个别句子
            [self updateRecognitionResultText:(self.resultAll)];
        });
    NSLog(@"%@", content); // 打印流式内容

    // 检测句子结束符
    NSCharacterSet *sentenceEndings = [NSCharacterSet characterSetWithCharactersInString:@"。！？\n"];
    NSRange range = [resultBuffer rangeOfCharacterFromSet:sentenceEndings options:NSBackwardsSearch];
    if (range.location != NSNotFound) {
        NSString *sentence = [resultBuffer substringToIndex:range.location + 1];
        [self synthesisToSpeaker:(sentence)];
        [resultBuffer deleteCharactersInRange:NSMakeRange(0, range.location + 1)];
    }
}

- (void)flushBuffer {
    static NSMutableString *resultBuffer = nil;
    if (resultBuffer && resultBuffer.length > 0) {
        [self.resultAll appendString:resultBuffer]; // 将内容追加到全局变量中
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // 在这里处理 resultContent 的个别句子
                [self updateRecognitionResultText:(self.resultAll)];
            });
        [self synthesisToSpeaker:(resultBuffer)];
        resultBuffer = [NSMutableString string];
    }
}
- (NSString *)getChatDeployment {
    // Implement your method to get chat deployment
    return @"gpt-4o";
}
- (void)runConversationWithMessages:(NSMutableArray *)messages tools:(NSArray *)tools completion:(void (^)(NSDictionary *response, NSError *error))completion {
    [self getLLMResponseWithMessages:messages tools:tools completion:^(NSDictionary *responseMessage, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
          
        if (responseMessage[@"tool_calls"]) {
            NSArray *toolCalls = responseMessage[@"tool_calls"];
            [messages addObject:responseMessage]; // extend conversation with assistant's reply
              
            for (NSDictionary *toolCall in toolCalls) {
                NSLog(@"⏳Call internal function...");
                NSString *functionName = toolCall[@"function"][@"name"];
                NSLog(@"⏳Call %@...", functionName);
                  
                NSDictionary *functionArgs = [NSJSONSerialization JSONObjectWithData:[toolCall[@"function"][@"arguments"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                NSLog(@"⏳Call params: %@", functionArgs);
                  
                // Call the function dynamically
                SEL selector = NSSelectorFromString(functionName);
                id functionResponse = [self.toolManager performSelector:selector withObject:functionArgs];
                  
                NSLog(@"⏳Call internal function done!");
                NSLog(@"执行结果：%@", functionResponse);
                NSLog(@"===================================");
                  
                [messages addObject:@{
                    @"tool_call_id": toolCall[@"id"],
                    @"role": @"tool",
                    @"name": functionName,
                    @"content": functionResponse
                }];
                if (self.toolManager.capturedImage) {
                    
                    NSData *imageData = UIImageJPEGRepresentation(self.toolManager.capturedImage, 0.95);
                    NSError *error = nil;
                    NSString *imgUrl =[self.toolManager uploadImageToAzureBlob:imageData error:&error];
                    if (error) {  
                        NSLog(@"上传失败: %@", error.localizedDescription);  
                    } else {  
                        NSLog(@"上传成功, 图片 URL: %@", imgUrl);
                    }  
                    NSLog(@"Compressed image size: %lu bytes", (unsigned long)[imageData length]);
                    //NSString *encodedImage = [imageData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
                    [messages addObject:@{@"role": @"user", @"content": @[ @{@"type": @"text", @"text": @"这是采集到的照片"},@{@"type": @"image_url", @"image_url": @{@"url": [NSString stringWithFormat:@"%@", imgUrl]}} ]}];
                    //[self appendImageToChatTextView:selectedImage];
                    self.toolManager.capturedImage = nil; // 清空已选图片
                    
                }
            }
              
            // Recursively call runConversation
            [self runConversationWithMessages:messages tools:tools completion:completion];
        } else {
            completion(responseMessage, nil);
        }
    }];
}

  
// Example function to be called
- (NSString *)exampleFunctionWithArguments:(NSDictionary *)args {
    // Implement your function logic here
    return @"Function response";
}

  
NSMutableArray *messages;
UIImage *selectedImage;
  
- (instancetype)init {
    self = [super init];
    if (self) {
        messages = [NSMutableArray array];
    }
    return self;
}
- (void)generateTextWithPrompt:(NSString *)prompt completion:(void (^)(NSString *content, NSError *error))completion {
    //[messages addObject:@{@"role": @"user", @"content": prompt}];
    [messages addObject:@{@"role": @"user", @"content": @[ @{@"type": @"text", @"text": prompt} ]}];
    
    NSArray *tools = [self getTools];
      
    [self runConversationWithMessages:messages tools:tools completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            completion(nil, error);
        } else {
            completion(response[@"content"], nil);
            [messages addObject:@{@"role": @"assistant", @"content": response[@"content"]}];
        }
    }];
}

- (NSMutableArray *)getTools {
    
    // 调用ToolsManager的getTools方法
    NSArray<Tool *> *tools = [self.toolManager getTools];
      
    // 将Tool对象转换为NSDictionary
    NSMutableArray *toolsDictArray = [NSMutableArray array];
    for (Tool *tool in tools) {
        [toolsDictArray addObject:[tool toDictionary]];
    }
      
    // 返回结果
    return toolsDictArray;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishProcessingPhoto:(AVCapturePhoto *)photo
                       error:(NSError *)error {
    if (error) {
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
- (NSArray<Tool *> *)getTools2 {
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
        @"description": @"打开摄像头",
        @"parameters": @{
            @"type": @"object",
            @"properties": @{},
            @"required": @[]
        }
    };
    Tool *openCameraTool = [[Tool alloc] initWithType:@"function" function:openCameraDescription];
    
    NSDictionary *closeCameraDescription = @{
        @"name": @"closeCamera",
        @"description": @"关闭摄像头",
        @"parameters": @{
            @"type": @"object",
            @"properties": @{},
            @"required": @[]
        }
    };
    Tool *closeCameraTool = [[Tool alloc] initWithType:@"function" function:closeCameraDescription];
    
    NSDictionary *takePhotoDescription = @{
        @"name": @"takePhoto",
        @"description": @"拍照",
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
        result = @"摄像头已打开！";
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
          
        result = @"关闭了摄像头。";
        dispatch_semaphore_signal(semaphore);
    });
      
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return result;
}
- (NSString *)takePhoto {
    UIImage *capturedImage = nil;
    self.capturedImage = [self takePhoto2];
    return @"已拍照！";
}
- (UIImage *)takePhoto2 {
    __block UIImage *capturedImage = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  
    dispatch_async(dispatch_get_main_queue(), ^{
        AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
        
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
@end

