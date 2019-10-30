#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#include "../../../common/trace.h"
#include "../../shared/interface.h"
#include "nucleus.h"

@implementation AudienceWindowContextData
@end

@interface AudienceAppDelegate : NSObject <NSApplicationDelegate>
@property(strong) NSImage *appIcon;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (NSApplicationTerminateReply)applicationShouldTerminate:
    (NSApplication *)sender;
- (void)applicationWillTerminate:(NSNotification *)notification;
@end

@implementation AudienceAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  NSApp.applicationIconImage = self.appIcon;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:
    (NSApplication *)sender {
  bool prevent_quit = false;
  internal_on_process_will_quit(prevent_quit);
  return prevent_quit ? NSTerminateCancel : NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  internal_on_process_quit();
  TRACEA(info, "cocoa will call exit() for us now");
}
@end

@interface AudienceWindow : NSWindow <NSWindowDelegate>
@property(strong) AudienceWindowContext context;
- (void)timedWindowTitleUpdate:(NSTimer *)timer;
- (BOOL)windowShouldClose:(NSWindow *)sender;
- (void)windowWillClose:(NSNotification *)notification;
@end

@implementation AudienceWindow
- (void)timedWindowTitleUpdate:(NSTimer *)timer {
  // update window title with document title
  if (self.context != NULL && self.context.webview != NULL) {
    [self setTitle:[self.context.webview title]];
  }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
  // trigger event
  bool prevent_close = false;
  if (self.context != NULL) {
    internal_on_window_will_close(self.context, prevent_close);
  }
  return !prevent_close;
}

- (void)windowWillClose:(NSNotification *)notification {
  bool prevent_quit = false;

  if (self.context != NULL) {
    // trigger event
    internal_on_window_close(self.context, prevent_quit);

    // invalidate title timer
    if (self.context.titletimer != NULL) {
      [self.context.titletimer invalidate];
      self.context.titletimer = NULL;
    }

    // remove all references
    self.context.window = NULL;
    self.context.webview = NULL;
    self.context = NULL;
  }

  // post application quit event
  if (!prevent_quit) {
    dispatch_async(dispatch_get_main_queue(), ^{
      TRACEA(info, "calling NSApp.terminate()");
      [NSApp terminate:NULL];
    });
  }

  TRACEA(info, "window closed");
}
@end

AudienceAppDelegate *_nucleus_app_delegate = nullptr;

bool internal_init(AudienceNucleusProtocolNegotiation *negotiation,
                   const AudienceInternalDetails *details) {
  // negotiate protocol
  negotiation->nucleus_handles_webapp_type_url = true;

  // init shared application object
  [NSApplication sharedApplication];

  // set delegate (we need a strong reference here)
  _nucleus_app_delegate = [[AudienceAppDelegate alloc] init];
  [NSApp setDelegate:_nucleus_app_delegate];

  // apply icon
  NSImage *select_app_icon = nullptr;
  for (size_t i = 0; i < AUDIENCE_DETAILS_ICON_SET_ENTRIES; ++i) {
    if (details->icon_set[i] != nullptr) {
      TRACEW(info, "loading icon " << details->icon_set[i]);
      NSImage *app_icon = [[NSImage alloc]
          initWithContentsOfFile:
              [[NSString alloc]
                  initWithBytes:details->icon_set[i]
                         length:wcslen(details->icon_set[i]) * sizeof(wchar_t)
                       encoding:NSUTF32LittleEndianStringEncoding]];
      if (app_icon.size.width == 0) {
        continue;
      }
      if (select_app_icon == nullptr ||
          select_app_icon.size.width < app_icon.size.width) {
        TRACEW(info, "selecting icon "
                         << details->icon_set[i]
                         << " with width = " << app_icon.size.width);
        select_app_icon = app_icon;
      }
    }
  }

  if (select_app_icon != nullptr) {
    _nucleus_app_delegate.appIcon = select_app_icon;
  }

  TRACEA(info, "initialized");
  return true;
}

AudienceWindowContext
internal_window_create(const InternalWindowDetails &details) {
  // prepare context object
  AudienceWindowContext context = [[AudienceWindowContextData alloc] init];

  // create window
  NSRect screenSize = NSScreen.mainScreen.frame;
  NSRect targetRect =
      CGRectMake(0, 0, screenSize.size.width / 2, screenSize.size.height / 2);

  context.window = [[AudienceWindow alloc]
      initWithContentRect:targetRect
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO
                   screen:NSScreen.mainScreen];

  [context.window setReleasedWhenClosed:NO];

  context.window.delegate = context.window;
  context.window.context = context;

  [context.window
      setTitle:[[NSString alloc]
                   initWithBytes:details.loading_title.c_str()
                          length:details.loading_title.length() *
                                 sizeof(wchar_t)
                        encoding:NSUTF32LittleEndianStringEncoding]];
  [context.window center];

  // create webview
  WKWebViewConfiguration *config = [WKWebViewConfiguration new];
  context.webview = [[WKWebView alloc] initWithFrame:targetRect
                                       configuration:config];
  [context.webview
      loadRequest:
          [NSURLRequest
              requestWithURL:
                  [NSURL
                      URLWithString:
                          [[NSString alloc]
                              initWithBytes:details.webapp_location.c_str()
                                     length:details.webapp_location.length() *
                                            sizeof(wchar_t)
                                   encoding:
                                       NSUTF32LittleEndianStringEncoding]]]];
  [context.webview setAutoresizesSubviews:YES];
  [context.webview
      setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

  // enable dev tools
  if (details.dev_mode) {
    [context.webview.configuration.preferences
        setValue:@YES
          forKey:@"developerExtrasEnabled"];
  }

  // attach webview and put window in front
  [context.window.contentView addSubview:context.webview];
  [context.window orderFrontRegardless];

  // activate and finish launching
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
  [NSApp finishLaunching];
  [NSApp activateIgnoringOtherApps:YES];

  // create title update timer
  context.titletimer =
      [NSTimer scheduledTimerWithTimeInterval:1
                                       target:context.window
                                     selector:@selector(timedWindowTitleUpdate:)
                                     userInfo:NULL
                                      repeats:YES];

  TRACEA(info, "window created");
  return context;
}

void internal_window_post_message(AudienceWindowContext context,
                                  const char *message) {}

void internal_window_destroy(AudienceWindowContext context) {
  // perform close operation
  if (context.window != NULL) {
    [context.window close];
    TRACEA(info, "window close triggered");
  }
}

void internal_main() {
  [NSApp run];
  // NSApp.run() calls exit() by itself
}

void internal_dispatch_sync(void (*task)(void *context), void *context) {
  TRACEA(info, "dispatching task on main queue (sync)");
  dispatch_sync(dispatch_get_main_queue(), ^{
    task(context);
  });
}

void internal_dispatch_async(void (*task)(void *context), void *context) {
  TRACEA(info, "dispatching task on main queue (async)");
  dispatch_async(dispatch_get_main_queue(), ^{
    task(context);
  });
}
