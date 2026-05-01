#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <substrate.h>

typedef NS_ENUM(NSUInteger, SOOPRequestPolicy) {
    SOOPRequestPolicyAllow = 0,
    SOOPRequestPolicyBlock
};

static NSString *const kSOOPHandledKey = @"com.lemonflare.soopshield.handled";
static const void *kSOOPScriptInstalledKey = &kSOOPScriptInstalledKey;

@interface SOOPAdBlockURLProtocol : NSURLProtocol
@end

static NSString *LowerString(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return @"";
    return value.lowercaseString;
}

static BOOL IsHTTPURL(NSURL *url) {
    if (![url isKindOfClass:[NSURL class]]) return NO;
    NSString *scheme = LowerString(url.scheme);
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

static BOOL HostEquals(NSString *host, NSString *target) {
    if (host.length == 0 || target.length == 0) return NO;
    return [host isEqualToString:target];
}

static BOOL HasSuffixOrExact(NSString *value, NSString *suffix) {
    if (value.length == 0 || suffix.length == 0) return NO;
    if ([value isEqualToString:suffix]) return YES;
    return [value hasSuffix:[@"." stringByAppendingString:suffix]];
}

static BOOL IsVodPlayerHost(NSString *host) {
    if (host.length == 0) return NO;
    if (!HasSuffixOrExact(host, @"sooplive.com")) return NO;

    NSArray<NSString *> *parts = [host componentsSeparatedByString:@"."];
    if (parts.count == 0) return NO;

    NSString *first = parts.firstObject ?: @"";
    return [first hasPrefix:@"vod-player"];
}

static SOOPRequestPolicy RequestPolicyForURL(NSURL *url) {
    if (!IsHTTPURL(url)) return SOOPRequestPolicyAllow;

    NSString *host = LowerString(url.host);
    NSString *path = LowerString(url.path);

    if (IsVodPlayerHost(host)) return SOOPRequestPolicyBlock;

    if (HostEquals(host, @"main-player.sooplive.com")) return SOOPRequestPolicyBlock;
    if (HostEquals(host, @"img-display.sooplive.com")) return SOOPRequestPolicyBlock;

    if (HostEquals(host, @"ch.dawin.tv") && ([path isEqualToString:@"/dmpro"] || [path hasPrefix:@"/dmpro/"])) {
        return SOOPRequestPolicyBlock;
    }

    if (HostEquals(host, @"admv.digitalcamp.co.kr") && ([path isEqualToString:@"/adfiles"] || [path hasPrefix:@"/adfiles/"])) {
        return SOOPRequestPolicyBlock;
    }

    return SOOPRequestPolicyAllow;
}

@implementation SOOPAdBlockURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (![request isKindOfClass:[NSURLRequest class]]) return NO;

    if ([NSURLProtocol propertyForKey:kSOOPHandledKey inRequest:request]) {
        return NO;
    }

    SOOPRequestPolicy policy = RequestPolicyForURL(request.URL);
    return policy != SOOPRequestPolicyAllow;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *markedRequest = [self.request mutableCopy];
    if (markedRequest) {
        [NSURLProtocol setProperty:@YES forKey:kSOOPHandledKey inRequest:markedRequest];
    }

    NSURL *url = self.request.URL;
    NSDictionary *userInfo = url ? @{ NSURLErrorFailingURLErrorKey: url } : nil;
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];
    [self.client URLProtocol:self didFailWithError:error];
    NSLog(@"[SoopShield] Blocked ad request: %@", url.absoluteString);
}

- (void)stopLoading {
}

@end

