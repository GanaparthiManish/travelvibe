/**
 * Fuzzy Name Matching Utility for Agent Payout Verification
 * Compares entered account holder name against the agent's verified profile name.
 */
export function normalizeName(name) {
  if (!name) return '';
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function verifyNameMatch(enteredName, verifiedName) {
  const normEntered = normalizeName(enteredName);
  const normVerified = normalizeName(verifiedName);

  if (!normEntered || !normVerified) {
    return {
      verified: false,
      score: 0,
      reason: 'Missing name information',
    };
  }

  // Exact normalized match
  if (normEntered === normVerified) {
    return {
      verified: true,
      score: 1.0,
      reason: 'Exact match',
    };
  }

  const enteredTokens = normEntered.split(' ').filter(Boolean);
  const verifiedTokens = normVerified.split(' ').filter(Boolean);

  // Check if all tokens of one are in the other (e.g. "Manish" in "Manish Ganaparthi")
  const enteredInVerified = enteredTokens.filter((t) => verifiedTokens.includes(t));
  const verifiedInEntered = verifiedTokens.filter((t) => enteredTokens.includes(t));

  const commonTokens = new Set([...enteredInVerified, ...verifiedInEntered]);
  const allTokens = new Set([...enteredTokens, ...verifiedTokens]);

  const tokenOverlap = commonTokens.size / allTokens.size;

  // Handle reordered names (e.g., "Ganaparthi Manish" vs "Manish Ganaparthi")
  const sortedEntered = [...enteredTokens].sort().join(' ');
  const sortedVerified = [...verifiedTokens].sort().join(' ');
  if (sortedEntered === sortedVerified) {
    return {
      verified: true,
      score: 0.98,
      reason: 'Reordered name tokens matched',
    };
  }

  // Substring check (e.g. initials or prefix/suffix)
  if (normVerified.includes(normEntered) || normEntered.includes(normVerified)) {
    if (tokenOverlap >= 0.5) {
      return {
        verified: true,
        score: 0.85,
        reason: 'Contained name with sufficient token overlap',
      };
    }
  }

  // Levenshtein distance on full string
  const lev = levenshteinDistance(normEntered, normVerified);
  const maxLen = Math.max(normEntered.length, normVerified.length);
  const stringSimilarity = (maxLen - lev) / maxLen;

  const score = Math.max(tokenOverlap, stringSimilarity);

  if (score >= 0.70) {
    return {
      verified: true,
      score: parseFloat(score.toFixed(2)),
      reason: `Fuzzy match confidence ${Math.round(score * 100)}%`,
    };
  }

  return {
    verified: false,
    score: parseFloat(score.toFixed(2)),
    reason: `Confidence ${Math.round(score * 100)}% below 70% threshold (${normEntered} vs ${normVerified})`,
  };
}

function levenshteinDistance(a, b) {
  const matrix = Array.from({ length: a.length + 1 }, () =>
    new Array(b.length + 1).fill(0)
  );

  for (let i = 0; i <= a.length; i++) matrix[i][0] = i;
  for (let j = 0; j <= b.length; j++) matrix[0][j] = j;

  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost
      );
    }
  }

  return matrix[a.length][b.length];
}
