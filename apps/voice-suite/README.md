# Voice Suite

Integration module for two independently runnable applications:

- **WhisprFlow** records and transcribes speech locally.
- **Spark Corrector** corrects selected text on its own and provides the
  `whisprflow` filter context used by WhisprFlow.

The suite injects the exact packaged Spark Corrector into WhisprFlow, so the
hold-to-talk workflow and the standalone correction command cannot drift onto
different implementations.

WhisprFlow keeps fast local transcription separate from semantic formatting.
The Spark `whisprflow` context handles explicitly spoken list structure,
lettered or numbered points, punctuation instructions and code snippets.
