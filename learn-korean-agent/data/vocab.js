// category: 'descriptive' (general descriptive words/adjectives),
// 'conjunction' (connecting words), or 'objects' (nouns/things).
export const vocab = [
  // -- descriptive --
  { id: 'pretty', category: 'descriptive', hangul: '예뻐요', romanization: 'yeppeoyo', meaning: 'pretty' },
  { id: 'big', category: 'descriptive', hangul: '커요', romanization: 'keoyo', meaning: 'big' },
  { id: 'small', category: 'descriptive', hangul: '작아요', romanization: 'jagayo', meaning: 'small' },
  { id: 'delicious', category: 'descriptive', hangul: '맛있어요', romanization: 'masisseoyo', meaning: 'delicious' },
  { id: 'expensive', category: 'descriptive', hangul: '비싸요', romanization: 'bissayo', meaning: 'expensive' },
  { id: 'cheap', category: 'descriptive', hangul: '싸요', romanization: 'ssayo', meaning: 'cheap' },
  { id: 'good', category: 'descriptive', hangul: '좋아요', romanization: 'joayo', meaning: 'good' },
  { id: 'bad', category: 'descriptive', hangul: '나빠요', romanization: 'nappayo', meaning: 'bad' },
  { id: 'fast', category: 'descriptive', hangul: '빨라요', romanization: 'ppallayo', meaning: 'fast' },
  { id: 'slow', category: 'descriptive', hangul: '느려요', romanization: 'neuryeoyo', meaning: 'slow' },
  { id: 'new', category: 'descriptive', hangul: '새로워요', romanization: 'saerowoyo', meaning: 'new' },
  { id: 'old-thing', category: 'descriptive', hangul: '오래됐어요', romanization: 'oraedwaesseoyo', meaning: 'old (thing)' },

  // -- conjunction --
  { id: 'and', category: 'conjunction', hangul: '그리고', romanization: 'geurigo', meaning: 'and' },
  { id: 'but', category: 'conjunction', hangul: '하지만', romanization: 'hajiman', meaning: 'but' },
  { id: 'so', category: 'conjunction', hangul: '그래서', romanization: 'geuraeseo', meaning: 'so, therefore' },
  { id: 'because', category: 'conjunction', hangul: '왜냐하면', romanization: 'waenyahamyeon', meaning: 'because' },
  { id: 'or', category: 'conjunction', hangul: '또는', romanization: 'ttoneun', meaning: 'or' },
  { id: 'however', category: 'conjunction', hangul: '그런데', romanization: 'geureonde', meaning: 'however, by the way' },
  { id: 'if-so', category: 'conjunction', hangul: '그러면', romanization: 'geureomyeon', meaning: 'then, if so' },
  { id: 'even-so', category: 'conjunction', hangul: '그래도', romanization: 'geuraedo', meaning: 'even so, still' },

  // -- objects --
  { id: 'water', category: 'objects', hangul: '물', romanization: 'mul', meaning: 'water' },
  { id: 'coffee', category: 'objects', hangul: '커피', romanization: 'keopi', meaning: 'coffee' },
  { id: 'book', category: 'objects', hangul: '책', romanization: 'chaek', meaning: 'book' },
  { id: 'bathroom', category: 'objects', hangul: '화장실', romanization: 'hwajangsil', meaning: 'bathroom' },
  { id: 'money', category: 'objects', hangul: '돈', romanization: 'don', meaning: 'money' },
  { id: 'bag', category: 'objects', hangul: '가방', romanization: 'gabang', meaning: 'bag' },
  { id: 'phone', category: 'objects', hangul: '핸드폰', romanization: 'haendeupon', meaning: 'phone' },
  { id: 'umbrella', category: 'objects', hangul: '우산', romanization: 'usan', meaning: 'umbrella' },
  { id: 'chair', category: 'objects', hangul: '의자', romanization: 'uija', meaning: 'chair' },
  { id: 'table', category: 'objects', hangul: '테이블', romanization: 'teibeul', meaning: 'table' },
  { id: 'door', category: 'objects', hangul: '문', romanization: 'mun', meaning: 'door' },
  { id: 'window', category: 'objects', hangul: '창문', romanization: 'changmun', meaning: 'window' }
];

export const CATEGORIES = ['descriptive', 'conjunction', 'objects'];
