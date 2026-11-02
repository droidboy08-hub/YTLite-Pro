#import "YTLite.h"
#import <objc/message.h>
#import <objc/runtime.h>

// A floating "capsule" bottom bar, like the pill tab bars in Instagram and similar apps.
// YouTube keeps its own tab buttons; we pack them together, centre them, and draw a rounded
// glass pill behind them that grows or shrinks with the number of tabs.
//
// Design goals from the request:
//  - Consistent: built once, only its frame is updated each layout pass, so it never flickers.
//  - Icons sit inside with even padding, not touching the top, bottom or ends.
//  - Adaptive width: 4 tabs -> wider pill, 3 tabs -> narrower pill.
//  - Frosted glass: Liquid Glass (UIGlassEffect) on iOS 26, a frosted blur on earlier versions.

static const NSInteger kCapTag  = 0x59544C43; // 'YTLC' — the capsule container
static const NSInteger kMatTag  = 0x59544C44; // the glass/material subview

static const CGFloat kHPad     = 16.0; // space inside the pill, left and right of the icons
static const CGFloat kVPad     = 7.0;  // space inside the pill, above and below the icons
static const CGFloat kItemGap  = 2.0;  // gap between adjacent tab buttons once packed
static const CGFloat kSideMin  = 10.0; // the pill never comes closer than this to the screen edge

static BOOL CapsuleOn(void) { return ytlBool(@"capsuleTabBar"); }

static UIVisualEffect *CapsuleEffect(void) {
    // Liquid Glass when the OS has it; a frosted, theme-adapting blur otherwise.
    Class glass = NSClassFromString(@"UIGlassEffect");
    if ([glass respondsToSelector:@selector(effectWithStyle:)]) {
        UIVisualEffect *effect = ((id (*)(id, SEL, NSInteger))objc_msgSend)(glass, @selector(effectWithStyle:), 0); // UIGlassEffectStyleRegular
        if (effect) return effect;
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
}

static UIView *CapsuleMakeView(void) {
    UIView *capsule = [[UIView alloc] initWithFrame:CGRectZero];
    capsule.tag = kCapTag;
    capsule.userInteractionEnabled = NO; // the real buttons sit on top and stay tappable
    capsule.backgroundColor = UIColor.clearColor;
    capsule.layer.shadowColor = UIColor.blackColor.CGColor;
    capsule.layer.shadowOpacity = 0.16;
    capsule.layer.shadowRadius = 10.0;
    capsule.layer.shadowOffset = CGSizeMake(0, 3);

    UIVisualEffect *effect = CapsuleEffect();
    UIVisualEffectView *material = [[UIVisualEffectView alloc] initWithEffect:effect];
    material.tag = kMatTag;
    material.userInteractionEnabled = NO;
    material.clipsToBounds = YES;
    material.layer.cornerCurve = kCACornerCurveContinuous;
    material.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if ([effect isKindOfClass:UIBlurEffect.class]) {
        // A plain blur needs a faint edge to read as a pill; Liquid Glass draws its own.
        material.layer.borderWidth = 0.5;
        material.layer.borderColor = [UIColor colorWithWhite:0.6 alpha:0.30].CGColor;
    }
    [capsule addSubview:material];
    return capsule;
}

static void CollectByClass(UIView *view, Class cls, NSMutableArray *out) {
    for (UIView *sub in view.subviews) {
        if (sub.tag == kCapTag) continue;
        if (cls && [sub isKindOfClass:cls]) [out addObject:sub];
        else CollectByClass(sub, cls, out);
    }
}

// YouTube's own full-width backing view(s), hidden so the pill can float. Idempotent.
static void CapsuleSetBackdropHidden(UIView *bar, BOOL hidden) {
    CGFloat barW = bar.bounds.size.width;
    CGFloat barH = bar.bounds.size.height;
    for (UIView *sub in bar.subviews) {
        if (sub.tag == kCapTag) continue;
        if (sub.frame.size.width >= barW - 1.0 && sub.frame.size.height >= barH * 0.5) {
            if (sub.hidden != hidden) sub.hidden = hidden;
        }
    }
}

static void CapsuleApplyCornerAndShadow(UIView *capsule) {
    CGFloat radius = capsule.bounds.size.height / 2.0;
    UIView *material = [capsule viewWithTag:kMatTag];
    material.frame = capsule.bounds;
    material.layer.cornerRadius = radius;
    capsule.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:capsule.bounds cornerRadius:radius].CGPath;
}

