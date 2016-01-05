#MCLog

This plugin lets you easily filter the Xcode console log output. While you can already search the text in the console log output you are still left searching through a lot of code that has nothing to do with what you're interested in. MCLog is a simple solution to this problem. Filter the console using simple strings and display what you really want to see. Here's the demo:

![screen-shot](https://rawgithub.com/yuhua-chen/MCLog/master/MCLogScreenshot.gif)


## Compatibility

 - Support Xcode 5 above.
 
## Features

 - Filter console log with regular expression.
 - Support multi-tabs.
 - Support colorful log output.

## Usage

Install it via [Alcatraz](http://alcatraz.io/)  
or  
 1. Clone the repo and build it.
 2. MCLog.xcplugin should appear in `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`
 3. Restart Xcode  

If you encounter any issues you can uninstall it by removing the `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins/MCLog.xcplugin`.

## Notice

If you upgrade OSX to 10.11(El Capitain), please run this command `sudo xcodebuild -license` after install MCLog.

## License

MCLog is under MIT.  See the LICENSE file for more info.

## Thanks

Thanks to [@alexlee002](https://github.com/alexlee002) for code contributions and many features.

## Contact

Any suggestions or improvements are welcome. Feel free to contact me at [@yuhua_twit](https://twitter.com/yuhua_twit).
