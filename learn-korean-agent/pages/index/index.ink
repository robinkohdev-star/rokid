<script def>
{
  "navigationBarTitleText": "Learn Korean",
  "description": "Hands-free Korean tutor: spaced-repetition word recognition where two meanings drop from the top and the wearer tilts their head left/right to answer, scenario roleplay conversations, AI-generated mnemonics, and free-form voice chat with a Korean tutor persona.",
  "schema": {
    "data": {
      "type": "object",
      "properties": {
        "mode": { "enum": ["review", "scenario", "chat"] },
        "category": { "enum": ["descriptive", "conjunction", "objects", "mix"] },
        "direction": { "enum": ["ko-en", "en-ko"] },
        "due": { "type": "number" },
        "mastered": { "type": "number" },
        "poolSize": { "type": "number" },
        "feedback": { "type": "string" },
        "mnemonic": { "type": "string" },
        "listening": { "type": "boolean" },
        "awaitingAnswer": { "type": "boolean" },
        "optionsVisible": { "type": "boolean" },
        "sensorAvailable": { "type": "boolean" },
        "scenarioStarted": { "type": "boolean" }
      },
      "required": ["mode", "due", "mastered"]
    }
  }
}
</script>

<script setup>
import { vocab, CATEGORIES } from '../../data/vocab.js';
import { scenarios } from '../../data/scenarios.js';
import { loadState, saveState, pickDueWord, recordResult, dueCount, MAX_STAGE } from '../../data/srs.js';

const CATEGORY_STORAGE_KEY = 'korean.category';
const DIRECTION_STORAGE_KEY = 'korean.direction';

const TUTOR_SYSTEM_PROMPT =
  'You are a warm, concise Korean language tutor speaking to someone wearing ' +
  'smart glasses. Keep every reply to one or two short sentences, suitable to ' +
  'be read aloud. When correcting pronunciation or grammar, name the issue ' +
  'and give the correct Korean phrase with romanization.';

const MNEMONIC_STORAGE_KEY = 'korean.mnemonics';

function scenarioPersonaPrompt(scenario) {
  return `You are role-playing as ${scenario.persona} for a Korean-language ` +
    'learner wearing smart glasses. Stay fully in character. Reply only in ' +
    'Korean, one short natural sentence suitable for a beginner. Never break ' +
    'character or switch to English.';
}

// One correct answer plus one distractor pulled from the same pool, shuffled
// into a stable [left, right] pair for the round. In 'ko-en' direction the
// prompt is the Korean word and options are meanings; in 'en-ko' the prompt
// is the meaning and options are Korean words.
function buildOptions(word, pool, direction) {
  const distractorPool = pool.filter((w) => w.id !== word.id);
  const distractor = distractorPool[Math.floor(Math.random() * distractorPool.length)];
  const pair = Math.random() < 0.5 ? [word, distractor] : [distractor, word];
  const textFor = direction === 'en-ko' ? (w) => w.hangul : (w) => w.meaning;
  return pair.map((w) => ({ text: textFor(w), isCorrect: w.id === word.id }));
}

const TILT_THRESHOLD_DEG = 18;

