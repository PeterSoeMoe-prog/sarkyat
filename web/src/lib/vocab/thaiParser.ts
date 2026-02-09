import type { VocabLogic } from "./firestore";

export interface CharBreakdown {
  char: string;
  type: 'consonant' | 'vowel' | 'tone' | 'final' | 'unknown';
  burmeseName: string;
}

export function parseThaiWord(word: string, logic: VocabLogic): CharBreakdown[] {
  const breakdown: CharBreakdown[] = [];
  
  // 1. Build strict lookup maps with NFC normalization
  const consonantMap = parseLogicString(logic.consonants || "");
  const vowelMap = parseLogicString(logic.vowels || "");
  const toneMap = parseLogicString(logic.tones || "");

  const normalizedWord = (word || "").normalize('NFC');
  const chars = Array.from(normalizedWord);
  let i = 0;

  while (i < chars.length) {
    let matched = false;
    
    // 2. Greedy Multi-character Vowel Check (Longest match first: 4 down to 2)
    // This handles complex vowels like เ-าะ which you may have in your list
    for (let len = 4; len >= 2; len--) {
      if (i + len <= chars.length) {
        const chunk = chars.slice(i, i + len).join("").normalize('NFC');
        const withFiller = `อ${chunk}`.normalize('NFC');
        
        if (vowelMap.has(chunk) || vowelMap.has(withFiller)) {
          const burmeseName = vowelMap.get(chunk) || vowelMap.get(withFiller)!;
          breakdown.push({ char: chunk, type: 'vowel', burmeseName });
          i += len;
          matched = true;
          break;
        }
      }
    }
    if (matched) continue;

    const char = chars[i].normalize('NFC');

    // 3. Direct Character Matching (High priority for accuracy)
    // We check EVERY map to ensure we find your custom Burmese name.
    
    if (toneMap.has(char)) {
      breakdown.push({ char, type: 'tone', burmeseName: toneMap.get(char)! });
    } else if (vowelMap.has(char) || vowelMap.has(`อ${char}`) || vowelMap.has(`${char}อ`)) {
      const burmeseName = vowelMap.get(char) || vowelMap.get(`อ${char}`) || vowelMap.get(`${char}อ`)!;
      breakdown.push({ char, type: 'vowel', burmeseName });
    } else if (consonantMap.has(char)) {
      const burmeseName = consonantMap.get(char)!;
      const isFirst = i === 0;
      const prevItem = breakdown.length > 0 ? breakdown[breakdown.length - 1] : null;
      
      // Determine Initial (ဗျည်း) vs Final (အသတ်ဗျည်း)
      // Logic: It is a final ONLY if it follows a vowel, tone, or another consonant
      let type: 'consonant' | 'final' = 'consonant';
      if (!isFirst && prevItem) {
        if (prevItem.type === 'vowel' || prevItem.type === 'tone' || prevItem.type === 'consonant') {
          type = 'final';
        }
      }
      
      breakdown.push({ char, type, burmeseName });
    } else {
      // If NOT in any list, mark as unknown with '-' label in UI
      breakdown.push({ char, type: 'unknown', burmeseName: "" });
    }
    
    i++;
  }

  return breakdown;
}

function parseLogicString(input: string): Map<string, string> {
  const map = new Map<string, string>();
  const lines = input.split(/\r?\n/);
  
  for (const line of lines) {
    // Strip all invisible characters and non-standard spaces
    const cleanLine = line.replace(/[\u00A0\u1680\u180E\u2000-\u200B\u202F\u205F\u3000\uFEFF]/g, ' ').trim();
    if (!cleanLine) continue;
    
    const parts = cleanLine.split(/[\s\t]+/);
    if (parts.length >= 2) {
      // Normalize to NFC for consistent matching across platform boundaries
      const thaiChar = parts[0].trim().normalize('NFC');
      const burmeseName = parts.slice(1).join(" ").trim().normalize('NFC');
      if (thaiChar) {
        map.set(thaiChar, burmeseName);
      }
    }
  }
  
  return map;
}
