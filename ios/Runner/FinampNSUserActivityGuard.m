// FinampNSUserActivityGuard.m
//
// iOS throws NSInvalidArgumentException when NSUserActivity is created with a
// nil/empty activityType (keyboard autofill + ASWebAuthentication / Safari
// sheets during Tailscale interactive login). Declaring NSUserActivityTypes
// in Info.plist is necessary but NOT sufficient — empty types still abort.
// Remap empty types to a declared reverse-DNS id before Foundation raises.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static id (*finamp_orig_initWithActivityType)(id, SEL, NSString *);

static id finamp_initWithActivityType(id self, SEL _cmd, NSString *activityType) {
  if (activityType == nil || activityType.length == 0) {
    NSString *bundleId = NSBundle.mainBundle.bundleIdentifier;
    activityType = (bundleId.length > 0)
                       ? [bundleId stringByAppendingString:@".browsing"]
                       : @"com.finamp.browsing";
    NSLog(@"[FINAMP] Replaced empty NSUserActivity activityType with %@",
          activityType);
  }
  return finamp_orig_initWithActivityType(self, _cmd, activityType);
}

@interface FinampNSUserActivityGuard : NSObject
@end

@implementation FinampNSUserActivityGuard

+ (void)load {
  Method method = class_getInstanceMethod([NSUserActivity class],
                                          @selector(initWithActivityType:));
  if (method == NULL) {
    return;
  }
  finamp_orig_initWithActivityType =
      (id(*)(id, SEL, NSString *))method_getImplementation(method);
  method_setImplementation(method, (IMP)finamp_initWithActivityType);
}

@end
