module.exports = Ferdium =>
  class Discord extends Ferdium {
    overrideUserAgent() {
      // Presenting Discord web with a clean modern Chrome User-Agent
      // ensures Discord initializes its standard browser WebRTC stack
      // (preventing RTC Connecting failure).
      return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
    }
  };
