"""Track display transitions without retaining cursor coordinates."""


class ScreenTransitionTracker:
    """Pulse on an observed display change, with a short anti-chatter window."""

    def __init__(self, cooldown_seconds=0.25):
        self.cooldown_seconds = cooldown_seconds
        self.reset()

    def reset(self):
        self._layout = None
        self._screen = None
        self._last_pulse_at = None

    def observe(self, screen, layout, now):
        # Startup, hotplug and rearrangement establish a silent baseline.
        if layout != self._layout:
            self.reset()
            self._layout = layout
            self._screen = screen
            return False
        previous = self._screen
        self._screen = screen
        # Qt can report no screen in a virtual-desktop gap or during teardown.
        if screen is None or previous is None or screen == previous:
            return False
        if self._last_pulse_at is not None and now - self._last_pulse_at < self.cooldown_seconds:
            return False
        self._last_pulse_at = now
        return True