export default {
  data: {
    mode: 'review',
    category: 'mix',
    direction: 'ko-en',
    currentWord: vocab[0],
    options: buildOptions(vocab[0], vocab, 'ko-en'),
    optionsVisible: false,
    awaitingAnswer: false,
    sensorAvailable: true,
    due: 0,
    mastered: 0,
    poolSize: vocab.length,
    listening: false,
    feedback: '',
    mnemonic: '',
    mnemonicLoading: false,
    scenarioIndex: 0,
    currentScenario: scenarios[0],
    scenarioStarted: false,
    scenarioLog: [],
    chatLog: []
  },

  session: null,
  scenarioSession: null,
  srsState: null,
  sensor: null,
  baselineRoll: null,

  onLoad() {
    this.srsState = loadState(vocab);
    const category = localStorage.getItem(CATEGORY_STORAGE_KEY) || 'mix';
    const direction = localStorage.getItem(DIRECTION_STORAGE_KEY) || 'ko-en';
    this.setData({ category, direction });
    this.nextRound();
    if (this.data.mode === 'review') this.startSensor();
  },

  onShow() {
    if (this.data.mode === 'review') this.startSensor();
  },

  onHide() {
    this.stopSensor();
  },

  pool() {
    return this.data.category === 'mix'
      ? vocab
      : vocab.filter((word) => word.category === this.data.category);
  },

  refreshStats() {
    const pool = this.pool();
    this.setData({
      due: dueCount(pool, this.srsState),
      mastered: pool.filter((word) => this.srsState[word.id].stage === MAX_STAGE).length,
      poolSize: pool.length
    });
  },

  nextRound() {
    const pool = this.pool();
    const word = pickDueWord(pool, this.srsState);
    this.baselineRoll = null;
    this.refreshStats();
    this.setData({
      currentWord: word,
      options: buildOptions(word, pool, this.data.direction),
      optionsVisible: false,
      awaitingAnswer: true,
      feedback: '',
      mnemonic: ''
    });
    if (this.data.direction === 'ko-en') {
      this.speak(word.hangul);
    }
    setTimeout(() => this.setData({ optionsVisible: true }), 50);
  },

  setCategory(event) {
    const category = event.currentTarget.dataset.category;
    if (category === this.data.category) return;
    localStorage.setItem(CATEGORY_STORAGE_KEY, category);
    this.setData({ category });
    this.nextRound();
  },

  setDirection(event) {
    const direction = event.currentTarget.dataset.direction;
    if (direction === this.data.direction) return;
    localStorage.setItem(DIRECTION_STORAGE_KEY, direction);
    this.setData({ direction });
    this.nextRound();
  },

  startSensor() {
    try {
      this.sensor = new AbsoluteOrientationSensor({ frequency: 30 });
      this.sensor.addEventListener('reading', () => this.handleTiltReading());
      this.sensor.addEventListener('error', () => this.setData({ sensorAvailable: false }));
      this.sensor.start();
      this.setData({ sensorAvailable: true });
    } catch {
      this.setData({ sensorAvailable: false });
    }
  },

  stopSensor() {
    if (this.sensor && typeof this.sensor.stop === 'function') {
      this.sensor.stop();
    }
    this.sensor = null;
  },

  handleTiltReading() {
    if (!this.data.awaitingAnswer || !this.sensor?.quaternion) return;

    const [x, y, z, w] = this.sensor.quaternion;
    const rollDeg = Math.atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y)) * (180 / Math.PI);

    if (this.baselineRoll === null) {
      this.baselineRoll = rollDeg;
      return;
    }

    const delta = rollDeg - this.baselineRoll;
    // Sign convention (positive delta = tilt right) is unverified against
    // real hardware; flip the branches below if left/right feel swapped.
    if (delta > TILT_THRESHOLD_DEG) {
      this.selectAnswer(1);
    } else if (delta < -TILT_THRESHOLD_DEG) {
      this.selectAnswer(0);
    }
  },

  selectLeft() {
    this.selectAnswer(0);
  },

  selectRight() {
    this.selectAnswer(1);
  },

  selectAnswer(sideIndex) {
    if (!this.data.awaitingAnswer) return;
    this.setData({ awaitingAnswer: false });

    const target = this.data.currentWord;
    const picked = this.data.options[sideIndex];
    const correct = picked.isCorrect;
    recordResult(this.srsState, target.id, correct);
    saveState(this.srsState);
    this.refreshStats();

    if (this.data.direction === 'en-ko') {
      // Recall mode: never speak English, just sound out the Korean word
      // the wearer just picked so they hear its pronunciation either way.
      const feedback = correct ? 'Correct!' : `Not quite — it's "${target.hangul}" (${target.romanization}).`;
      this.setData({ feedback });
      this.speak(picked.text);
    } else {
      const feedback = correct ? 'Correct!' : `Not quite — it means "${target.meaning}".`;
      this.setData({ feedback });
      this.speak(feedback);
    }
    setTimeout(() => this.nextRound(), 1600);
  },

  loadMnemonicCache() {
    try {
      return JSON.parse(localStorage.getItem(MNEMONIC_STORAGE_KEY) || '{}');
    } catch {
      return {};
    }
  },

  saveMnemonicCache(cache) {
    localStorage.setItem(MNEMONIC_STORAGE_KEY, JSON.stringify(cache));
  },

  async ensureSession() {
    if (this.session) return this.session;
    const available = await LanguageModel.availability();
    if (available === 'no') return null;
    this.session = await LanguageModel.create({ systemPrompt: TUTOR_SYSTEM_PROMPT });
    return this.session;
  },

  speak(text) {
    const utterance = new SpeechSynthesisUtterance(text);
    speechSynthesis.speak(utterance);
  },

  speakCurrent() {
    // Recall mode never speaks English, and replaying the Korean word here
    // would give the answer away before it's picked, so this is a no-op.
    if (this.data.direction === 'en-ko') return;
    const word = this.data.currentWord;
    this.speak(word.hangul);
  },

  setMode(event) {
    const mode = event.currentTarget.dataset.mode;
    if (mode === 'review' && this.data.mode !== 'review') {
      this.startSensor();
    } else if (mode !== 'review' && this.data.mode === 'review') {
      this.stopSensor();
    }
    this.setData({ mode });
  },

  listenOnce() {
    return new Promise((resolve) => {
      const recognition = new SpeechRecognition();
      recognition.lang = 'ko-KR';
      recognition.onresult = (event) => {
        const transcript = event.results?.[0]?.[0]?.transcript || '';
        resolve(transcript);
      };
      recognition.onerror = () => resolve('');
      recognition.onend = () => resolve('');
      recognition.start();
    });
  },

  async getMnemonic() {
    if (this.data.mnemonicLoading) return;
    const word = this.data.currentWord;
    const cache = this.loadMnemonicCache();

    if (cache[word.id]) {
      this.setData({ mnemonic: cache[word.id] });
      this.speak(cache[word.id]);
      return;
    }

    this.setData({ mnemonicLoading: true });
    const session = await this.ensureSession();
    const mnemonic = session
      ? await session.prompt(
        `Create a short, memorable English mnemonic (one sentence) to help ` +
          `remember that the Korean phrase "${word.hangul}" (${word.romanization}) ` +
          `means "${word.meaning}".`
        )
      : `Think of "${word.romanization}" as your clue for "${word.meaning}".`;

    cache[word.id] = mnemonic;
    this.saveMnemonicCache(cache);
    this.setData({ mnemonic, mnemonicLoading: false });
    this.speak(mnemonic);
  },

  async startChat() {
    if (this.data.listening) return;
    this.setData({ listening: true });

    const heard = await this.listenOnce();
    if (!heard) {
      this.setData({ listening: false });
      return;
    }

    const session = await this.ensureSession();
    const reply = session
      ? await session.prompt(heard)
      : 'The tutor model is unavailable right now.';

    const chatLog = [...this.data.chatLog, { role: 'user', text: heard }, { role: 'tutor', text: reply }].slice(-6);
    this.setData({ listening: false, chatLog });
    this.speak(reply);
  },

  prevScenario() {
    if (this.data.scenarioStarted) return;
    const scenarioIndex = (this.data.scenarioIndex - 1 + scenarios.length) % scenarios.length;
    this.setData({ scenarioIndex, currentScenario: scenarios[scenarioIndex] });
  },

  nextScenario() {
    if (this.data.scenarioStarted) return;
    const scenarioIndex = (this.data.scenarioIndex + 1) % scenarios.length;
    this.setData({ scenarioIndex, currentScenario: scenarios[scenarioIndex] });
  },

  async startScenario() {
    const scenario = this.data.currentScenario;
    const available = await LanguageModel.availability();
    if (available === 'no') {
      this.setData({
        scenarioStarted: true,
        scenarioLog: [{ role: 'npc', text: 'The tutor model is unavailable right now.' }]
      });
      return;
    }

    this.scenarioSession = await LanguageModel.create({ systemPrompt: scenarioPersonaPrompt(scenario) });
    const scenarioLog = [{ role: 'npc', text: scenario.opening }];
    this.setData({ scenarioStarted: true, scenarioLog });
    this.speak(scenario.opening);
  },

  async replyToScenario() {
    if (this.data.listening || !this.scenarioSession) return;
    this.setData({ listening: true });

    const heard = await this.listenOnce();
    if (!heard) {
      this.setData({ listening: false });
      return;
    }

    const reply = await this.scenarioSession.prompt(heard);
    const scenarioLog = [...this.data.scenarioLog, { role: 'learner', text: heard }, { role: 'npc', text: reply }].slice(-6);
    this.setData({ listening: false, scenarioLog });
    this.speak(reply);
  },

  endScenario() {
    this.scenarioSession = null;
    this.setData({ scenarioStarted: false, scenarioLog: [] });
  },

  onKeyUp(event) {
    if (event.code !== 'Enter' && event.code !== 'GlobalHook') return;
    event.preventDefault();
    if (this.data.mode === 'review') {
      this.speakCurrent();
    } else if (this.data.mode === 'scenario') {
      if (this.data.scenarioStarted) {
        this.replyToScenario();
      } else {
        this.startScenario();
      }
    } else if (this.data.mode === 'chat') {
      this.startChat();
    }
  },

  onVoiceWakeup() {
    if (this.data.mode === 'review') {
      this.speakCurrent();
    } else if (this.data.mode === 'scenario' && this.data.scenarioStarted) {
      this.replyToScenario();
    } else if (this.data.mode === 'chat') {
      this.startChat();
    }
  }
}
</script>

