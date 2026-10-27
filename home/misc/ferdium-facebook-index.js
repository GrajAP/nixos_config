module.exports = Ferdium =>
  class Facebook extends Ferdium {
    overrideUserAgent() {
      return window.navigator.userAgent
        .replace(/(Ferdium|Electron)\/\S+\s*/g, '')
        .replace(/\s+/g, ' ')
        .trim();
    }
  };
