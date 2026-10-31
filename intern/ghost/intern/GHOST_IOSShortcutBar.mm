/* SPDX-FileCopyrightText: 2026 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

/** \file
 * \ingroup GHOST
 * Native on-screen Blender shortcut keys for touch use.
 *
 * A column of keys at the middle of the left or right screen edge. The top button switches
 * between direct touch (a finger clicks and drags where it touches) and the trackpad-style
 * virtual cursor. A handle collapses the keys; drag the handle to move the bar to the other edge.
 * Keys apply the on-screen Shift/Ctrl/Alt/Cmd state, so Shift then A opens the Add menu.
 */

#import <UIKit/UIKit.h>

#include "GHOST_IOSShortcutBar.hh"

static NSString *const GHOST_IOSShortcutBarRight = @"GHOST_IOSShortcutBarRight";
static NSString *const GHOST_IOSShortcutBarExpanded = @"GHOST_IOSShortcutBarExpanded";
static NSString *const GHOST_IOSDirectTouch = @"GHOST_IOSDirectTouch";

static constexpr CGFloat key_width = 46.0f;
static constexpr CGFloat key_height = 38.0f;
static constexpr CGFloat key_spacing = 4.0f;
static constexpr CGFloat bar_padding = 5.0f;
static constexpr CGFloat handle_size = 40.0f;
static constexpr CGFloat edge_inset = 6.0f;

struct GHOST_IOSShortcutKeyInfo {
  NSString *title;
  NSString *identifier;
  GHOST_IOSShortcut shortcut;
};

/* Two keys per row. Numpad keys drive the view: front, right, top, perspective, frame
 * selected and camera. */
static const GHOST_IOSShortcutKeyInfo GHOST_IOS_SHORTCUT_KEYS[] = {
    {@"Esc", @"blender_shortcut_esc", {GHOST_kKeyEsc, nullptr, false, false, false}},
    {@"Enter", @"blender_shortcut_enter", {GHOST_kKeyEnter, nullptr, false, false, false}},
    {@"G", @"blender_shortcut_g", {GHOST_kKeyG, "g", false, false, false}},
    {@"R", @"blender_shortcut_r", {GHOST_kKeyR, "r", false, false, false}},
    {@"S", @"blender_shortcut_s", {GHOST_kKeyS, "s", false, false, false}},
    {@"Tab", @"blender_shortcut_tab", {GHOST_kKeyTab, nullptr, false, false, false}},
    {@"X", @"blender_shortcut_x", {GHOST_kKeyX, "x", false, false, false}},
    {@"Y", @"blender_shortcut_y", {GHOST_kKeyY, "y", false, false, false}},
    {@"Z", @"blender_shortcut_z", {GHOST_kKeyZ, "z", false, false, false}},
    {@"I", @"blender_shortcut_i", {GHOST_kKeyI, "i", false, false, false}},
    {@"A", @"blender_shortcut_a", {GHOST_kKeyA, "a", false, false, false}},
    {@"Del", @"blender_shortcut_delete", {GHOST_kKeyDelete, nullptr, false, false, false}},
    {@"E", @"blender_shortcut_e", {GHOST_kKeyE, "e", false, false, false}},
    {@"D", @"blender_shortcut_d", {GHOST_kKeyD, "d", false, false, false}},
    {@"H", @"blender_shortcut_h", {GHOST_kKeyH, "h", false, false, false}},
    {@"N", @"blender_shortcut_n", {GHOST_kKeyN, "n", false, false, false}},
    {@"1", @"blender_shortcut_numpad_1", {GHOST_kKeyNumpad1, nullptr, false, false, false}},
    {@"3", @"blender_shortcut_numpad_3", {GHOST_kKeyNumpad3, nullptr, false, false, false}},
    {@"7", @"blender_shortcut_numpad_7", {GHOST_kKeyNumpad7, nullptr, false, false, false}},
    {@"5", @"blender_shortcut_numpad_5", {GHOST_kKeyNumpad5, nullptr, false, false, false}},
    {@".", @"blender_shortcut_numpad_period", {GHOST_kKeyNumpadPeriod, nullptr, false, false, false}},
    {@"0", @"blender_shortcut_numpad_0", {GHOST_kKeyNumpad0, nullptr, false, false, false}},
    {@"Save", @"blender_shortcut_save", {GHOST_kKeyS, "s", true, false, false}},
    {@"F3", @"blender_shortcut_search", {GHOST_kKeyF3, nullptr, false, false, false}},
};
static constexpr int GHOST_IOS_SHORTCUT_KEY_COUNT = sizeof(GHOST_IOS_SHORTCUT_KEYS) /
                                                    sizeof(*GHOST_IOS_SHORTCUT_KEYS);