<page>
  <view class="container">
    <view class="tabs">
      <text class="tab {{ mode === 'review' ? 'active' : '' }}" data-mode="review" bindtap="setMode">Review</text>
      <text class="tab {{ mode === 'scenario' ? 'active' : '' }}" data-mode="scenario" bindtap="setMode">Scenario</text>
      <text class="tab {{ mode === 'chat' ? 'active' : '' }}" data-mode="chat" bindtap="setMode">Chat</text>
    </view>

    <view class="card review-card" ink:if="{{ mode === 'review' }}">
      <view class="settings-row">
        <text class="pill {{ category === 'descriptive' ? 'active' : '' }}" data-category="descriptive" bindtap="setCategory">General</text>
        <text class="pill {{ category === 'conjunction' ? 'active' : '' }}" data-category="conjunction" bindtap="setCategory">Conjunction</text>
        <text class="pill {{ category === 'objects' ? 'active' : '' }}" data-category="objects" bindtap="setCategory">Objects</text>
        <text class="pill {{ category === 'mix' ? 'active' : '' }}" data-category="mix" bindtap="setCategory">Mix</text>
      </view>
      <view class="settings-row">
        <text class="pill {{ direction === 'ko-en' ? 'active' : '' }}" data-direction="ko-en" bindtap="setDirection">Read (KO→EN)</text>
        <text class="pill {{ direction === 'en-ko' ? 'active' : '' }}" data-direction="en-ko" bindtap="setDirection">Recall (EN→KO)</text>
      </view>

      <view class="options-row">
        <view class="option option-left {{ optionsVisible ? 'visible' : '' }}" bindtap="selectLeft">
          <text>{{ options[0].text }}</text>
        </view>
        <view class="option option-right {{ optionsVisible ? 'visible' : '' }}" bindtap="selectRight">
          <text>{{ options[1].text }}</text>
        </view>
      </view>

      <view ink:if="{{ direction === 'ko-en' }}">
        <text class="hangul">{{ currentWord.hangul }}</text>
        <text class="romanization">{{ currentWord.romanization }}</text>
      </view>
      <text class="hangul" ink:if="{{ direction === 'en-ko' }}">{{ currentWord.meaning }}</text>
      <text class="hint">{{ sensorAvailable ? 'Tilt your head left or right to answer' : 'Tap an answer above' }}</text>

      <text class="feedback" ink:if="{{ feedback }}">{{ feedback }}</text>
      <text class="feedback" ink:if="{{ mnemonic }}">{{ mnemonic }}</text>
      <view class="row">
        <button ink:if="{{ direction === 'ko-en' }}" bindtap="speakCurrent">Play again</button>
        <button bindtap="getMnemonic">{{ mnemonicLoading ? '...' : 'Mnemonic' }}</button>
      </view>
      <text class="stats">Due: {{ due }}  Mastered: {{ mastered }}/{{ poolSize }}</text>
    </view>

    <view class="card" ink:if="{{ mode === 'scenario' }}">
      <view class="row" ink:if="{{ !scenarioStarted }}">
        <button bindtap="prevScenario">Prev</button>
        <text class="scenario-title">{{ currentScenario.title }}</text>
        <button bindtap="nextScenario">Next</button>
      </view>
      <button ink:if="{{ !scenarioStarted }}" bindtap="startScenario">Start</button>

      <scroll-view class="chat-log" ink:if="{{ scenarioStarted }}">
        <text class="chat-line {{ item.role }}" ink:for="{{ scenarioLog }}" ink:key="index">{{ item.text }}</text>
      </scroll-view>
      <view class="row" ink:if="{{ scenarioStarted }}">
        <button class="{{ listening ? 'focused' : '' }}" bindtap="replyToScenario">
          {{ listening ? 'Listening...' : 'Reply' }}
        </button>
        <button bindtap="endScenario">End</button>
      </view>
    </view>

    <view class="card" ink:if="{{ mode === 'chat' }}">
      <scroll-view class="chat-log">
        <text class="chat-line {{ item.role }}" ink:for="{{ chatLog }}" ink:key="index">{{ item.text }}</text>
      </scroll-view>
      <button class="{{ listening ? 'focused' : '' }}" bindtap="startChat">
        {{ listening ? 'Listening...' : 'Ask the tutor' }}
      </button>
    </view>
  </view>
