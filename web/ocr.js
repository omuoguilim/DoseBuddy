// Images stay in this browser; only OCR library/model assets are downloaded.
window.dosebuddyRecognize = async function(path) {
  if (!window.Tesseract) {
    await new Promise((resolve,reject)=>{
      const script=document.createElement('script');
      script.src='https://cdn.jsdelivr.net/npm/tesseract.js@6/dist/tesseract.min.js';
      script.onload=resolve;script.onerror=()=>reject(new Error('OCR download failed'));
      document.head.appendChild(script);
    });
  }
  const worker=await Tesseract.createWorker('eng');
  try { const result=await worker.recognize(path); return result.data.text; }
  finally { await worker.terminate(); }
};
