<script def>
{
  "navigationBarTitleText": "Learn Korean",
  "description": "Hands-free Korean tutor: flashcards with TTS playback, spoken-practice with LLM feedback, and free-form voice chat with a Korean tutor persona.",
  "schema": {
    "data": {
      "type": "object",
      "properties": {
        "mode": { "enum": ["learn", "practice", "chat"] },
        "index": { "type": "number" },
        "streak": { "type": "number" },
        "feedback": { "type": "string" },
        "listening": { "type": "boolean" }
      },
      "required": ["mode", "index", "streak"]
    }
  }
}
</script>

<script setup>
import { vocab } from '../../data/vocab.js';

const TUTOR_SYSTEM_PROMPT =
  'You are a warm, concise Korean language tutor speaking to someone wearing ' +
  'smart glasses. Keep every reply to one or two short sentences, suitable to ' +
  'be read aloud. When correcting pronunciation or grammar, name the issue ' +
  'and give the correct Korean phrase with romanization.';

function normalize(text) {
  return (text || '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, '')
    .trim();
}

export default {
  data: {
    mode: 'learn',
    index: 0,
    streak: 0,
    listening: false,
    feedback: '',
    chatLog: [],
    currentWord: vocab[0]
  },

  session: null,

  onLoad() {
    const savedIndex = Number(localStorage.getItem('korean.index') || 0);
    const savedStreak = Number(localStorage.getItem('korean.streak') || 0);
    const index = Number.isFinite(savedIndex) ? savedIndex % vocab.length : 0;
    this.setData({
      index,
      streak: Number.isFinite(savedStreak) ? savedStreak : 0,
      currentWord: vocab[index]
    });
  },

  getCurrentWord() {
    return vocab[this.data.index];
  },

  persist() {
    localStorage.setItem('korean.index', String(this.data.index));
    localStorage.setItem('korean.streak', String(this.data.streak));
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
    this.speak(this.getCurrentWord().hangul);
  },

  setMode(event) {
    const mode = event.currentTarget.dataset.mode;
    this.setData({ mode, feedback: '' });
  },

  nextWord() {
    const index = (this.data.index + 1) % vocab.length;
    const streak = this.data.streak + 1;
    this.setData({ index, streak, feedback: '', currentWord: vocab[index] });
    this.persist();
  },

  prevWord() {
    const index = (this.data.index - 1 + vocab.length) % vocab.length;
    this.setData({ index, feedback: '', currentWord: vocab[index] });
    this.persist();
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

  async startPractice() {
    if (this.data.listening) return;
    this.setData({ listening: true, feedback: '' });

    const target = this.getCurrentWord();
    const heard = await this.listenOnce();
    const isMatch = normalize(heard) === normalize(target.romanization) ||
      normalize(heard) === normalize(target.hangul);

    let feedback;
    const session = await this.ensureSession();
    if (session) {
      const prompt = `Target Korean phrase: "${target.hangul}" (${target.romanization}, ` +
        `meaning "${target.meaning}"). The learner said: "${heard || '(nothing heard)'}". ` +
        'Give one short sentence of feedback on how close that was and how to improve.';
      feedback = await session.prompt(prompt);
    } else {
      feedback = isMatch
        ? 'Nicely done, that matches.'
        : `Close. The target is "${target.romanization}".`;
    }

    if (isMatch) {
      this.setData({ streak: this.data.streak + 1 });
      this.persist();
    }

    this.setData({ listening: false, feedback });
    this.speak(feedback);
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

  onKeyUp(event) {
    if (event.code !== 'Enter' && event.code !== 'GlobalHook') return;
    event.preventDefault();
    if (this.data.mode === 'learn') {
      this.speakCurrent();
    } else if (this.data.mode === 'practice') {
      this.startPractice();
    } else if (this.data.mode === 'chat') {
      this.startChat();
    }
  },

  onVoiceWakeup() {
    if (this.data.mode === 'chat') {
      this.startChat();
    } else if (this.data.mode === 'practice') {
      this.startPractice();
    }
  }
}
</script>

<page>
  <view class="container">
    <view class="tabs">
      <text class="tab {{ mode === 'learn' ? 'active' : '' }}" data-mode="learn" bindtap="setMode">Learn</text>
      <text class="tab {{ mode === 'practice' ? 'active' : '' }}" data-mode="practice" bindtap="setMode">Practice</text>
      <text class="tab {{ mode === 'chat' ? 'active' : '' }}" data-mode="chat" bindtap="setMode">Chat</text>
    </view>

    <view class="card" ink:if="{{ mode === 'learn' }}">
      <text class="hangul">{{ currentWord.hangul }}</text>
      <text class="romanization">{{ currentWord.romanization }}</text>
      <text class="meaning">{{ currentWord.meaning }}</text>
      <view class="row">
        <button bindtap="prevWord">Prev</button>
        <button bindtap="speakCurrent">Play</button>
        <button bindtap="nextWord">Next</button>
      </view>
    </view>

    <view class="card" ink:if="{{ mode === 'practice' }}">
      <text class="hangul">{{ currentWord.hangul }}</text>
      <text class="romanization">{{ currentWord.romanization }}</text>
      <button class="{{ listening ? 'focused' : '' }}" bindtap="startPractice">
        {{ listening ? 'Listening...' : 'Speak it' }}
      </button>
      <text class="feedback" ink:if="{{ feedback }}">{{ feedback }}</text>
    </view>

    <view class="card" ink:if="{{ mode === 'chat' }}">
      <scroll-view class="chat-log">
        <text class="chat-line {{ item.role }}" ink:for="{{ chatLog }}" ink:key="index">{{ item.text }}</text>
      </scroll-view>
      <button class="{{ listening ? 'focused' : '' }}" bindtap="startChat">
        {{ listening ? 'Listening...' : 'Ask the tutor' }}
      </button>
    </view>

    <text class="streak">Streak: {{ streak }}</text>
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

.row {
  display: flex;
  flex-direction: row;
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

.chat-line.user {
  opacity: 0.7;
}

.streak {
  font-size: 12px;
  opacity: 0.6;
  margin-bottom: 8px;
}
</style>
