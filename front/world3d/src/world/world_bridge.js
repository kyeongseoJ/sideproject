const VERSION = 1;

export function postBridgeMessage(type, payload = {}) {
  const message = JSON.stringify({ version: VERSION, type, payload });
  if (globalThis.NoveltyWorldBridge?.postMessage) {
    globalThis.NoveltyWorldBridge.postMessage(message);
  }
  if (globalThis.parent && globalThis.parent !== globalThis) {
    globalThis.parent.postMessage(message, globalThis.location.origin);
  }
}

export function installWorldBridge(onMessage) {
  globalThis.NoveltyWorld = {
    receiveFromFlutter(rawMessage) {
      try {
        const message = typeof rawMessage === 'string' ? JSON.parse(rawMessage) : rawMessage;
        if (message?.version !== VERSION || typeof message.type !== 'string') {
          throw new Error('Unsupported bridge message.');
        }
        return Promise.resolve(onMessage(message));
      } catch (error) {
        postBridgeMessage('rendererError', { message: error.message });
        return Promise.reject(error);
      }
    },
  };
}
