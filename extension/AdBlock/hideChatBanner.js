function hideChatBanner() {
  const banner = document.querySelector(".chat_banner2.on");
  if (banner) {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        banner.style.display = "none";
      });
    });
  }
}

hideChatBanner();

const observer = new MutationObserver(() => {
  hideChatBanner();
});

observer.observe(document.body, { childList: true, subtree: true });
