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

function decodeMessage(rawMessage) {
  const message = typeof rawMessage === 'string' ? JSON.parse(rawMessage) : rawMessage;
  if (message?.version !== VERSION || typeof message.type !== 'string') {
    throw new Error('Unsupported bridge message.');
  }
  return message;
}

export function installWorldBridge(onMessage) {
  const handleMessage = (rawMessage) => {
    try {
      return Promise.resolve(onMessage(decodeMessage(rawMessage)));
    } catch (error) {
      postBridgeMessage('rendererError', { message: error.message });
      return Promise.reject(error);
    }
  };

  globalThis.NoveltyWorld = {
    receiveFromFlutter(rawMessage) {
      return handleMessage(rawMessage);
    },
  };

  globalThis.addEventListener('message', (event) => {
    if (event.origin !== globalThis.location.origin) {
      return;
    }
    void handleMessage(event.data);
  });
}
