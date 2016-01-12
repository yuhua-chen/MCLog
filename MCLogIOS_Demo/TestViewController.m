//
//  TestViewController.m
//  MCLog
//
//  Created by Alex Lee on 2/25/15.
//  Copyright (c) 2015 Yuhua Chen. All rights reserved.
//

#import "TestViewController.h"

#define EnableColorLog 1

// clang-format off
#define PRETTY_FILE_NAME (__FILE__ ? [[NSString stringWithUTF8String:__FILE__] lastPathComponent] : @"")

#if DEBUG
#   if EnableColorLog
#       define __ALLog(LEVEL, fmt, ...) NSLog((@"-" LEVEL @"\e[2;3;4m %s (%@:%d)\e[22;23;24m " fmt), __PRETTY_FUNCTION__, PRETTY_FILE_NAME, __LINE__, ##__VA_ARGS__)
#   else
#       define __ALLog(LEVEL, fmt, ...) NSLog((@" %s (%@:%d) " fmt), __PRETTY_FUNCTION__, PRETTY_FILE_NAME, __LINE__, ##__VA_ARGS__)
#   endif
#else
#   define __ALLog(LEVEL, fmt, ...) do {} while (0)
#endif
// clang-format on

#define ALLogVerbose(fmt, ...)  __ALLog(@"[VERBOSE]", fmt, ##__VA_ARGS__)
#define ALLogInfo(fmt, ...)     __ALLog(@"[INFO]", fmt, ##__VA_ARGS__)
#define ALLogWarn(fmt, ...)     __ALLog(@"[WARN]", fmt, ##__VA_ARGS__)
#define ALLogError(fmt, ...)    __ALLog(@"[ERROR]", fmt, ##__VA_ARGS__)

