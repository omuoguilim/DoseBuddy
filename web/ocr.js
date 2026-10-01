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
window.dosebuddyDownload = function(contents,filename) {
 const url=URL.createObjectURL(new Blob([contents],{type:'text/csv;charset=utf-8'}));
 const link=document.createElement('a');link.href=url;link.download=filename;
 document.body.appendChild(link);link.click();link.remove();
 setTimeout(()=>URL.revokeObjectURL(url),1000);
};
