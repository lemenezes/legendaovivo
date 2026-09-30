<template>
  <div class="pip-caption-container">
    <!-- clientReady evita divergência SSR/cliente em propriedades que dependem de APIs do browser -->
    <template v-if="clientReady">
      <button
        class="pip-button"
        :class="{
          'pip-button--active': isPipActive,
          'pip-button--unavailable': !isSupported,
        }"
        :disabled="!isSupported"
        :aria-label="buttonLabel"
        :aria-pressed="isPipActive"
        @click="togglePip"
        title="Use este modo para acompanhar a legenda enquanto navega em outra aba ou app."
      >
        <svg
          aria-hidden="true"
          focusable="false"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
          <rect x="12" y="11" width="8" height="6" rx="1" ry="1" />
        </svg>
        {{ buttonLabel }}
      </button>
    </template>

    <!-- Canvas e vídeo só montados no cliente (v-if=clientReady) para evitar refs nulos em SSR -->
    <canvas v-if="clientReady" ref="canvas" class="pip-canvas" aria-hidden="true" />
    <video v-if="clientReady" ref="video" class="pip-video" playsinline aria-hidden="true" />
  </div>
</template>

<script>
const CANVAS_WIDTH = 1280;
const CANVAS_HEIGHT = 360;
const FONT_SIZE = 52;
const PADDING = 40;
const LINE_HEIGHT = 1.35;
const BG_COLOR = '#111111';
const TEXT_COLOR = '#ffffff';
const PLACEHOLDER_COLOR = '#777777';
const MAX_LINES = 3;