bool GHOST_IOSShortcutBar_storedDirectTouch(const bool default_value)
{
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  if ([defaults objectForKey:GHOST_IOSDirectTouch] == nil) {
    return default_value;
  }
  return [defaults boolForKey:GHOST_IOSDirectTouch];
}

static UIImage *GHOST_IOSShortcutSymbol(NSString *name, const CGFloat size)
{
  UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration
      configurationWithPointSize:size
                          weight:UIImageSymbolWeightSemibold];
  return [UIImage systemImageNamed:name withConfiguration:config];
}

/* -------------------------------------------------------------------- */
/** \name Bar
 * \{ */

@interface GHOSTIOSShortcutBarView : UIView {
  id<GHOSTIOSShortcutBarDelegate> delegate_;
  UIVisualEffectView *background_;
  UIStackView *column_;
  UIStackView *keys_column_;
  UIView *handle_;
  UIImageView *handle_icon_;
  UIButton *direct_button_;
  NSArray<NSLayoutConstraint *> *edge_constraints_;
  UIPanGestureRecognizer *pan_;
  UITapGestureRecognizer *tap_;
  BOOL right_;
  BOOL expanded_;
  BOOL direct_touch_;
}
- (instancetype)initWithInputView:(UIView *)input_view
                         delegate:(id<GHOSTIOSShortcutBarDelegate>)delegate
                      directTouch:(BOOL)direct_touch;
- (void)teardown;
@end

@implementation GHOSTIOSShortcutBarView

