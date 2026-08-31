// Leitner-style spaced repetition. Stage index -> delay before next review.
const STAGE_INTERVALS_MS = [
  0,                       // stage 0: due immediately (new / just missed)
  10 * 60 * 1000,          // stage 1: 10 minutes
  24 * 60 * 60 * 1000,     // stage 2: 1 day
  3 * 24 * 60 * 60 * 1000, // stage 3: 3 days
  7 * 24 * 60 * 60 * 1000, // stage 4: 1 week
  30 * 24 * 60 * 60 * 1000 // stage 5: 1 month (mastered)
];
export const MAX_STAGE = STAGE_INTERVALS_MS.length - 1;
const STORAGE_KEY = 'korean.srs';

export function loadState(vocab) {
  let saved = {};
  try {
    saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
  } catch {
    saved = {};
  }
  const now = Date.now();
  const state = {};
  for (const word of vocab) {
    state[word.id] = saved[word.id] || { stage: 0, nextReview: now };
  }
  return state;
}

export function saveState(state) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

export function pickDueWord(vocab, state) {
  const now = Date.now();
  const due = vocab.filter((word) => state[word.id].nextReview <= now);
  const pool = due.length > 0 ? due : vocab;
  return pool.reduce((soonest, word) =>
    state[word.id].nextReview < state[soonest.id].nextReview ? word : soonest
  , pool[0]);
}

export function recordResult(state, wordId, correct) {
  const entry = state[wordId];
  const stage = correct ? Math.min(entry.stage + 1, MAX_STAGE) : 0;
  state[wordId] = { stage, nextReview: Date.now() + STAGE_INTERVALS_MS[stage] };
  return state;
}

export function dueCount(vocab, state) {
  const now = Date.now();
  return vocab.filter((word) => state[word.id].nextReview <= now).length;
}
