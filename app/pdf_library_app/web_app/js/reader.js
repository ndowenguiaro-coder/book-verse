pdfjsLib.GlobalWorkerOptions.workerSrc =
  'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';

const bookId = Number(new URLSearchParams(window.location.search).get('id'));

const titleEl = document.getElementById('book-title');
const statusEl = document.getElementById('reader-status');
const canvas = document.getElementById('pdf-canvas');
const ctx = canvas.getContext('2d');
const controls = document.getElementById('reader-controls');
const ttsBtn = document.getElementById('tts-btn');
const ttsLabel = document.getElementById('tts-label');
const pageIndicator = document.getElementById('page-indicator');
const prevBtn = document.getElementById('prev-btn');
const nextBtn = document.getElementById('next-btn');
const speedSelect = document.getElementById('speed-select');
const downloadBtn = document.getElementById('download-btn');
const immersiveBtn = document.getElementById('immersive-btn');
let touchStartX = 0;

let pdfDoc = null;
let currentPage = 1;
let isRendering = false;
let isSpeaking = false;
let isDownloaded = false;
let resumePage = null;

document.addEventListener('DOMContentLoaded', init);

async function init() {
  if (!bookId) {
    showFatalError('Livre introuvable.');
    return;
  }

  try {
    const [book, offlineBytes, progress] = await Promise.all([
      fetchBook(bookId),
      readPdfOffline(bookId),
      fetchReadingProgress(bookId),
    ]);

    titleEl.textContent = book.title;
    document.title = `BookVerse — ${book.title}`;
    resumePage = progress;
    isDownloaded = Boolean(offlineBytes);
    updateDownloadButton();

    let arrayBuffer = offlineBytes;
    if (!arrayBuffer) {
      const response = await fetch(bookPdfUrl(bookId));
      if (!response.ok) throw new Error('Impossible de télécharger le PDF.');
      arrayBuffer = await response.arrayBuffer();
    }

    // On garde une copie en mémoire pour le téléchargement hors-ligne
    // (une ArrayBuffer ne peut être lue qu'une fois par pdf.js).
    window.__pdfArrayBuffer = arrayBuffer.slice(0);

    pdfDoc = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;

    statusEl.hidden = true;
    canvas.hidden = false;
    controls.hidden = false;

    const startPage = resumePage && resumePage > 1 && resumePage <= pdfDoc.numPages ? resumePage : 1;
    await renderPage(startPage);

    registerView(bookId);
  } catch (err) {
    showFatalError(`Impossible de charger le document : ${err.message}`);
  }
}

function pageTurnEffect() {
  const el = document.createElement('div');
  el.className = 'reader-page-turn';
  document.body.appendChild(el);
  el.addEventListener('animationend', () => el.remove(), { once: true });
}

async function renderPage(pageNumber) {
  if (isRendering || !pdfDoc) return;
  isRendering = true;
  try {
    if (pageNumber !== currentPage) pageTurnEffect();
    const page = await pdfDoc.getPage(pageNumber);
    const viewport = page.getViewport({ scale: 1.5 });
    canvas.width = viewport.width;
    canvas.height = viewport.height;
    await page.render({ canvasContext: ctx, viewport }).promise;

    currentPage = pageNumber;
    pageIndicator.textContent = `Page ${currentPage} / ${pdfDoc.numPages}`;
    prevBtn.disabled = currentPage <= 1;
    nextBtn.disabled = currentPage >= pdfDoc.numPages;

    if (isSpeaking) stopSpeech();
    saveReadingProgress(bookId, currentPage);
  } finally {
    isRendering = false;
  }
}

prevBtn.addEventListener('click', () => {
  if (currentPage > 1) renderPage(currentPage - 1);
});

nextBtn.addEventListener('click', () => {
  if (pdfDoc && currentPage < pdfDoc.numPages) renderPage(currentPage + 1);
});

// --- Lecture audio (Web Speech API, équivalent navigateur du TTS mobile) ---

ttsBtn.addEventListener('click', async () => {
  if (isSpeaking) {
    stopSpeech();
    return;
  }
  const text = await extractPageText(currentPage);
  if (!text.trim()) {
    ttsLabel.textContent = 'Aucun texte lisible trouvé sur cette page.';
    setTimeout(() => (ttsLabel.textContent = 'Écouter cette page'), 2500);
    return;
  }
  speak(text);
});

async function extractPageText(pageNumber) {
  const page = await pdfDoc.getPage(pageNumber);
  const content = await page.getTextContent();
  return content.items.map((item) => item.str).join(' ');
}

function speak(text) {
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = 'fr-FR';
  utterance.rate = Number(speedSelect.value);

  utterance.onstart = () => {
    isSpeaking = true;
    ttsBtn.textContent = '⏹';
    ttsLabel.textContent = 'Lecture vocale en cours...';
  };
  utterance.onend = () => {
    isSpeaking = false;
    ttsBtn.textContent = '🔊';
    ttsLabel.textContent = 'Écouter cette page';
  };
  utterance.onerror = () => {
    isSpeaking = false;
    ttsBtn.textContent = '🔊';
    ttsLabel.textContent = "Erreur de synthèse vocale.";
  };

  window.speechSynthesis.cancel();
  window.speechSynthesis.speak(utterance);
}

function stopSpeech() {
  window.speechSynthesis.cancel();
  isSpeaking = false;
  ttsBtn.textContent = '🔊';
  ttsLabel.textContent = 'Écouter cette page';
}

// --- Téléchargement hors-ligne ---

downloadBtn.addEventListener('click', async () => {
  if (isDownloaded || !window.__pdfArrayBuffer) return;
  downloadBtn.textContent = '…';
  try {
    await savePdfOffline(bookId, window.__pdfArrayBuffer);
    isDownloaded = true;
    updateDownloadButton();
  } catch (err) {
    downloadBtn.textContent = '⬇️';
    alert(`Échec du téléchargement : ${err.message}`);
  }
});

function updateDownloadButton() {
  downloadBtn.textContent = isDownloaded ? '✅' : '⬇️';
  downloadBtn.title = isDownloaded ? 'Déjà disponible hors-ligne' : 'Télécharger pour lecture hors-ligne';
}

function showFatalError(message) {
  statusEl.innerHTML = `<div class="error-state" style="color:#FCA5A5;">${message}</div>`;
}


immersiveBtn.addEventListener('click', () => {
  document.body.classList.toggle('reader-immersive');
  const active = document.body.classList.contains('reader-immersive');
  immersiveBtn.textContent = active ? '⛶' : '⛶';
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'ArrowRight') nextBtn.click();
  if (event.key === 'ArrowLeft') prevBtn.click();
  if (event.key === 'Escape') document.body.classList.remove('reader-immersive');
});

document.addEventListener('touchstart', (event) => { touchStartX = event.changedTouches[0].screenX; }, { passive: true });
document.addEventListener('touchend', (event) => {
  const delta = event.changedTouches[0].screenX - touchStartX;
  if (Math.abs(delta) < 55) return;
  if (delta < 0) nextBtn.click(); else prevBtn.click();
}, { passive: true });
