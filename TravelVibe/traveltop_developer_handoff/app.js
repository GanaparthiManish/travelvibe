// Screen navigation
function switchScreen(name, btn) {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.pill').forEach(p => p.classList.remove('active'));
  document.getElementById('screen-' + name).classList.add('active');
  if (btn) btn.classList.add('active');
}

// Login -> Home transition
function goToHome() {
  const pills = document.querySelectorAll('.pill');
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.pill').forEach(p => p.classList.remove('active'));
  document.getElementById('screen-home').classList.add('active');
  pills[2].classList.add('active');
}

// Category select
function setActive(el) {
  el.closest('.category-row').querySelectorAll('.category-item').forEach(i => i.classList.remove('active'));
  el.classList.add('active');
}

// Splash auto-advance
window.addEventListener('load', () => {
  setTimeout(() => {
    const pills = document.querySelectorAll('.pill');
    switchScreen('login', pills[1]);
  }, 2500);
});
