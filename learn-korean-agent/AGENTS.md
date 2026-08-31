# Learn Korean

A hands-free Korean language tutor for Rokid glasses. Modeled after the
existing "Learn Chinese" agent in the Rokid Agent Store, retargeted at
Korean (Hangul).

## Capabilities

- **Review** — the core mode, matching how the reference "Learn Chinese"
  agent works: a due word is shown (Hangul + romanization) and spoken via
  TTS, then two candidate meanings drop down from the top of the display,
  one on the left and one on the right. The wearer tilts their head toward
  the correct meaning; the glasses' orientation sensor picks up the tilt
  and locks in that side as the answer. This is how reading, pronunciation,
  and meaning are all reinforced in one pass. Answers drive a spaced-
  repetition scheduler so words you get wrong resurface sooner.
- **Scenario** — spoken roleplay practice in a real-world context (ordering
  coffee, asking directions, meeting someone, bargaining at a market), with
  an LLM playing an in-character local.
- **Chat** — open-ended spoken conversation practice; the wearer asks
  questions ("how do I say X?", "when do I use 이 vs 가?") and the LLM
  tutor answers and speaks the answer back.
- **Mnemonics** — on demand, an LLM generates a short memorable English
  mnemonic for the current word (cached after first generation).

## Interaction model

Voice-first, glasses-appropriate. In Review mode, answers are selected by
tilting the head left/right (`AbsoluteOrientationSensor`, roll axis) with
tap-on-the-option as a fallback for when the sensor is unavailable. Scenario
and Chat modes are push-to-talk via the hardware key or wake phrase.

## Persisted state

Per-word spaced-repetition state (review stage + next-due time) is kept in
`localStorage`, along with a cache of generated mnemonics, so progress
survives an app restart.