@interface TestViewController() <UITextFieldDelegate>
@property(nonatomic, weak) UITextField *textField;
@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UITextField *textField = [[UITextField alloc]initWithFrame:CGRectMake(20, 50, self.view.bounds.size.width - 40, 35)];
    textField.placeholder = @"Input log text case here";
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.font = [UIFont systemFontOfSize:11.f];
    textField.delegate = self;
    [self.view addSubview:textField];
    self.textField = textField;
    
    CGRect frame = CGRectMake(20, 100, 10, 30);
    UIButton *hideKeyboard = [UIButton buttonWithType:UIButtonTypeSystem];
    [hideKeyboard setTitle:@"V" forState:UIControlStateNormal];
    [hideKeyboard setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [hideKeyboard addTarget:self action:@selector(hideKeyboardButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    hideKeyboard.frame = frame;
    [self.view addSubview:hideKeyboard];
    
    frame = CGRectMake(50, 100, 60, 30);
    UIButton *verbose = [UIButton buttonWithType:UIButtonTypeSystem];
    [verbose setTitle:@"Verbose" forState:UIControlStateNormal];
    [verbose addTarget:self action:@selector(verboseButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    verbose.frame = frame;
    [self.view addSubview:verbose];
    
    frame.origin.x += verbose.bounds.size.width + 20;
    UIButton *info = [UIButton buttonWithType:UIButtonTypeSystem];
    [info setTitle:@"Info" forState:UIControlStateNormal];
    [info addTarget:self action:@selector(infoButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    info.frame = frame;
    [self.view addSubview:info];
    
    frame.origin.x += info.bounds.size.width + 20;
    UIButton *warn = [UIButton buttonWithType:UIButtonTypeSystem];
    [warn setTitle:@"Warn" forState:UIControlStateNormal];
    [warn addTarget:self action:@selector(warnButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    warn.frame = frame;
    [self.view addSubview:warn];
    
    frame.origin.x += warn.bounds.size.width + 20;
    UIButton *error = [UIButton buttonWithType:UIButtonTypeSystem];
    [error setTitle:@"Error" forState:UIControlStateNormal];
    [error addTarget:self action:@selector(errorButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    error.frame = frame;
    [self.view addSubview:error];
    
    frame.origin.x = 20;
    frame.origin.y += 50;
    frame.size.width = self.textField.bounds.size.width;
    frame.size.height = self.view.bounds.size.height - frame.origin.y;
    UITextView *textView = [[UITextView alloc] initWithFrame:frame];
    textView.font = [UIFont systemFontOfSize:11.f];
    textView.editable = NO;

    NSString *tip = @"----- ANSI Escape Code -----\n\n"
                    @">>> Text attributes: \n"
                    @"0     All attributes off \n"
                    @"1/21  Bold on / off \n"
                    @"2/22  Faint on / off \n"
                    @"3/23  Italic on / off\n"
                    @"4/24  Underline on / off \n"
                    @"7/27  Image negative / positive \n"
                    @"8/28  Concealed on / off \n\n"
    
                    @">>> Foreground colors: \n"
                    @"30	Black \n"
                    @"31	Red \n"
                    @"32	Green \n"
                    @"33	Yellow \n"
                    @"34	Blue \n"
                    @"35	Magenta \n"
                    @"36	Cyan \n"
                    @"37	White \n"
                    @"39    Reset foreground color \n\n"
    
                    @">>> Background colors: \n"
                    @"40	Black \n"
                    @"41	Red \n"
                    @"42	Green \n"
                    @"43	Yellow \n"
                    @"44	Blue \n"
                    @"45	Magenta \n"
                    @"46	Cyan \n"
                    @"47	White \n"
                    @"49    Reset background color \n\n";
    textView.attributedText = [[NSAttributedString alloc] initWithString:tip];
    [self.view addSubview:textView];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSLog(@"original input: %@", textField.text);
    NSString *text = [textField.text stringByReplacingOccurrencesOfString:@"\\033" withString:@"\033"];
    NSLog(@"%@", text);
    textField.text = nil;
    return YES;
}

- (void)hideKeyboardButtonClick:(UIButton *)sender {
    [self.textField resignFirstResponder];
}

- (void)verboseButtonClick:(UIButton *)sender {
    [self.textField becomeFirstResponder];
    self.textField.text = @"-\\033[7m[VERBOSE]\\033[27m ";
}

- (void)infoButtonClick:(UIButton *)sender {
    [self.textField becomeFirstResponder];
    self.textField.text = @"-\\033[7m[INFO]\\033[27m ";
}

- (void)warnButtonClick:(UIButton *)sender {
    [self.textField becomeFirstResponder];
    self.textField.text = @"-\\033[7m[WARN]\\033[27m ";
}

- (void)errorButtonClick:(UIButton *)sender {
    [self.textField becomeFirstResponder];
    self.textField.text = @"-\\033[7m[ERROR]\\033[27m ";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self testCaseLotsOfLogs];
        //[self testCaseAttributeText];
        //[self testcaseLogLevel];
    });
}

- (void)testCaseAttributeText {
    NSLog(@"11111\e[32;2m222222\e[33m333333\e[44m4444444\e[45;22m5555555\e[0m");
    NSLog(@"11111\e[1m222222\e[1m333333\e[21m4444444\e[21m5555555\e[0m");
    NSLog(@"11111\e[3m222222\e[3m333333\e[23m4444444\e[23m5555555\e[0m");
    NSLog(@"11111\e[4m222222\e[4m333333\e[24m4444444\e[24m5555555\e[0m");
    NSLog(@"11111\e[32;2m222222\e[7m333333\e[45m4444444\e[41m88888\e[27m5555555\e[0m");
    NSLog(@"11111\033[32m222222\033[8meeeeeeeeeee\033[33m4444444444\033[28m66666666\033[0m");
    NSLog(@"11111\e[32m222222\e[8meeeeeeeeeee\e[33;7m4444444444\e[28m66666666\e[0m");
}

- (void)testcaseLogLevel {
    ALLogVerbose(@"This is VERBOSE message");
    ALLogInfo(@"This is INFO message");
    ALLogWarn(@"This is WARN message");
    ALLogError(@"This is ERROR message");
    NSLog(@"-[VERBOSE] verbose message");
    NSLog(@"-[INFO] \033[2;3;4minfo message");
    NSLog(@"-[WARN] warn message");
    NSLog(@"-[ERROR] error message");
}


- (void)testCaseLotsOfLogs {
    for (NSUInteger count = 0; count < 10000; ++count) {
        if (count % 1000 == 0) {
            [NSThread sleepForTimeInterval:0.1];
        }
        NSUInteger random = arc4random() % 4;
        NSUInteger randomStringLen = arc4random() % 200;
        NSMutableString *randomString = [NSMutableString stringWithCapacity:randomStringLen];
        for (NSUInteger i = 0; i < randomStringLen; ++i) {
            [randomString appendFormat:@"%02X", arc4random() % 256];
        }
        if (random == 0) {
            ALLogVerbose(@"***[%tu]***:If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.%@", count, randomString);
        } else if (random == 1) {
            ALLogInfo(@"***[%tu]***:Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.%@", count, randomString);
        } else if (random == 2) {
            ALLogWarn(@"***[%tu]***:If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.%@", count, randomString);
        } else if (random == 3) {
            ALLogError(@"***[%tu]***:Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.%@", count, randomString);
        }
    }
    
    //[@"" performSelector:NSSelectorFromString(@"hello_alex")];
}

@end
