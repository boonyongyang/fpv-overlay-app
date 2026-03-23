import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let semanticsSetter = Selector(("setSemanticsEnabled:"))
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 1320, height: 880)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 720, height: 860)

    if flutterViewController.engine.responds(to: semanticsSetter) {
      flutterViewController.engine.setValue(true, forKey: "semanticsEnabled")
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
