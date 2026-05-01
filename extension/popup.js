chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === "update") {
    const currentVersion = chrome.runtime.getManifest().version;

    // 처음 설치 시 팝업
    if (details.reason === "install") {
     chrome.tabs.create({ url: "HTML/update.html" });
    }

    // 버전 업데이트 시 팝업
    if (currentVersion === "2.5") {
      chrome.tabs.create({ url: "HTML/update.html" });
    }
  }
});