static void CapsuleLayout(UIView *bar) {
    UIView *capsule = [bar viewWithTag:kCapTag];

    if (!CapsuleOn()) {
        if (capsule) [capsule removeFromSuperview];
        // Give YouTube its bar back.
        CapsuleSetBackdropHidden(bar, NO);
        NSMutableArray *indicators = [NSMutableArray array];
        CollectByClass(bar, %c(YTPivotBarIndicatorView), indicators);
        for (UIView *indicator in indicators) indicator.hidden = NO;
        return;
    }

    // Gather the visible tab buttons.
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    CollectByClass(bar, %c(YTPivotBarItemView), items);
    NSMutableArray<UIView *> *visible = [NSMutableArray array];
    for (UIView *item in items) {
        if (!item.hidden && item.alpha > 0.01 && item.bounds.size.width > 1.0) [visible addObject:item];
    }
    // During a transition the buttons can be momentarily absent; keep the last good pill
    // rather than hiding it, so nothing flickers.
    if (visible.count == 0) return;

    [visible sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = [a convertPoint:CGPointZero toView:bar].x;
        CGFloat bx = [b convertPoint:CGPointZero toView:bar].x;
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    // Can we pack the buttons? Only when they share one superview, so the maths stays sane.
    UIView *host = visible.firstObject.superview;
    for (UIView *item in visible) { if (item.superview != host) { host = nil; break; } }

    CGFloat barW = bar.bounds.size.width;
    CGFloat totalItemsW = 0;
    CGFloat top = CGFLOAT_MAX, bottom = -CGFLOAT_MAX;
    for (UIView *item in visible) {
        totalItemsW += item.bounds.size.width;
        CGRect inBar = [item convertRect:item.bounds toView:bar];
        top = MIN(top, CGRectGetMinY(inBar));
        bottom = MAX(bottom, CGRectGetMaxY(inBar));
    }
    totalItemsW += kItemGap * (visible.count - 1);

    CGRect frame;
    if (host) {
        // Pack the buttons tight and centre them (horizontal only; keep YouTube's vertical placement).
        CGFloat startXInBar = (barW - totalItemsW) / 2.0;
        CGFloat cursor = startXInBar;
        for (UIView *item in visible) {
            CGFloat targetXInHost = [bar convertPoint:CGPointMake(cursor, 0) toView:host].x;
            CGRect f = item.frame;
            f.origin.x = targetXInHost;
            if (!CGRectEqualToRect(item.frame, f)) item.frame = f;
            cursor += item.bounds.size.width + kItemGap;
        }
        frame = CGRectMake(startXInBar - kHPad, top - kVPad, totalItemsW + 2 * kHPad, (bottom - top) + 2 * kVPad);
    } else {
        // Fallback: wrap the buttons where they are.
        CGFloat left = CGFLOAT_MAX, right = -CGFLOAT_MAX;
        for (UIView *item in visible) {
            CGRect inBar = [item convertRect:item.bounds toView:bar];
            left = MIN(left, CGRectGetMinX(inBar));
            right = MAX(right, CGRectGetMaxX(inBar));
        }
        frame = CGRectMake(left - kHPad, top - kVPad, (right - left) + 2 * kHPad, (bottom - top) + 2 * kVPad);
    }

    // Keep the pill off the screen edges.
    if (frame.size.width > barW - 2 * kSideMin) {
        frame.origin.x = kSideMin;
        frame.size.width = barW - 2 * kSideMin;
    }
    if (frame.size.width <= 0 || frame.size.height <= 0) return;

    bar.backgroundColor = UIColor.clearColor;
    CapsuleSetBackdropHidden(bar, YES);

    // The little selection indicator would be left behind once buttons move, so hide it in pill mode.
    NSMutableArray *indicators = [NSMutableArray array];
    CollectByClass(bar, %c(YTPivotBarIndicatorView), indicators);
    for (UIView *indicator in indicators) { if (!indicator.hidden) indicator.hidden = YES; }

    if (!capsule) {
        capsule = CapsuleMakeView();
        [bar insertSubview:capsule atIndex:0];
    } else if (bar.subviews.firstObject != capsule) {
        [bar sendSubviewToBack:capsule];
    }

    if (!CGRectEqualToRect(capsule.frame, frame)) {
        capsule.frame = frame;
        CapsuleApplyCornerAndShadow(capsule);
    }
}

%hook YTPivotBarView
- (void)layoutSubviews {
    %orig;
    CapsuleLayout(self);
}
- (void)setBackgroundColor:(UIColor *)color {
    %orig(CapsuleOn() ? UIColor.clearColor : color);
}
%end
