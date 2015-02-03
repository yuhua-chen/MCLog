#MCLog

This plugin let you feel easy to trace console log. Although you may search the text in the console area, you can't hide something you don't want to see. MCLog is one of the solutions. You're able to filter the console by it and display what you really want to see. Here's the demo:

![screen-shot](https://rawgithub.com/yuhua-chen/MCLog/master/MCLogScreenshot.gif)

![screen-shot](https://raw.githubusercontent.com/alexlee002/MCLog/master/MCLog-colorful-logs.png)

 
## Compatibility

 - Support Xcode 5 above.
 
## Features 
 - Filter console log with regular expression.
 - Support multi-tabs.
 - Support colorful log output
 - Support different log levels 

## Usage

Install it via [Alcatraz](http://alcatraz.io/)  
or  
 1. Clone the repo and build it.
 2. MCLog.xcplugin should appear in `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`
 3. Restart Xcode  

If you encounter any issues you can uninstall it by removing the `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins/MCLog.xcplugin`.

## Enable colorful console output

example:

- define log macros:

``` objc
#define __ALLog(LEVEL, fmt, ...) \
    NSLog((@"-\e[7m" LEVEL @"\e[27;2;3;4m %s (%@:%d)\e[22;23;24m] " fmt ), __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, ##__VA_ARGS__)

#define ALLogV(fmt, ...) __ALLog(@"[VERBOSE]", fmt, ##__VA_ARGS__)
#define ALLogI(fmt, ...) __ALLog(@"[INFO]", fmt, ##__VA_ARGS__)
#define ALLogW(fmt, ...) __ALLog(@"[WARN]", fmt, ##__VA_ARGS__)
#define ALLogE(fmt, ...) __ALLog(@"[ERROR]", fmt, ##__VA_ARGS__)
```

- use macros in your code:

``` objc
    ALLogV(@"Sent when the application is about to move from active to inactive state. This can occur for certain types of");
    ALLogI(@"temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application");
    ALLogW(@"If your application supports background execution, this method is called instead of applicationWillTerminate:");
    ALLogE(@"Called as part of the transition from the background to the inactive state; here you can undo many of the changes");
```


## License

MCLog is under MIT.  See the LICENSE file for more info.

## Thanks

Thanks to [@alexlee002](https://github.com/alexlee002) for code contributions and many features.

## Contact

Any suggestions or improvements are welcome. Feel free to contact me at [@yuhua_twit](https://twitter.com/yuhua_twit).
