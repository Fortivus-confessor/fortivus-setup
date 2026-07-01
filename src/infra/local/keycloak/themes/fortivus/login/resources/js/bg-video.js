/*
 * FORTIVUS — Vídeo de fundo do login.
 * Injeta um <video> em tela cheia atrás do conteúdo, sem alterar o
 * template nem a lógica de autenticação (carregado via `scripts` no
 * theme.properties). Se o vídeo falhar, o degradê azul do body permanece.
 */
(function () {
  // currentScript só é válido durante a execução síncrona no <head>.
  var self = document.currentScript;
  var videoUrl;
  try {
    videoUrl = new URL('../img/video_keycloak_tema.mp4', self.src).href;
  } catch (e) {
    return; // sem base de URL, mantém o fallback (degradê)
  }

  function mount() {
    if (!document.body || document.querySelector('.fv-bg-video')) return;

    var overlay = document.createElement('div');
    overlay.className = 'fv-bg-overlay';

    var video = document.createElement('video');
    video.className = 'fv-bg-video';
    video.autoplay = true;
    video.loop = true;
    video.muted = true;
    video.defaultMuted = true;
    video.playsInline = true;
    // atributos para autoplay em Safari/iOS
    video.setAttribute('autoplay', '');
    video.setAttribute('loop', '');
    video.setAttribute('muted', '');
    video.setAttribute('playsinline', '');
    video.setAttribute('preload', 'auto');

    var source = document.createElement('source');
    source.src = videoUrl;
    source.type = 'video/mp4';
    video.appendChild(source);

    document.body.insertBefore(overlay, document.body.firstChild);
    document.body.insertBefore(video, document.body.firstChild);

    var p = video.play();
    if (p && typeof p.catch === 'function') {
      p.catch(function () { /* autoplay bloqueado: overlay/degradê seguem visíveis */ });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mount);
  } else {
    mount();
  }
})();
