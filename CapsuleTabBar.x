#import "YTLite.h"
#import <objc/message.h>
#import <objc/runtime.h>

// Capsule tab bar: YouTube's bottom bar (YTPivotBarView) keeps its own frame and tab layout, but
// its background is cleared and a rounded, floating capsule is drawn behind the tab buttons. The
// capsule uses Liquid Glass on iOS 26 and a system blur on earlier versions.

static const NSInteger kYTLCapsuleTag = 0x59544C43; // 'YTLC'
static const CGFloat kYTLCapsuleMargin = 12.0;
static const void *kYTLCapsuleHiddenViewsKey = &kYTLCapsuleHiddenViewsKey;
static const void *kYTLCapsuleBarColorKey = &kYTLCapsuleBarColorKey;

static BOOL YTLCapsuleEnabled(void) {
    return ytlBool(@"capsuleTabBar");
}

static UIVisualEffect *YTLCapsuleEffect(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if ([glass respondsToSelector:@selector(effectWithStyle:)]) {
        UIVisualEffect *effect = ((id (*)(id, SEL, NSInteger))objc_msgSend)(glass, @selector(effectWithStyle:), 0); // UIGlassEffectStyleRegular
        if (effect) return effect;
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
}

static BOOL YTLIsPivotItemView(UIView *view) {
    if ([view isKindOfClass:%c(YTPivotBarItemView)]) return YES;
    NSString *name = NSStringFromClass(view.class);
    return [name hasPrefix:@"YTPivotBar"] && [name hasSuffix:@"ItemView"];
}

static BOOL YTLContainsPivotItem(UIView *view) {
    if (YTLIsPivotItemView(view)) return YES;
    for (UIView *subview in view.subviews) {
        if (YTLContainsPivotItem(subview)) return YES;
    }
    return NO;
}

static void YTLCollectPivotItems(UIView *view, NSMutableArray<UIView *> *items) {
    for (UIView *subview in view.subviews) {
        if (subview.tag == kYTLCapsuleTag) continue;
        if (YTLIsPivotItemView(subview)) {
            if (!subview.hidden && subview.alpha > 0.01) [items addObject:subview];
        } else {
            YTLCollectPivotItems(subview, items);
        }
    }
}

static UIView *YTLMakeCapsule(void) {
    UIView *capsule = [[UIView alloc] initWithFrame:CGRectZero];
    capsule.tag = kYTLCapsuleTag;
    capsule.userInteractionEnabled = NO;
    capsule.backgroundColor = UIColor.clearColor;
    capsule.layer.shadowColor = UIColor.blackColor.CGColor;
    capsule.layer.shadowOpacity = 0.18;
    capsule.layer.shadowRadius = 12.0;
    capsule.layer.shadowOffset = CGSizeMake(0, 4);

    UIVisualEffect *effect = YTLCapsuleEffect();
    UIVisualEffectView *material = [[UIVisualEffectView alloc] initWithEffect:effect];
    material.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    material.userInteractionEnabled = NO;
    material.clipsToBounds = YES;
    material.layer.cornerCurve = kCACornerCurveContinuous;
    if ([effect isKindOfClass:UIBlurEffect.class]) {
        // Glass draws its own edge; a blur needs a hairline to stand out from the content behind it.
        material.layer.borderWidth = 0.5;
        material.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.25].CGColor;
    }
    [capsule addSubview:material];
    return capsule;
}

// YouTube's own background and separator views are hidden while the capsule is on, and shown again
// when it is turned off.
static void YTLSetBarChromeHidden(UIView *bar, BOOL hidden) {
    NSHashTable<UIView *> *hiddenViews = objc_getAssociatedObject(bar, kYTLCapsuleHiddenViewsKey);
    if (!hidden) {
        for (UIView *view in hiddenViews) view.hidden = NO;
        [hiddenViews removeAllObjects];
        return;
    }
    if (!hiddenViews) {
        hiddenViews = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(bar, kYTLCapsuleHiddenViewsKey, hiddenViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGRect bounds = bar.bounds;
    for (UIView *subview in bar.subviews) {
        if (subview.tag == kYTLCapsuleTag || subview.hidden || YTLContainsPivotItem(subview)) continue;
        CGRect frame = subview.frame;
        BOOL separator = frame.size.height <= 1.5 || frame.size.width <= 1.5;
        BOOL background = frame.size.width >= bounds.size.width * 0.9 && frame.size.height >= bounds.size.height * 0.5;
        if (separator || background) {
            subview.hidden = YES;
            [hiddenViews addObject:subview];
        }
    }
}

static void YTLLayoutCapsule(UIView *bar) {
    UIView *capsule = [bar viewWithTag:kYTLCapsuleTag];
    if (!YTLCapsuleEnabled()) {
        if (capsule) {
            [capsule removeFromSuperview];
            YTLSetBarChromeHidden(bar, NO);
            bar.backgroundColor = objc_getAssociatedObject(bar, kYTLCapsuleBarColorKey);
        }
        return;
    }

    bar.backgroundColor = UIColor.clearColor;
    YTLSetBarChromeHidden(bar, YES);

    NSMutableArray<UIView *> *items = [NSMutableArray array];
    YTLCollectPivotItems(bar, items);
    CGRect area = CGRectNull;
    for (UIView *item in items) {
        area = CGRectUnion(area, [item convertRect:item.bounds toView:bar]);
    }
    if (CGRectIsNull(area) || area.size.height < 1.0) {
        // No tab buttons found: use the part of the bar above the home indicator.
        area = UIEdgeInsetsInsetRect(bar.bounds, UIEdgeInsetsMake(0, 0, bar.safeAreaInsets.bottom, 0));
    }

    CGFloat top = MAX(CGRectGetMinY(area) - 2.0, 2.0);
    CGFloat bottom = MIN(CGRectGetMaxY(area) + 2.0, CGRectGetHeight(bar.bounds));
    CGRect frame = CGRectMake(kYTLCapsuleMargin, top, CGRectGetWidth(bar.bounds) - 2.0 * kYTLCapsuleMargin, bottom - top);
    if (frame.size.width <= 0 || frame.size.height <= 0) {
        capsule.hidden = YES;
        return;
    }

    if (!capsule) capsule = YTLMakeCapsule();
    if (capsule.superview != bar) [bar insertSubview:capsule atIndex:0];
    else if (bar.subviews.firstObject != capsule) [bar sendSubviewToBack:capsule];

    capsule.hidden = NO;
    if (!CGRectEqualToRect(capsule.frame, frame)) {
        capsule.frame = frame;
        CGFloat radius = frame.size.height / 2.0;
        capsule.subviews.firstObject.layer.cornerRadius = radius;
        capsule.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:capsule.bounds cornerRadius:radius].CGPath;
    }
}

%hook YTPivotBarView
- (void)layoutSubviews {
    %orig;
    YTLLayoutCapsule(self);
}

- (void)setBackgroundColor:(UIColor *)color {
    // Remember YouTube's colour so it can be put back when the capsule is turned off.
    if (color && ![color isEqual:UIColor.clearColor]) {
        objc_setAssociatedObject(self, kYTLCapsuleBarColorKey, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    %orig(YTLCapsuleEnabled() ? UIColor.clearColor : color);
}
%end
