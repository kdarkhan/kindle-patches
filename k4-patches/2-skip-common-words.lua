local ReaderKeySelection = require("apps/reader/modules/readerkeyselection")

-- Common English function words (articles, pronouns, prepositions,
-- conjunctions, auxiliary/copula verbs, common short verbs and adverbs,
-- contractions, small numbers) -- almost never worth a dictionary lookup,
-- so the left/right crosshair keys skip straight past them onto the next
-- word instead of making you press through each one.
local SKIP_WORDS = {}
for _, w in ipairs({
    -- articles
    "a", "an", "the",
    -- pronouns
    "i", "me", "my", "mine", "myself",
    "you", "your", "yours", "yourself", "yourselves",
    "he", "him", "his", "himself",
    "she", "her", "hers", "herself",
    "it", "its", "itself",
    "we", "us", "our", "ours", "ourselves",
    "they", "them", "their", "theirs", "themselves",
    "this", "that", "these", "those",
    "who", "whom", "whose", "which", "what", "whoever", "whatever", "whichever",
    -- be / auxiliary / modal verbs
    "am", "is", "are", "was", "were", "be", "been", "being",
    "do", "does", "did", "doing", "done",
    "have", "has", "had", "having",
    "will", "would", "shall", "should", "can", "could", "may", "might", "must", "ought",
    -- prepositions
    "of", "in", "on", "at", "by", "for", "with", "about", "against", "between", "into",
    "through", "during", "before", "after", "above", "below", "to", "from",
    "up", "down", "over", "under", "again", "further", "out", "off", "near",
    "since", "until", "upon", "within", "without", "among", "along", "across",
    "behind", "beyond", "beside", "besides", "around", "toward", "towards", "throughout",
    -- conjunctions
    "and", "but", "or", "nor", "so", "yet", "if", "because", "as", "while",
    "although", "though", "unless", "whether", "than", "that",
    -- common adverbs / quantifiers
    "not", "no", "yes", "very", "too", "also", "just", "only", "still", "even",
    "once", "here", "there", "then", "now", "always", "never", "often",
    "sometimes", "usually", "ever", "already", "soon", "quite", "rather",
    "almost", "enough", "more", "most", "less", "least", "much", "many",
    "some", "any", "all", "both", "each", "few", "other", "another", "such", "same", "own",
    -- question words
    "how", "why", "when", "where",
    -- common short verbs
    "get", "got", "gotten", "go", "goes", "went", "gone", "going",
    "make", "makes", "made", "say", "says", "said",
    "see", "sees", "saw", "seen", "know", "knows", "knew", "known",
    "think", "thinks", "thought", "take", "takes", "took", "taken",
    "come", "comes", "came", "want", "wants", "wanted",
    "look", "looks", "looked", "use", "uses", "used",
    "find", "finds", "found", "give", "gives", "gave", "given",
    "tell", "tells", "told", "ask", "asks", "asked",
    "work", "works", "worked", "seem", "seems", "seemed",
    "feel", "feels", "felt", "try", "tries", "tried", "leave", "leaves", "left",
    "call", "calls", "called", "put", "puts", "let", "lets",
    -- numbers
    "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
    "first", "second", "third",
    -- trivial nouns
    "people", "man", "woman", "time", "day", "way", "thing", "things",
    -- contractions
    "don't", "doesn't", "didn't", "isn't", "aren't", "wasn't", "weren't",
    "won't", "wouldn't", "can't", "couldn't", "shouldn't", "mustn't",
    "i'm", "you're", "he's", "she's", "it's", "we're", "they're",
    "i've", "you've", "we've", "they've",
    "i'll", "you'll", "he'll", "she'll", "we'll", "they'll",
    "i'd", "you'd", "he'd", "she'd", "we'd", "they'd",
    "that's", "there's", "here's", "what's", "who's", "let's",
    "s",
}) do
    SKIP_WORDS[w] = true
end