static NSString *const kSOOPDOMScript =
@"(() => {"
"if (window.__soopShieldInstalled) return;"
"window.__soopShieldInstalled = true;"
"const hideSelectors = ["
"'.adballoon_icon',"
"'.shopProduct_banner',"
"'#timeshift.message_player.on',"
"'.a_d_banner',"
"'.bnrimg_area',"
"'.collabo_brand',"
"'.nav-conts #catch + li',"
"\"div[class*=\\\"NoticeLayer_layerContainer\\\"]\","
"\"li[virtual-index=\\\"3\\\"]:has(.player_thumb_wrap__xrIsm)\","
"'.subBanner_fullBanner__SNZqb',"
"'.main_banner_wrap',"
"'.contents_wrap.event',"
"'.gp_modal_wrap'"
"];"
"const padSelectors = [\"#container._live > .title_wrap[data-testid=\\\"section-header\\\"]\"];"
"const hideChatBanner = () => {"
"  const banner = document.querySelector('.chat_banner2.on');"
"  if (banner) banner.style.setProperty('display', 'none', 'important');"
"};"
"const closeMainBanner = () => {"
"  const closeBtn = document.querySelector('.mainBanner_close__ftU15');"
"  if (closeBtn) closeBtn.click();"
"};"
"const hideBySelectors = () => {"
"  for (const selector of hideSelectors) {"
"    try {"
"      const nodes = document.querySelectorAll(selector);"
"      for (const node of nodes) {"
"        node.style.setProperty('display', 'none', 'important');"
"      }"
"    } catch (e) {}"
"  }"
"  for (const selector of padSelectors) {"
"    try {"
"      const nodes = document.querySelectorAll(selector);"
"      for (const node of nodes) {"
"        node.style.setProperty('padding-top', '10px', 'important');"
"      }"
"    } catch (e) {}"
"  }"
"};"
"const runAll = () => {"
"  closeMainBanner();"
"  hideChatBanner();"
"  hideBySelectors();"
"};"
"runAll();"
"window.addEventListener('load', () => {"
"  runAll();"
"  for (let delay = 0; delay <= 50; delay += 5) setTimeout(runAll, delay);"
"  setTimeout(runAll, 100);"
"  setTimeout(runAll, 1000);"
"});"
"new MutationObserver(runAll).observe(document.documentElement || document.body, { childList: true, subtree: true });"
"setInterval(runAll, 600);"
"})();";

static void InstallProtocolClassIfNeeded(NSURLSessionConfiguration *configuration) {
    if (![configuration isKindOfClass:[NSURLSessionConfiguration class]]) return;

    NSArray *currentClasses = configuration.protocolClasses ?: @[];
    for (Class cls in currentClasses) {
        if (cls == [SOOPAdBlockURLProtocol class]) {
            return;
        }
    }

    NSMutableArray *updated = [NSMutableArray arrayWithObject:[SOOPAdBlockURLProtocol class]];
    [updated addObjectsFromArray:currentClasses];
    configuration.protocolClasses = updated;
}

static void InstallDOMScriptIfNeeded(WKWebViewConfiguration *configuration) {
    if (![configuration isKindOfClass:[WKWebViewConfiguration class]]) return;

    @synchronized (configuration) {
        NSNumber *installed = objc_getAssociatedObject(configuration, kSOOPScriptInstalledKey);
        if (installed.boolValue) return;

        WKUserContentController *controller = configuration.userContentController;
        if (!controller) {
            controller = [[WKUserContentController alloc] init];
            configuration.userContentController = controller;
        }

        WKUserScript *script = [[WKUserScript alloc] initWithSource:kSOOPDOMScript
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                   forMainFrameOnly:NO];
        [controller addUserScript:script];
        objc_setAssociatedObject(configuration, kSOOPScriptInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void BootstrapWebViewIfNeeded(WKWebView *webView) {
    if (![webView isKindOfClass:[WKWebView class]]) return;
    InstallDOMScriptIfNeeded(webView.configuration);
    [webView evaluateJavaScript:kSOOPDOMScript completionHandler:nil];
}

%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *configuration = %orig;
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *configuration = %orig;
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    NSURLSessionConfiguration *configuration = %orig(identifier);
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)backgroundSessionConfiguration:(NSString *)identifier {
    NSURLSessionConfiguration *configuration = %orig(identifier);
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

%end

%hook NSURLSession

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    InstallProtocolClassIfNeeded(configuration);
    return %orig(configuration);
}

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    InstallProtocolClassIfNeeded(configuration);
    return %orig(configuration, delegate, queue);
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration {
    InstallProtocolClassIfNeeded(configuration);
    return %orig(configuration);
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    InstallProtocolClassIfNeeded(configuration);
    return %orig(configuration, delegate, queue);
}

%end

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    InstallDOMScriptIfNeeded(configuration);
    id instance = %orig(frame, configuration);
    BootstrapWebViewIfNeeded(instance);
    return instance;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    id instance = %orig(coder);
    BootstrapWebViewIfNeeded(instance);
    return instance;
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    BootstrapWebViewIfNeeded(self);
    return %orig(request);
}

- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    BootstrapWebViewIfNeeded(self);
    return %orig(string, baseURL);
}

%end

%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"(unknown)";
    NSLog(@"[SoopShield] Tweak loaded in bundle: %@", bundleID);
    [NSURLProtocol registerClass:[SOOPAdBlockURLProtocol class]];
}