</page>

<style>
.container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: space-between;
  height: 100vh;
  background: #000;
  color: var(--color-primary, #40FF5E);
}

.tabs {
  display: flex;
  flex-direction: row;
  gap: var(--spacing-md, 12px);
  margin-top: 8px;
}

.tab {
  padding: 4px 10px;
  border: 1px solid #40ff5d42;
  border-radius: var(--radius-md, 12px);
}

.tab.active {
  border: 2px solid #40FF5E;
}

.card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--spacing-md, 12px);
  width: 80%;
}

.hangul {
  font-size: 28px;
  line-height: 32px;
  text-align: center;
}

.romanization {
  font-size: 16px;
  opacity: 0.8;
}

.meaning {
  font-size: 16px;
}

.scenario-title {
  font-size: 16px;
  text-align: center;
}

.review-card {
  width: 100%;
}

.settings-row {
  display: flex;
  flex-direction: row;
  flex-wrap: wrap;
  justify-content: center;
  gap: 6px;
}

.pill {
  font-size: 11px;
  padding: 3px 8px;
  border: 1px solid #40ff5d42;
  border-radius: var(--radius-md, 12px);
  opacity: 0.7;
}

.pill.active {
  border: 2px solid #40FF5E;
  opacity: 1;
}

.options-row {
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  width: 100%;
  height: 56px;
}

.option {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 46%;
  min-height: 40px;
  border: 1px solid #40ff5d42;
  border-radius: var(--radius-md, 12px);
  padding: 8px;
  box-sizing: border-box;
  text-align: center;
  transform: translateY(-140px);
  opacity: 0;
  transition: transform 450ms ease, opacity 450ms ease;
}

.option.visible {
  transform: translateY(0);
  opacity: 1;
}

.hint {
  font-size: 12px;
  opacity: 0.7;
  text-align: center;
}

.row {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: var(--spacing-md, 12px);
}

button {
  color: #40FF5E;
  border: 1px solid #40ff5d42;
  border-radius: 12px;
  box-sizing: border-box;
  padding: 5px 10px;
  line-height: 24px;
  text-align: center;
}

button.focused {
  border: 2px solid #40FF5E;
}

.feedback {
  font-size: 14px;
  text-align: center;
}

.chat-log {
  width: 100%;
  height: 160px;
}

.chat-line {
  display: block;
  font-size: 14px;
  margin-bottom: 4px;
}

.chat-line.learner,
.chat-line.user {
  opacity: 0.7;
}

.stats {
  font-size: 12px;
  opacity: 0.6;
  margin-bottom: 8px;
}
</style>