export default {
  name: 'PipCaption',

  data() {
    return {
      // Só vira true no mounted() — garante que nenhuma API de browser
      // é acessada durante SSR/renderização no servidor.
      clientReady: false,
      isPipActive: false,
      stream: null,
      rafId: null,
    };
  },

  computed: {
    isSupported() {
      if (!this.clientReady) return false;
      return (
        !!document.pictureInPictureEnabled &&
        typeof HTMLCanvasElement.prototype.captureStream === 'function'
      );
    },

    buttonLabel() {
      if (!this.isSupported) return 'Legenda flutuante indisponível';
      if (this.isPipActive) return 'Fechar legenda flutuante';
      return 'Abrir legenda flutuante';
    },

    currentText() {
      const state = this.$store.state.captioner.transcript;
      if (this.$store.state.settings.stabilizedThresholdMs !== 0) {
        return state.stabilized || '';
      }
      const base = state.final || '';
      const interim = state.interim || '';
      return (base + (interim ? ' ' + interim : '')).trim();
    },
  },

  mounted() {
    // Só aqui temos garantia de estar no browser
    this.clientReady = true;
  },

  beforeDestroy() {
    this.stopPip();
  },

  methods: {
    async togglePip() {
      if (this.isPipActive) {
        this.stopPip();
      } else {
        await this.startPip();
      }
    },

    async startPip() {
      if (!this.isSupported) return;

      const canvas = this.$refs.canvas;
      const video = this.$refs.video;

      canvas.width = CANVAS_WIDTH;
      canvas.height = CANVAS_HEIGHT;

      // Renderiza um frame inicial antes de criar o stream
      this.renderCanvas(this.currentText);

      this.stream = canvas.captureStream(30);
      video.srcObject = this.stream;

      try {
        await video.play();
        await video.requestPictureInPicture();
        this.isPipActive = true;

        // Inicia o loop de atualização do canvas para evitar frame congelado
        this.startRenderLoop();

        video.addEventListener('leavepictureinpicture', this.onLeavePip, { once: true });
      } catch (err) {
        console.error('[PipCaption] Erro ao abrir Picture-in-Picture:', err);
        this.stopPip();
      }
    },

    stopPip() {
      this.stopRenderLoop();
      if (document.pictureInPictureElement) {
        document.exitPictureInPicture().catch(() => {});
      }
      if (this.stream) {
        this.stream.getTracks().forEach((t) => t.stop());
        this.stream = null;
      }
      const video = this.$refs.video;
      if (video) {
        video.srcObject = null;
      }
      this.isPipActive = false;
    },

    onLeavePip() {
      this.stopPip();
    },

    // Loop RAF para manter o canvas sempre atualizado enquanto PiP está ativo.
    // Impede que o frame congele quando o texto não muda por algum tempo.
    startRenderLoop() {
      const loop = () => {
        this.renderCanvas(this.currentText);
        this.rafId = requestAnimationFrame(loop);
      };
      this.rafId = requestAnimationFrame(loop);
    },

    stopRenderLoop() {
      if (this.rafId !== null) {
        cancelAnimationFrame(this.rafId);
        this.rafId = null;
      }
    },

    renderCanvas(text) {
      const canvas = this.$refs.canvas;
      if (!canvas) return;

      const ctx = canvas.getContext('2d');
      const w = CANVAS_WIDTH;
      const h = CANVAS_HEIGHT;
      const isPlaceholder = !text;
      const displayText = text || 'Aguardando legenda...';

      // Fundo
      ctx.fillStyle = BG_COLOR;
      ctx.fillRect(0, 0, w, h);

      // Texto — levemente acinzentado e itálico para o placeholder
      ctx.fillStyle = isPlaceholder ? PLACEHOLDER_COLOR : TEXT_COLOR;
      ctx.font = `${isPlaceholder ? 'italic ' : 'bold '}${FONT_SIZE}px 'Segoe UI', Arial, sans-serif`;
      ctx.textBaseline = 'top';

      const maxWidth = w - PADDING * 2;
      const lineHeightPx = Math.round(FONT_SIZE * LINE_HEIGHT);
      const lines = this.wrapText(ctx, displayText, maxWidth);

      // Mostrar apenas as últimas MAX_LINES linhas
      const visibleLines = lines.slice(-MAX_LINES);
      const totalHeight = visibleLines.length * lineHeightPx;
      const startY = (h - totalHeight) / 2;

      visibleLines.forEach((line, i) => {
        ctx.fillText(line, PADDING, startY + i * lineHeightPx);
      });
    },

    wrapText(ctx, text, maxWidth) {
      const words = text.split(' ');
      const lines = [];
      let current = '';

      for (const word of words) {
        const test = current ? current + ' ' + word : word;
        if (ctx.measureText(test).width > maxWidth && current) {
          lines.push(current);
          current = word;
        } else {
          current = test;
        }
      }
      if (current) lines.push(current);
      return lines;
    },
  },
};
</script>

<style scoped>
.pip-caption-container {
  display: inline-flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.4rem;
}

.pip-button {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.45rem 0.9rem;
  font-size: 0.85rem;
  font-weight: 600;
  color: #fff;
  background-color: #1a1a2e;
  border: 2px solid #4a4a8a;
  border-radius: 6px;
  cursor: pointer;
  transition: background-color 0.15s, border-color 0.15s;
  line-height: 1.3;
}

.pip-button:hover,
.pip-button:focus-visible {
  background-color: #2e2e60;
  border-color: #7b7bcf;
  outline: 3px solid #7b7bcf;
  outline-offset: 2px;
}

.pip-button--active {
  background-color: #2e2e60;
  border-color: #7b7bcf;
}

.pip-button--unavailable,
.pip-button[disabled] {
  opacity: 0.5;
  cursor: not-allowed;
}

.pip-button--unavailable:hover,
.pip-button--unavailable:focus-visible,
.pip-button[disabled]:hover,
.pip-button[disabled]:focus-visible {
  background-color: #1a1a2e;
  border-color: #4a4a8a;
  outline: none;
}

.pip-hint {
  font-size: 0.75rem;
  color: #aaa;
  margin: 0;
  max-width: 340px;
}

/* Canvas e vídeo ficam fora da tela — necessários para o stream funcionar */
.pip-canvas,
.pip-video {
  position: fixed;
  top: -9999px;
  left: -9999px;
  width: 1px;
  height: 1px;
  pointer-events: none;
  visibility: hidden;
}
</style>
