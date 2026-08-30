# Learn Korean

A hands-free Korean language tutor for Rokid glasses. Modeled after the
existing "Learn Chinese" agent in the Rokid Agent Store, retargeted at
Korean (Hangul).

## Capabilities

- **Flashcards** — cycles through everyday Korean words and phrases,
  showing Hangul, romanization, and English meaning, with text-to-speech
  playback of native pronunciation.
- **Practice** — listens to the wearer's spoken attempt via ASR, compares
  it against the target phrase, and uses an LLM tutor persona to give a
  short spoken correction or encouragement.
- **Chat** — open-ended spoken conversation practice; the wearer asks
  questions ("how do I say X?", "when do I use 이 vs 가?") and the LLM
  tutor answers and speaks the answer back.

## Interaction model

Voice-first, glasses-appropriate: tap to cycle modes/words, hold the
hardware key (or say the wake phrase) to speak. No keyboard input.

## Persisted state

Streak count and last-seen vocab index are kept in `localStorage` so
progress survives an app restart.