- (UIButton *)makeKeyWithTitle:(NSString *)title identifier:(NSString *)identifier tag:(NSInteger)tag
{
  UIButton *key = [UIButton buttonWithType:UIButtonTypeCustom];
  key.translatesAutoresizingMaskIntoConstraints = NO;
  key.tag = tag;
  key.layer.cornerRadius = 9.0f;
  key.layer.cornerCurve = kCACornerCurveContinuous;
  key.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.10f];
  key.titleLabel.font = [UIFont systemFontOfSize:15.0f weight:UIFontWeightSemibold];
  key.titleLabel.adjustsFontSizeToFitWidth = YES;
  key.titleLabel.minimumScaleFactor = 0.6f;
  [key setTitle:title forState:UIControlStateNormal];
  [key setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  key.accessibilityIdentifier = identifier;
  [key addTarget:self action:@selector(keyDown:) forControlEvents:UIControlEventTouchDown];
  [key addTarget:self
                action:@selector(keyUp:)
      forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
  [key addTarget:self action:@selector(keyPressed:) forControlEvents:UIControlEventTouchUpInside];
  [NSLayoutConstraint activateConstraints:@[
    [key.widthAnchor constraintEqualToConstant:key_width],
    [key.heightAnchor constraintEqualToConstant:key_height],
  ]];
  return key;
}

- (instancetype)initWithInputView:(UIView *)input_view
                         delegate:(id<GHOSTIOSShortcutBarDelegate>)delegate
                      directTouch:(BOOL)direct_touch
{
  self = [super initWithFrame:CGRectZero];
  if (self == nil) {
    return nil;
  }
  delegate_ = delegate;
  direct_touch_ = direct_touch;
  edge_constraints_ = nil;

  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  right_ = [defaults boolForKey:GHOST_IOSShortcutBarRight];
  expanded_ = [defaults objectForKey:GHOST_IOSShortcutBarExpanded] != nil ?
                  [defaults boolForKey:GHOST_IOSShortcutBarExpanded] :
                  YES;

  self.translatesAutoresizingMaskIntoConstraints = NO;
  self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
  self.accessibilityIdentifier = @"blender_shortcut_bar";
  self.layer.shadowColor = UIColor.blackColor.CGColor;
  self.layer.shadowOpacity = 0.3f;
  self.layer.shadowRadius = 8.0f;
  self.layer.shadowOffset = CGSizeMake(0.0f, 2.0f);

  background_ = [[UIVisualEffectView alloc]
      initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
  background_.translatesAutoresizingMaskIntoConstraints = NO;
  background_.layer.cornerRadius = 14.0f;
  background_.layer.cornerCurve = kCACornerCurveContinuous;
  background_.clipsToBounds = YES;
  background_.userInteractionEnabled = NO;
  [self addSubview:background_];

  /* Handle: tap to collapse or expand, drag to move to the other edge. */
  handle_ = [[UIView alloc] init];
  handle_.translatesAutoresizingMaskIntoConstraints = NO;
  handle_.isAccessibilityElement = YES;
  handle_.accessibilityTraits = UIAccessibilityTraitButton;
  handle_.accessibilityLabel = @"Shortcut keys";
  handle_.accessibilityIdentifier = @"blender_shortcut_bar_handle";
  handle_icon_ = [[UIImageView alloc] init];
  handle_icon_.translatesAutoresizingMaskIntoConstraints = NO;
  handle_icon_.contentMode = UIViewContentModeCenter;
  handle_icon_.tintColor = UIColor.whiteColor;
  [handle_ addSubview:handle_icon_];
  tap_ = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
  pan_ = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
  pan_.maximumNumberOfTouches = 1;
  [handle_ addGestureRecognizer:tap_];
  [handle_ addGestureRecognizer:pan_];

  /* Direct touch switch. */
  direct_button_ = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
  direct_button_.translatesAutoresizingMaskIntoConstraints = NO;
  direct_button_.layer.cornerRadius = 9.0f;
  direct_button_.layer.cornerCurve = kCACornerCurveContinuous;
  direct_button_.tintColor = UIColor.whiteColor;
  direct_button_.accessibilityIdentifier = @"blender_shortcut_direct_touch";
  [direct_button_ addTarget:self
                     action:@selector(toggleDirectTouch:)
           forControlEvents:UIControlEventTouchUpInside];

  /* Keys, two per row. */
  keys_column_ = [[UIStackView alloc] init];
  keys_column_.translatesAutoresizingMaskIntoConstraints = NO;
  keys_column_.axis = UILayoutConstraintAxisVertical;
  keys_column_.spacing = key_spacing;
  keys_column_.alignment = UIStackViewAlignmentCenter;

  UIStackView *top_row = [[[UIStackView alloc] init] autorelease];
  top_row.axis = UILayoutConstraintAxisHorizontal;
  top_row.spacing = key_spacing;
  top_row.alignment = UIStackViewAlignmentCenter;
  [top_row addArrangedSubview:direct_button_];
  [keys_column_ addArrangedSubview:top_row];

  for (int i = 0; i < GHOST_IOS_SHORTCUT_KEY_COUNT; i += 2) {
    UIStackView *row = [[[UIStackView alloc] init] autorelease];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = key_spacing;
    for (int j = i; j < i + 2 && j < GHOST_IOS_SHORTCUT_KEY_COUNT; j++) {
      const GHOST_IOSShortcutKeyInfo &info = GHOST_IOS_SHORTCUT_KEYS[j];
      [row addArrangedSubview:[self makeKeyWithTitle:info.title
                                          identifier:info.identifier
                                                 tag:j]];
    }
    [keys_column_ addArrangedSubview:row];
  }

  column_ = [[UIStackView alloc] init];
  column_.translatesAutoresizingMaskIntoConstraints = NO;
  column_.axis = UILayoutConstraintAxisVertical;
  column_.spacing = key_spacing;
  column_.alignment = UIStackViewAlignmentCenter;
  [column_ addArrangedSubview:handle_];
  [column_ addArrangedSubview:keys_column_];
  [self addSubview:column_];

  [NSLayoutConstraint activateConstraints:@[
    [background_.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [background_.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    [background_.topAnchor constraintEqualToAnchor:self.topAnchor],
    [background_.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [column_.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:bar_padding],
    [column_.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-bar_padding],
    [column_.topAnchor constraintEqualToAnchor:self.topAnchor constant:bar_padding],
    [column_.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-bar_padding],
    [handle_.widthAnchor constraintEqualToConstant:handle_size],
    [handle_.heightAnchor constraintEqualToConstant:handle_size - 10.0f],
    [handle_icon_.centerXAnchor constraintEqualToAnchor:handle_.centerXAnchor],
    [handle_icon_.centerYAnchor constraintEqualToAnchor:handle_.centerYAnchor],
    [direct_button_.widthAnchor constraintEqualToConstant:key_width * 2.0f + key_spacing],
    [direct_button_.heightAnchor constraintEqualToConstant:key_height],
  ]];

  [input_view addSubview:self];
  [self activateEdgeConstraints];
  keys_column_.hidden = !expanded_;
  [self updateHandle];
  [self updateDirectButton];
  return self;
}

- (void)teardown
{
  [handle_ removeGestureRecognizer:tap_];
  [handle_ removeGestureRecognizer:pan_];
  delegate_ = nil;
  [self removeFromSuperview];
}

- (void)dealloc
{
  [background_ release];
  [column_ release];
  [keys_column_ release];
  [handle_ release];
  [handle_icon_ release];
  [direct_button_ release];
  [edge_constraints_ release];
  [pan_ release];
  [tap_ release];
  [super dealloc];
}

- (void)activateEdgeConstraints
{
  UIView *parent = self.superview;
  if (parent == nil) {
    return;
  }
  if (edge_constraints_ != nil) {
    [NSLayoutConstraint deactivateConstraints:edge_constraints_];
    [edge_constraints_ release];
  }
  UILayoutGuide *safe_area = parent.safeAreaLayoutGuide;
  NSLayoutConstraint *horizontal =
      right_ ? [self.trailingAnchor constraintEqualToAnchor:safe_area.trailingAnchor
                                                   constant:-edge_inset] :
               [self.leadingAnchor constraintEqualToAnchor:safe_area.leadingAnchor
                                                  constant:edge_inset];
  NSLayoutConstraint *vertical = [self.centerYAnchor
      constraintEqualToAnchor:safe_area.centerYAnchor];
  edge_constraints_ = [@[ horizontal, vertical ] retain];
  [NSLayoutConstraint activateConstraints:edge_constraints_];
}

- (void)updateHandle
{
  handle_icon_.image = GHOST_IOSShortcutSymbol(expanded_ ? @"chevron.up" : @"command", 16.0f);
  handle_.accessibilityValue = expanded_ ? @"expanded" : @"collapsed";
}

- (void)updateDirectButton
{
  [direct_button_ setImage:GHOST_IOSShortcutSymbol(direct_touch_ ? @"hand.point.up.left.fill" :
                                                                   @"cursorarrow.motionlines",
                                                   16.0f)
                  forState:UIControlStateNormal];
  direct_button_.backgroundColor = direct_touch_ ? UIColor.systemBlueColor :
                                                   [UIColor colorWithWhite:1.0f alpha:0.10f];
  direct_button_.accessibilityLabel = direct_touch_ ? @"Direct touch" : @"Trackpad cursor";
  direct_button_.accessibilityValue = direct_touch_ ? @"on" : @"off";
}

- (void)setExpanded:(BOOL)expanded
{
  if (expanded_ == expanded) {
    return;
  }
  expanded_ = expanded;
  [NSUserDefaults.standardUserDefaults setBool:expanded_ forKey:GHOST_IOSShortcutBarExpanded];
  [UIView animateWithDuration:0.25
                        delay:0.0
       usingSpringWithDamping:0.9f
        initialSpringVelocity:0.0f
                      options:UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     keys_column_.hidden = !expanded;
                     keys_column_.alpha = expanded ? 1.0f : 0.0f;
                     [self.superview layoutIfNeeded];
                   }
                   completion:nil];
  [self updateHandle];
}

- (void)handleTap:(UITapGestureRecognizer *)sender
{
  if (sender.state == UIGestureRecognizerStateEnded) {
    [self setExpanded:!expanded_];
  }
}

- (void)handlePan:(UIPanGestureRecognizer *)sender
{
  UIView *parent = self.superview;
  if (parent == nil) {
    return;
  }
  const CGPoint translation = [sender translationInView:parent];
  if (sender.state == UIGestureRecognizerStateBegan ||
      sender.state == UIGestureRecognizerStateChanged)
  {
    self.transform = CGAffineTransformMakeTranslation(translation.x, translation.y);
    return;
  }
  if (sender.state != UIGestureRecognizerStateEnded &&
      sender.state != UIGestureRecognizerStateCancelled)
  {
    return;
  }
  /* Snap to the nearer screen edge. */
  const CGRect dropped = self.frame;
  const CGRect safe = parent.safeAreaLayoutGuide.layoutFrame;
  right_ = CGRectGetMidX(dropped) > CGRectGetMidX(safe);
  [NSUserDefaults.standardUserDefaults setBool:right_ forKey:GHOST_IOSShortcutBarRight];
  self.transform = CGAffineTransformIdentity;
  [self activateEdgeConstraints];
  [parent layoutIfNeeded];
  const CGRect settled = self.frame;
  self.transform = CGAffineTransformMakeTranslation(CGRectGetMinX(dropped) - CGRectGetMinX(settled),
                                                    CGRectGetMinY(dropped) - CGRectGetMinY(settled));
  [UIView animateWithDuration:0.35
                        delay:0.0
       usingSpringWithDamping:0.82f
        initialSpringVelocity:0.0f
                      options:UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     self.transform = CGAffineTransformIdentity;
                   }
                   completion:nil];
}

- (void)keyDown:(UIButton *)sender
{
  sender.backgroundColor = UIColor.systemBlueColor;
}

- (void)keyUp:(UIButton *)sender
{
  sender.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.10f];
}

- (void)keyPressed:(UIButton *)sender
{
  [self keyUp:sender];
  const NSInteger index = sender.tag;
  if (index < 0 || index >= GHOST_IOS_SHORTCUT_KEY_COUNT) {
    return;
  }
  [delegate_ shortcutBarPressed:GHOST_IOS_SHORTCUT_KEYS[index].shortcut];
}

- (void)toggleDirectTouch:(UIButton *)sender
{
  (void)sender;
  direct_touch_ = !direct_touch_;
  [NSUserDefaults.standardUserDefaults setBool:direct_touch_ forKey:GHOST_IOSDirectTouch];
  [self updateDirectButton];
  [delegate_ shortcutBarDirectTouchChanged:direct_touch_];
}

@end

/** \} */

/* -------------------------------------------------------------------- */
/** \name C API
 * \{ */

NSObject *GHOST_IOSShortcutBar_create(UIView *input_view,
                                      id<GHOSTIOSShortcutBarDelegate> delegate,
                                      const bool direct_touch)
{
  if (input_view == nil) {
    return nil;
  }
  return [[GHOSTIOSShortcutBarView alloc] initWithInputView:input_view
                                                   delegate:delegate
                                                directTouch:direct_touch];
}

void GHOST_IOSShortcutBar_destroy(NSObject *bar)
{
  if (bar == nil) {
    return;
  }
  [(GHOSTIOSShortcutBarView *)bar teardown];
  [bar release];
}

bool GHOST_IOSShortcutBar_containsView(NSObject *bar, UIView *view)
{
  if (bar == nil || view == nil) {
    return false;
  }
  return [view isDescendantOfView:(GHOSTIOSShortcutBarView *)bar];
}

/** \} */
