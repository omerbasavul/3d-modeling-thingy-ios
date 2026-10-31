/* SPDX-FileCopyrightText: 2026 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

/** \file
 * \ingroup GHOST
 * Native on-screen Blender shortcut keys (G, R, S, Tab, numpad views...) for touch use,
 * plus the switch between direct touch and the trackpad-style virtual cursor.
 */

#pragma once

#include "GHOST_Types.hh"

#ifdef __OBJC__

#import <Foundation/Foundation.h>

@class UIView;

/** One on-screen shortcut: a key with optional modifiers held around it. */
struct GHOST_IOSShortcut {
  GHOST_TKey key;
  const char *utf8;
  bool ctrl;
  bool shift;
  bool alt;
};

@protocol GHOSTIOSShortcutBarDelegate <NSObject>
/** A shortcut key was tapped. Send the key press and release to Blender. */
- (void)shortcutBarPressed:(const GHOST_IOSShortcut &)shortcut;
/** The direct touch switch changed. */
- (void)shortcutBarDirectTouchChanged:(BOOL)direct_touch;
@end

/**
 * Add the bar to \a input_view. It sits at the middle of the left or right screen edge and can be
 * collapsed to a small handle. The delegate is not retained.
 */
NSObject *GHOST_IOSShortcutBar_create(UIView *input_view,
                                      id<GHOSTIOSShortcutBarDelegate> delegate,
                                      bool direct_touch);
void GHOST_IOSShortcutBar_destroy(NSObject *bar);
bool GHOST_IOSShortcutBar_containsView(NSObject *bar, UIView *view);

/** The remembered direct touch choice (NSUserDefaults), or the default when never set. */
bool GHOST_IOSShortcutBar_storedDirectTouch(bool default_value);

#endif
