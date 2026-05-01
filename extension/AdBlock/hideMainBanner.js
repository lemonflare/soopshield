function hideMainBanner() { // 홈 상단 광고 배너
  const closeBtn = document.querySelector(".mainBanner_close__ftU15");
  if (closeBtn) closeBtn.click();
}

hideMainBanner();

window.addEventListener("load", () => {
  hideMainBanner();

  for (let delay = 0; delay <= 50; delay += 5) {
    setTimeout(hideMainBanner, delay);
  }

  setTimeout(hideMainBanner, 100);
  setTimeout(hideMainBanner, 1000);
});