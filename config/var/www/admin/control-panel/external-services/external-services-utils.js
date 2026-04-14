// EngineScript External Services Utilities
// Shared helpers for cookie handling and icon token sanitization

/**
 * Check whether a character code is an ASCII alphanumeric character.
 * @param {number} code - Character code
 * @returns {boolean} True when character is [a-z0-9]
 */
function isAsciiLowerAlnum(code) {
  return (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
}

/**
 * Normalize input to a lower-case token string.
 * @param {unknown} value - Raw value to normalize
 * @param {string} fallback - Fallback value when input is empty
 * @returns {string} Normalized token string
 */
function normalizeToken(value, fallback) {
  const candidate = String(value ?? '').trim().toLowerCase();
  return candidate === '' ? fallback : candidate;
}

/**
 * Validate hyphen-separated token segments without regex backtracking.
 * Accepts patterns like "abc" and "abc-def-123".
 * Rejects leading/trailing/double hyphens and non-alphanumeric characters.
 * @param {string} value - Candidate token
 * @returns {boolean} True when token is valid
 */
export function isValidHyphenToken(value) {
  if (value.length === 0) {
    return false;
  }

  let previousWasHyphen = true;

  for (let i = 0; i < value.length; i++) {
    const code = value.charCodeAt(i);

    if (code === 45) {
      if (previousWasHyphen) {
        return false;
      }
      previousWasHyphen = true;
      continue;
    }

    if (!isAsciiLowerAlnum(code)) {
      return false;
    }

    previousWasHyphen = false;
  }

  return !previousWasHyphen;
}

/**
 * Validate a full Font Awesome icon class string like "fa-circle-check".
 * @param {unknown} iconClass - Icon class candidate
 * @returns {string} Safe icon class with fa- prefix
 */
export function sanitizeFaIconClass(iconClass) {
  const candidate = normalizeToken(iconClass, 'fa-question');

  if (!candidate.startsWith('fa-')) {
    return 'fa-question';
  }

  const suffix = candidate.slice(3);
  return isValidHyphenToken(suffix) ? candidate : 'fa-question';
}

/**
 * Validate a Font Awesome icon suffix like "circle-check".
 * @param {unknown} iconName - Icon suffix candidate
 * @returns {string} Safe icon suffix
 */
export function sanitizeFaIconSuffix(iconName) {
  const candidate = normalizeToken(iconName, '');
  return isValidHyphenToken(candidate) ? candidate : '';
}

/**
 * Validate cookie name against RFC token-safe characters without regex.
 * @param {unknown} name - Cookie name
 * @returns {boolean} True when cookie name is safe to use
 */
export function isValidCookieName(name) {
  if (typeof name !== 'string' || name.length === 0) {
    return false;
  }

  for (let i = 0; i < name.length; i++) {
    const code = name.charCodeAt(i);

    const isDigit = code >= 48 && code <= 57;
    const isUpper = code >= 65 && code <= 90;
    const isLower = code >= 97 && code <= 122;

    const isTokenSymbol = (
      code === 33 ||  // !
      code === 35 ||  // #
      code === 36 ||  // $
      code === 37 ||  // %
      code === 38 ||  // &
      code === 39 ||  // '
      code === 42 ||  // *
      code === 43 ||  // +
      code === 45 ||  // -
      code === 46 ||  // .
      code === 94 ||  // ^
      code === 95 ||  // _
      code === 96 ||  // `
      code === 124 || // |
      code === 126    // ~
    );

    if (!isDigit && !isUpper && !isLower && !isTokenSymbol) {
      return false;
    }
  }

  return true;
}

/**
 * Read and decode cookie value.
 * @param {string} name - Cookie name
 * @returns {string|null} Cookie value or null if not found
 */
export function readCookie(name) {
  if (!isValidCookieName(name)) {
    console.warn('Invalid cookie name provided to readCookie');
    return null;
  }

  const nameEQ = `${name}=`;
  const cookies = document.cookie.split(';');

  for (let i = 0; i < cookies.length; i++) {
    let cookie = cookies[i];

    while (cookie.charAt(0) === ' ') {
      cookie = cookie.substring(1, cookie.length);
    }

    if (cookie.startsWith(nameEQ)) {
      const rawValue = cookie.substring(nameEQ.length, cookie.length);

      try {
        return decodeURIComponent(rawValue);
      } catch (error) {
        console.warn(`Failed to decode cookie value for ${name}:`, error);
        return rawValue;
      }
    }
  }

  return null;
}

/**
 * Write a cookie value with secure defaults.
 * @param {string} name - Cookie name
 * @param {unknown} value - Cookie value
 * @param {number} [days=365] - Expiration in days
 * @returns {void}
 */
export function writeCookie(name, value, days = 365) {
  if (!isValidCookieName(name)) {
    console.warn('Invalid cookie name provided to writeCookie');
    return;
  }

  let expires = '';
  if (Number.isFinite(days) && days > 0) {
    const date = new Date();
    date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
    expires = `; expires=${date.toUTCString()}`;
  }

  const encodedValue = encodeURIComponent(value == null ? '' : String(value));
  document.cookie = `${name}=${encodedValue}${expires}; path=/; SameSite=Strict; Secure`;
}

/**
 * Remove a cookie using an expired date.
 * @param {string} name - Cookie name
 * @returns {void}
 */
export function removeCookie(name) {
  if (!isValidCookieName(name)) {
    console.warn('Invalid cookie name provided to removeCookie');
    return;
  }

  document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; SameSite=Strict; Secure`;
}
