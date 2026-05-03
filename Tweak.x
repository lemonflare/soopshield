#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <dlfcn.h>
#import <netdb.h>
#import <objc/runtime.h>
#import <string.h>

typedef NS_ENUM(NSUInteger, SOOPRequestPolicy) {
    SOOPRequestPolicyAllow = 0,
    SOOPRequestPolicyBlock
};

static NSString *const kSOOPHandledKey = @"com.lemonflare.soopshield.handled";
static const void *kSOOPScriptInstalledKey = &kSOOPScriptInstalledKey;
static const void *kSOOPContentRuleInstalledKey = &kSOOPContentRuleInstalledKey;

@interface SOOPAdBlockURLProtocol : NSURLProtocol
@end

static NSString *LowerString(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return @"";
    return value.lowercaseString;
}

static NSString *NormalizedHost(NSString *value) {
    NSString *host = LowerString(value);
    while (host.length > 0 && [host hasSuffix:@"."]) {
        host = [host substringToIndex:host.length - 1];
    }
    return host;
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

static BOOL IsSOOPLiveHost(NSString *host) {
    if (host.length == 0) return NO;
    return HasSuffixOrExact(host, @"sooplive.com") || HasSuffixOrExact(host, @"sooplive.co.kr");
}

static BOOL IsVodPlayerHost(NSString *host) {
    if (host.length == 0) return NO;
    if (!IsSOOPLiveHost(host)) return NO;

    NSArray<NSString *> *parts = [host componentsSeparatedByString:@"."];
    if (parts.count == 0) return NO;

    NSString *first = parts.firstObject ?: @"";
    return [first hasPrefix:@"vod-player"];
}

static BOOL IsBlockedSOOPPlayerHost(NSString *host) {
    host = NormalizedHost(host);
    if (host.length == 0) return NO;

    if (IsVodPlayerHost(host)) return YES;

    if (HostEquals(host, @"main-player.sooplive.com")) return YES;
    if (HostEquals(host, @"img-display.sooplive.com")) return YES;
    if (HostEquals(host, @"main-player.sooplive.co.kr")) return YES;
    if (HostEquals(host, @"img-display.sooplive.co.kr")) return YES;

    return NO;
}

static SOOPRequestPolicy RequestPolicyForURL(NSURL *url) {
    if (!IsHTTPURL(url)) return SOOPRequestPolicyAllow;

    NSString *host = NormalizedHost(url.host);
    NSString *path = LowerString(url.path);

    if (IsBlockedSOOPPlayerHost(host)) return SOOPRequestPolicyBlock;

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

static NSString *const kSOOPContentRuleIdentifier = @"com.lemonflare.soopshield.webkit-rules";
static NSString *const kSOOPContentRuleList =
@"["
"{\"trigger\":{\"url-filter\":\"^https?://(vod-player[0-9]*|main-player|img-display)\\\\.sooplive\\\\.(com|co\\\\.kr)([:/]|$)\"},\"action\":{\"type\":\"block\"}}"
"]";

static BOOL IsBlockedDNSHostCString(const char *name) {
    if (!name || name[0] == '\0') return NO;
    NSString *host = [NSString stringWithUTF8String:name];
    if (!host) return NO;
    return IsBlockedSOOPPlayerHost(host);
}

typedef int (*SOOPGetAddrInfoFunction)(const char *, const char *, const struct addrinfo *, struct addrinfo **);
typedef struct hostent *(*SOOPGetHostByNameFunction)(const char *);
typedef struct hostent *(*SOOPGetHostByName2Function)(const char *, int);

static SOOPGetAddrInfoFunction SOOPOriginalGetAddrInfo(void) {
    static SOOPGetAddrInfoFunction function = NULL;
    if (!function) {
        function = (SOOPGetAddrInfoFunction)dlsym(RTLD_NEXT, "getaddrinfo");
    }
    return function;
}

static SOOPGetHostByNameFunction SOOPOriginalGetHostByName(void) {
    static SOOPGetHostByNameFunction function = NULL;
    if (!function) {
        function = (SOOPGetHostByNameFunction)dlsym(RTLD_NEXT, "gethostbyname");
    }
    return function;
}

static SOOPGetHostByName2Function SOOPOriginalGetHostByName2(void) {
    static SOOPGetHostByName2Function function = NULL;
    if (!function) {
        function = (SOOPGetHostByName2Function)dlsym(RTLD_NEXT, "gethostbyname2");
    }
    return function;
}

static int soopshield_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (IsBlockedDNSHostCString(node)) {
        if (res) *res = NULL;
        NSLog(@"[SoopShield] Blocked DNS lookup: %s", node);
        return EAI_NONAME;
    }

    SOOPGetAddrInfoFunction original = SOOPOriginalGetAddrInfo();
    return original ? original(node, service, hints, res) : EAI_FAIL;
}

static struct hostent *soopshield_gethostbyname(const char *name) {
    if (IsBlockedDNSHostCString(name)) {
        h_errno = HOST_NOT_FOUND;
        NSLog(@"[SoopShield] Blocked DNS lookup: %s", name);
        return NULL;
    }

    SOOPGetHostByNameFunction original = SOOPOriginalGetHostByName();
    return original ? original(name) : NULL;
}

static struct hostent *soopshield_gethostbyname2(const char *name, int af) {
    if (IsBlockedDNSHostCString(name)) {
        h_errno = HOST_NOT_FOUND;
        NSLog(@"[SoopShield] Blocked DNS lookup: %s", name);
        return NULL;
    }

    SOOPGetHostByName2Function original = SOOPOriginalGetHostByName2();
    return original ? original(name, af) : NULL;
}

struct SOOPInterposePair {
    const void *replacement;
    const void *replacee;
};

#define SOOP_INTERPOSE(replacement, replacee) { (const void *)(unsigned long)&replacement, (const void *)(unsigned long)&replacee }

__attribute__((used))
static const struct SOOPInterposePair kSOOPInterposers[] __attribute__((section("__DATA,__interpose"))) = {
    SOOP_INTERPOSE(soopshield_getaddrinfo, getaddrinfo),
    SOOP_INTERPOSE(soopshield_gethostbyname, gethostbyname),
    SOOP_INTERPOSE(soopshield_gethostbyname2, gethostbyname2)
};

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

static void InstallContentRuleListIfNeeded(WKUserContentController *controller) {
    if (![controller isKindOfClass:[WKUserContentController class]]) return;

    @synchronized (controller) {
        NSNumber *installed = objc_getAssociatedObject(controller, kSOOPContentRuleInstalledKey);
        if (installed.boolValue) return;
        objc_setAssociatedObject(controller, kSOOPContentRuleInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    WKContentRuleListStore *store = [WKContentRuleListStore defaultStore];
    [store compileContentRuleListForIdentifier:kSOOPContentRuleIdentifier
                        encodedContentRuleList:kSOOPContentRuleList
                             completionHandler:^(WKContentRuleList *contentRuleList, NSError *error) {
        if (!contentRuleList) {
            NSLog(@"[SoopShield] Failed to install WebKit content rules: %@", error);
            objc_setAssociatedObject(controller, kSOOPContentRuleInstalledKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        [controller addContentRuleList:contentRuleList];
        NSLog(@"[SoopShield] Installed WebKit content rules");
    }];
}

static void InstallDOMScriptIfNeeded(WKWebViewConfiguration *configuration) {
    if (![configuration isKindOfClass:[WKWebViewConfiguration class]]) return;

    @synchronized (configuration) {
        WKUserContentController *controller = configuration.userContentController;
        if (!controller) {
            controller = [[WKUserContentController alloc] init];
            configuration.userContentController = controller;
        }

        InstallContentRuleListIfNeeded(controller);

        NSNumber *installed = objc_getAssociatedObject(configuration, kSOOPScriptInstalledKey);
        if (installed.boolValue) return;

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

static void SOOPSwizzleInstanceMethod(Class targetClass, SEL originalSelector, SEL swizzledSelector) {
    if (!targetClass || !originalSelector || !swizzledSelector) return;

    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(targetClass, swizzledSelector);

    if (!originalMethod || !swizzledMethod) {
        NSLog(@"[SoopShield] Missing method for swizzle: %@ %@", NSStringFromClass(targetClass), NSStringFromSelector(originalSelector));
        return;
    }

    BOOL added = class_addMethod(targetClass,
                                 originalSelector,
                                 method_getImplementation(swizzledMethod),
                                 method_getTypeEncoding(swizzledMethod));
    if (added) {
        class_replaceMethod(targetClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
        return;
    }

    method_exchangeImplementations(originalMethod, swizzledMethod);
}

static void SOOPSwizzleClassMethod(Class targetClass, SEL originalSelector, SEL swizzledSelector) {
    SOOPSwizzleInstanceMethod(object_getClass(targetClass), originalSelector, swizzledSelector);
}

@implementation NSURLSessionConfiguration (SoopShield)

+ (NSURLSessionConfiguration *)soopshield_defaultSessionConfiguration {
    NSURLSessionConfiguration *configuration = [self soopshield_defaultSessionConfiguration];
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)soopshield_ephemeralSessionConfiguration {
    NSURLSessionConfiguration *configuration = [self soopshield_ephemeralSessionConfiguration];
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)soopshield_backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    NSURLSessionConfiguration *configuration = [self soopshield_backgroundSessionConfigurationWithIdentifier:identifier];
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

+ (NSURLSessionConfiguration *)soopshield_backgroundSessionConfiguration:(NSString *)identifier {
    NSURLSessionConfiguration *configuration = [self soopshield_backgroundSessionConfiguration:identifier];
    InstallProtocolClassIfNeeded(configuration);
    return configuration;
}

@end

@implementation NSURLSession (SoopShield)

+ (NSURLSession *)soopshield_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    InstallProtocolClassIfNeeded(configuration);
    return [self soopshield_sessionWithConfiguration:configuration];
}

+ (NSURLSession *)soopshield_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    InstallProtocolClassIfNeeded(configuration);
    return [self soopshield_sessionWithConfiguration:configuration delegate:delegate delegateQueue:queue];
}

- (instancetype)soopshield_initWithConfiguration:(NSURLSessionConfiguration *)configuration {
    InstallProtocolClassIfNeeded(configuration);
    return [self soopshield_initWithConfiguration:configuration];
}

- (instancetype)soopshield_initWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    InstallProtocolClassIfNeeded(configuration);
    return [self soopshield_initWithConfiguration:configuration delegate:delegate delegateQueue:queue];
}

@end

@implementation WKWebView (SoopShield)

- (instancetype)soopshield_initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    InstallDOMScriptIfNeeded(configuration);
    id instance = [self soopshield_initWithFrame:frame configuration:configuration];
    BootstrapWebViewIfNeeded(instance);
    return instance;
}

- (instancetype)soopshield_initWithCoder:(NSCoder *)coder {
    id instance = [self soopshield_initWithCoder:coder];
    BootstrapWebViewIfNeeded(instance);
    return instance;
}

- (WKNavigation *)soopshield_loadRequest:(NSURLRequest *)request {
    BootstrapWebViewIfNeeded(self);
    return [self soopshield_loadRequest:request];
}

- (WKNavigation *)soopshield_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    BootstrapWebViewIfNeeded(self);
    return [self soopshield_loadHTMLString:string baseURL:baseURL];
}

@end

__attribute__((constructor))
static void SoopShieldInit(void) {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"(unknown)";
        NSLog(@"[SoopShield] Tweak loaded in bundle: %@", bundleID);

        [NSURLProtocol registerClass:[SOOPAdBlockURLProtocol class]];

        SOOPSwizzleClassMethod([NSURLSessionConfiguration class],
                               @selector(defaultSessionConfiguration),
                               @selector(soopshield_defaultSessionConfiguration));
        SOOPSwizzleClassMethod([NSURLSessionConfiguration class],
                               @selector(ephemeralSessionConfiguration),
                               @selector(soopshield_ephemeralSessionConfiguration));
        SOOPSwizzleClassMethod([NSURLSessionConfiguration class],
                               @selector(backgroundSessionConfigurationWithIdentifier:),
                               @selector(soopshield_backgroundSessionConfigurationWithIdentifier:));
        SOOPSwizzleClassMethod([NSURLSessionConfiguration class],
                               @selector(backgroundSessionConfiguration:),
                               @selector(soopshield_backgroundSessionConfiguration:));

        SOOPSwizzleClassMethod([NSURLSession class],
                               @selector(sessionWithConfiguration:),
                               @selector(soopshield_sessionWithConfiguration:));
        SOOPSwizzleClassMethod([NSURLSession class],
                               @selector(sessionWithConfiguration:delegate:delegateQueue:),
                               @selector(soopshield_sessionWithConfiguration:delegate:delegateQueue:));
        SOOPSwizzleInstanceMethod([NSURLSession class],
                                  @selector(initWithConfiguration:),
                                  @selector(soopshield_initWithConfiguration:));
        SOOPSwizzleInstanceMethod([NSURLSession class],
                                  @selector(initWithConfiguration:delegate:delegateQueue:),
                                  @selector(soopshield_initWithConfiguration:delegate:delegateQueue:));

        SOOPSwizzleInstanceMethod([WKWebView class],
                                  @selector(initWithFrame:configuration:),
                                  @selector(soopshield_initWithFrame:configuration:));
        SOOPSwizzleInstanceMethod([WKWebView class],
                                  @selector(initWithCoder:),
                                  @selector(soopshield_initWithCoder:));
        SOOPSwizzleInstanceMethod([WKWebView class],
                                  @selector(loadRequest:),
                                  @selector(soopshield_loadRequest:));
        SOOPSwizzleInstanceMethod([WKWebView class],
                                  @selector(loadHTMLString:baseURL:),
                                  @selector(soopshield_loadHTMLString:baseURL:));
    }
}
