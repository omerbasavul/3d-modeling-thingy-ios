#!/usr/bin/env python3

from pathlib import Path
import unittest


REPOSITORY = Path(__file__).resolve().parents[3]
GHOST_INTERN = REPOSITORY / "intern" / "ghost" / "intern"
WINDOW_SOURCE = GHOST_INTERN / "GHOST_WindowIOS.mm"
BAR_HEADER = GHOST_INTERN / "GHOST_IOSShortcutBar.hh"
BAR_SOURCE = GHOST_INTERN / "GHOST_IOSShortcutBar.mm"
POINTER_HEADER = GHOST_INTERN / "GHOST_IOSVirtualPointer.hh"
TUNING_HEADER = GHOST_INTERN / "GHOST_IOSInputTuning.hh"
GHOST_CMAKE = REPOSITORY / "build_files" / "ios" / "cmake" / "ghost_ios.cmake"


def method(source: str, name: str) -> str:
    start = source.rindex(f"- {name}")
    end = source.index("\n}\n", start)
    return source[start:end]


class GhostDirectTouchTests(unittest.TestCase):
    def test_shortcut_bar_is_an_ios_ghost_shim_built_into_ghost(self) -> None:
        cmake = GHOST_CMAKE.read_text()
        self.assertIn("intern/GHOST_IOSShortcutBar.hh", cmake)
        self.assertIn("intern/GHOST_IOSShortcutBar.mm", cmake)

    def test_direct_touch_is_the_remembered_default(self) -> None:
        tuning = TUNING_HEADER.read_text()
        self.assertIn("direct_touch_default = true", tuning)
        source = WINDOW_SOURCE.read_text()
        self.assertIn("GHOST_IOSShortcutBar_storedDirectTouch(", source)
        bar = BAR_SOURCE.read_text()
        self.assertIn("GHOST_IOSDirectTouch", bar)

    def test_direct_tap_clicks_where_the_finger_touches(self) -> None:
        handler = method(WINDOW_SOURCE.read_text(), "(void)handleDirectTap:")
        self.assertIn("getScaledTouchPoint", handler)
        self.assertIn("GHOST_IOSPointerSource::Finger", handler)
        self.assertIn("click(GHOST_kButtonMaskLeft)", handler)
        # A grabbed cursor (transform) confirms in place instead of jumping to the finger.
        self.assertIn("directTouchFollowsFinger", handler)

    def test_direct_hold_is_a_right_click_at_the_finger(self) -> None:
        source = WINDOW_SOURCE.read_text()
        handler = method(source, "(void)handleDirectHold:")
        self.assertIn("GHOST_kButtonMaskRight, true", handler)
        self.assertIn("GHOST_kButtonMaskRight, false", handler)
        self.assertIn("direct_touch_right_click_hold_seconds", source)
        self.assertIn(
            "[direct_tap_gesture_recognizer requireGestureRecognizerToFail:"
            "direct_hold_gesture_recognizer];",
            source,
        )

    def test_direct_drag_presses_at_the_finger_and_goes_relative_when_grabbed(self) -> None:
        source = WINDOW_SOURCE.read_text()
        handler = method(source, "(bool)handleDirectPan:")
        self.assertIn("getScaledInitialTouchPoint", handler)
        self.assertIn("button(GHOST_kButtonMaskLeft, true)", handler)
        self.assertIn("button(GHOST_kButtonMaskLeft, false)", handler)
        self.assertIn("isGrabbed()", handler)
        self.assertIn("beginRelativeAtTime", handler)
        self.assertIn("moveRelativeToAtTime", handler)
        pan = method(source, "(void)handlePan:")
        self.assertIn("direct_touch && [self handleDirectPan:sender]", pan)

    def test_modes_swap_the_one_finger_recognizers(self) -> None:
        handler = method(WINDOW_SOURCE.read_text(), "(void)applyDirectTouchMode")
        for recognizer in (
            "tap_gesture_recognizer",
            "double_tap_drag_gesture_recognizer",
            "triple_tap_gesture_recognizer",
            "direct_tap_gesture_recognizer",
            "direct_hold_gesture_recognizer",
        ):
            self.assertIn(f"{recognizer}.allowedTouchTypes", handler)
        # Pencil keeps clicking through the original tap recognizer in both modes.
        self.assertIn("@[ @(UITouchTypePencil) ]", handler)

    def test_navigation_gestures_aim_at_the_fingers_in_direct_touch(self) -> None:
        source = WINDOW_SOURCE.read_text()
        for name in ("(void)handlePan2f:", "(void)handlePan3f:", "(void)handleZoom:",
                     "(void)handleTwoFingerHold:"):
            self.assertIn("[self aimDirectTouchAtGesture:sender];", method(source, name))
        aim = method(source, "(void)aimDirectTouchAtGesture:")
        self.assertIn("directTouchFollowsFinger", aim)
        self.assertIn("getButtons", aim)

    def test_grab_state_is_exposed_by_the_virtual_pointer(self) -> None:
        self.assertIn("bool isGrabbed() const;", POINTER_HEADER.read_text())

    def test_shortcut_bar_touches_never_reach_blender(self) -> None:
        source = WINDOW_SOURCE.read_text()
        start = source.index("       shouldReceiveTouch:(UITouch *)touch\n{")
        should_receive = source[start:source.index("\n}\n", start)]
        self.assertIn("GHOST_IOSShortcutBar_containsView(shortcut_bar, touch.view)", should_receive)
        send_event = method(source, "(void)sendEvent:")
        self.assertIn("GHOST_IOSShortcutBar_containsView(shortcut_bar, touch.view)", send_event)

    def test_shortcut_keys_apply_on_screen_modifiers_and_release_in_order(self) -> None:
        handler = method(WINDOW_SOURCE.read_text(), "(void)shortcutBarPressed:")
        self.assertLess(handler.index("modifierBeltPointerButton:true"),
                        handler.index("down:true utf8:shortcut.utf8"))
        self.assertLess(handler.index("down:true utf8:shortcut.utf8"),
                        handler.index("modifierBeltPointerButton:false"))

    def test_shortcut_bar_lives_on_main_windows_and_is_destroyed(self) -> None:
        source = WINDOW_SOURCE.read_text()
        self.assertIn("window->isMainWindow() && shortcut_bar == nil", source)
        self.assertIn("GHOST_IOSShortcutBar_destroy(shortcut_bar);", source)
        for recognizer in ("direct_tap_gesture_recognizer", "direct_hold_gesture_recognizer"):
            self.assertIn(
                f"[self releaseGestureRecognizer:{recognizer} fromView:input_view];", source)

    def test_shortcut_keys_expose_identifiers_for_ui_tests(self) -> None:
        bar = BAR_SOURCE.read_text()
        for identifier in (
            "blender_shortcut_bar",
            "blender_shortcut_bar_handle",
            "blender_shortcut_direct_touch",
            "blender_shortcut_g",
            "blender_shortcut_tab",
            "blender_shortcut_numpad_7",
            "blender_shortcut_esc",
        ):
            self.assertIn(f'@"{identifier}"', bar)
        self.assertIn("shortcutBarPressed:", BAR_HEADER.read_text())


if __name__ == "__main__":
    unittest.main()
