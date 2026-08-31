<script def>
{
  "navigationBarTitleText": "Learn Korean",
  "description": "Hands-free Korean tutor: spaced-repetition vocab review with TTS/ASR and LLM feedback, scenario roleplay conversations, AI-generated mnemonics, and free-form voice chat with a Korean tutor persona.",
  "schema": {
    "data": {
      "type": "object",
      "properties": {
        "mode": { "enum": ["review", "scenario", "chat"] },
        "due": { "type": "number" },
        "mastered": { "type": "number" },
        "feedback": { "type": "string" },
        "mnemonic": { "type": "string" },
        "listening": { "type": "boolean" },
        "scenarioStarted": { "type": "boolean" }
      },
      "required": ["mode", "due", "mastered"]
    }
  }
}
</script>

<script setup>
import { vocab } from '../../data/vocab.js';
import { scenarios } from '../../data/scenarios.js';
import { loadState, saveState, pickDueWord, recordResult, dueCount, MAX_STAGE } from '../../data/srs.js';

const TUTOR_SYSTEM_PROMPT =
  'You are a warm, concise Korean language tutor speaking to someone wearing ' +
  'smart glasses. Keep every reply to one or two short sentences, suitable to ' +
  'be read aloud. When correcting pronunciation or grammar, name the issue ' +
  'and give the correct Korean phrase with romanization.';

const MNEMONIC_STORAGE_KEY = 'korean.mnemonics';

function normalize(text) {
  return (text || '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, '')
    .trim();
}

function scenarioPersonaPrompt(scenario) {
  return `You are role-playing as ${scenario.persona} for a Korean-language ` +
    'learner wearing smart glasses. Stay fully in character. Reply only in ' +
    'Korean, one short natural sentence suitable for a beginner. Never break ' +
    'character or switch to English.';
}

export default {
  data: {
    mode: 'review',
    currentWord: vocab[0],
    due: 0,
    mastered: 0,
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

  onLoad() {
    this.srsState = loadState(vocab);
    this.refreshReview();
  },

  refreshReview() {
    this.setData({
      currentWord: pickDueWord(vocab, this.srsState),
      due: dueCount(vocab, this.srsState),
      mastered: vocab.filter((word) => this.srsState[word.id].stage === MAX_STAGE).length,
      feedback: '',
      mnemonic: ''
    });
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
    this.speak(this.data.currentWord.hangul);
  },

  setMode(event) {
    const mode = event.currentTarget.dataset.mode;
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

  async startPractice() {
    if (this.data.listening) return;
    this.setData({ listening: true, feedback: '' });

    const target = this.data.currentWord;
    const heard = await this.listenOnce();
    const isMatch = normalize(heard) === normalize(target.romanization) ||
      normalize(heard) === normalize(target.hangul);

    recordResult(this.srsState, target.id, isMatch);
    saveState(this.srsState);

    const session = await this.ensureSession();
    const feedback = session
      ? await session.prompt(
        `Target Korean phrase: "${target.hangul}" (${target.romanization}, ` +
          `meaning "${target.meaning}"). The learner said: "${heard || '(nothing heard)'}". ` +
          'Give one short sentence of feedback on how close that was and how to improve.'
        )
      : (isMatch ? 'Nicely done, that matches.' : `Close. The target is "${target.romanization}".`);

    this.setData({ listening: false, feedback });
    this.speak(feedback);
    setTimeout(() => this.refreshReview(), 1800);
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
      this.startPractice();
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
      this.startPractice();
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

    <view class="card" ink:if="{{ mode === 'review' }}">
      <text class="hangul">{{ currentWord.hangul }}</text>
      <text class="romanization">{{ currentWord.romanization }}</text>
      <text class="meaning">{{ currentWord.meaning }}</text>
      <view class="row">
        <button bindtap="speakCurrent">Play</button>
        <button bindtap="getMnemonic">{{ mnemonicLoading ? '...' : 'Mnemonic' }}</button>
        <button class="{{ listening ? 'focused' : '' }}" bindtap="startPractice">
          {{ listening ? 'Listening...' : 'Speak it' }}
        </button>
      </view>
      <text class="feedback" ink:if="{{ feedback }}">{{ feedback }}</text>
      <text class="feedback" ink:if="{{ mnemonic }}">{{ mnemonic }}</text>
      <text class="stats">Due: {{ due }}  Mastered: {{ mastered }}/20</text>
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