-- Top 500 most common English words by general-use frequency
-- (source: https://gist.github.com/deekayen/4148741). Beyond the first
-- couple hundred entries this drifts from pure function words into common
-- content vocabulary (e.g. "water", "system", "possible") -- expect it to
-- occasionally skip past a word you'd actually have wanted defined. Trim
-- entries here if that happens too often.
for _, w in ipairs({
    "the", "of", "to", "and", "a", "in", "is", "it", "you", "that",
    "he", "was", "for", "on", "are", "with", "as", "i", "his", "they",
    "be", "at", "one", "have", "this", "from", "or", "had", "by", "not",
    "word", "but", "what", "some", "we", "can", "out", "other", "were", "all",
    "there", "when", "up", "use", "your", "how", "said", "an", "each", "she",
    "which", "do", "their", "time", "if", "will", "way", "about", "many", "then",
    "them", "write", "would", "like", "so", "these", "her", "long", "make", "thing",
    "see", "him", "two", "has", "look", "more", "day", "could", "go", "come",
    "did", "number", "sound", "no", "most", "people", "my", "over", "know", "water",
    "than", "call", "first", "who", "may", "down", "side", "been", "now", "find",
    "any", "new", "work", "part", "take", "get", "place", "made", "live", "where",
    "after", "back", "little", "only", "round", "man", "year", "came", "show", "every",
    "good", "me", "give", "our", "under", "name", "very", "through", "just", "form",
    "sentence", "great", "think", "say", "help", "low", "line", "differ", "turn", "cause",
    "much", "mean", "before", "move", "right", "boy", "old", "too", "same", "tell",
    "does", "set", "three", "want", "air", "well", "also", "play", "small", "end",
    "put", "home", "read", "hand", "port", "large", "spell", "add", "even", "land",
    "here", "must", "big", "high", "such", "follow", "act", "why", "ask", "men",
    "change", "went", "light", "kind", "off", "need", "house", "picture", "try", "us",
    "again", "animal", "point", "mother", "world", "near", "build", "self", "earth", "father",
    "head", "stand", "own", "page", "should", "country", "found", "answer", "school", "grow",
    "study", "still", "learn", "plant", "cover", "food", "sun", "four", "between", "state",
    "keep", "eye", "never", "last", "let", "thought", "city", "tree", "cross", "farm",
    "hard", "start", "might", "story", "saw", "far", "sea", "draw", "left", "late",
    "run", "while", "press", "close", "night", "real", "life", "few", "north",
    "open", "seem", "together", "next", "white", "children", "begin", "got", "walk", "example",
    "ease", "paper", "group", "always", "music", "those", "both", "mark", "often", "letter",
    "until", "mile", "river", "car", "feet", "care", "second", "book", "carry", "took",
    "science", "eat", "room", "friend", "began", "idea", "fish", "mountain", "stop", "once",
    "base", "hear", "horse", "cut", "sure", "watch", "color", "face", "wood", "main",
    "enough", "plain", "girl", "usual", "young", "ready", "above", "ever", "red", "list",
    "though", "feel", "talk", "bird", "soon", "body", "dog", "family", "direct", "pose",
    "leave", "song", "measure", "door", "product", "black", "short", "numeral", "class", "wind",
    "question", "happen", "complete", "ship", "area", "half", "rock", "order", "fire", "south",
    "problem", "piece", "told", "knew", "pass", "since", "top", "whole", "king", "space",
    "heard", "best", "hour", "better", "true", "during", "hundred", "five", "remember", "step",
    "early", "hold", "west", "ground", "interest", "reach", "fast", "verb", "sing", "listen",
    "six", "table", "travel", "less", "morning", "ten", "simple", "several", "vowel", "toward",
    "war", "lay", "against", "pattern", "slow", "center", "love", "person", "money", "serve",
    "appear", "road", "map", "rain", "rule", "govern", "pull", "cold", "notice", "voice",
    "unit", "power", "town", "fine", "certain", "fly", "fall", "lead", "cry", "dark",
    "machine", "note", "wait", "plan", "figure", "star", "box", "noun", "field", "rest",
    "correct", "able", "pound", "done", "beauty", "drive", "stood", "contain", "front", "teach",
    "week", "final", "gave", "green", "oh", "quick", "develop", "ocean", "warm", "free",
    "minute", "strong", "special", "mind", "behind", "clear", "tail", "produce", "fact", "street",
    "inch", "multiply", "nothing", "course", "stay", "wheel", "full", "force", "blue", "object",
    "decide", "surface", "deep", "moon", "island", "foot", "system", "busy", "test", "record",
    "boat", "common", "gold", "possible", "plane", "stead", "dry", "wonder", "laugh", "thousand",
    "ago", "ran", "check", "game", "shape", "equate", "hot", "miss", "brought", "heat",
    "snow", "tire", "bring", "yes", "distant", "fill", "east", "paint", "language", "among",
}) do
    SKIP_WORDS[w] = true
end

-- Cap on extra hops per keypress so a long run of skip-words (or a patch
-- bug) can never hang key input.
local MAX_SKIP_HOPS = 25

local origGetAdjacentWordRolling = ReaderKeySelection._getAdjacentWordRolling

function ReaderKeySelection:_getAdjacentWordRolling(word, direction, lock_line_center_y, lock_line_tolerance)
    local candidate = origGetAdjacentWordRolling(self, word, direction, lock_line_center_y, lock_line_tolerance)

    -- Don't skip while extending an existing multi-word highlight -- the
    -- user may deliberately want "the" or "a" included in the selection.
    if self.ui.highlight and self.ui.highlight.select_mode then
        return candidate
    end

    local hops = 0
    while candidate and candidate.word and hops < MAX_SKIP_HOPS do
        local key = candidate.word:lower():gsub("^[^%a']+", ""):gsub("[^%a']+$", "")
        if not SKIP_WORDS[key] then
            break
        end
        hops = hops + 1
        candidate = origGetAdjacentWordRolling(self, candidate, direction, lock_line_center_y, lock_line_tolerance)
    end

    return candidate
end
