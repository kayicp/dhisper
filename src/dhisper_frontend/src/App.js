import { html, render } from 'lit-html';
import { dhisper_backend } from 'declarations/dhisper_backend';

BigInt.prototype.toJSON = function () {
  return this.toString();
};

const blob2hex = blob => Array.from(blob).map(byte => byte.toString(16).padStart(2, '0')).join('');
Uint8Array.prototype.toJSON = function () {
  return blob2hex(this) // Array.from(this).toString();
}

function randomGradient() {
  const colors = [];
  for (let i = 0; i < 2; i++) colors.push(`#${Math.floor(Math.random()*16777215).toString(16).padStart(6, '0')}`);
  return `linear-gradient(135deg, ${colors[0]}, ${colors[1]})`;
}

class App {
  constructor() {
    this.posts = [
      "1) Welcome to TextTok!",
      "2) Here's your second post.",
      "3) Swipe up to discover more.",
      "4) Keep scrolling to read more text-based content.",
    ];
    this.currentIndex = 0;
    this.nextIndex = null;
    this.direction = null;
    this.isAnimating = false;
    this.root = document.getElementById('root');
    this.background = this.getRandomGradient();

    this.setupScrollHandler();
    this.renderPosts();
  }

  setupScrollHandler() {
    window.addEventListener('wheel', (e) => {
      if (this.isAnimating) return;

      if (e.deltaY > 0 && this.currentIndex < this.posts.length - 1) {
        this.startSlide(this.currentIndex + 1, 'up');
      } else if (e.deltaY < 0 && this.currentIndex > 0) {
        this.startSlide(this.currentIndex - 1, 'down');
      }
    });
  }

  getRandomGradient() {
    return randomGradient();
  }

  startSlide(newIndex, direction) {
    this.isAnimating = true;
    this.nextIndex = newIndex;
    this.direction = direction;
    this.nextBackground = this.getRandomGradient();

    this.renderPosts();

    setTimeout(() => {
      this.currentIndex = newIndex;
      this.background = this.nextBackground;
      this.nextIndex = null;
      this.direction = null;
      this.isAnimating = false;
      this.renderPosts();
    }, 600);
  }

  renderPosts() {
    const currentPost = this.posts[this.currentIndex];
    const nextPost = this.nextIndex !== null ? this.posts[this.nextIndex] : null;

    render(html`
      <div class="post-layer current ${this.direction === 'up' ? 'slide-out-up' : this.direction === 'down' ? 'slide-out-down' : ''}"
           style="background: ${this.background}">
        <div class="text">${currentPost}</div>
      </div>

      ${nextPost !== null
        ? html`
            <div class="post-layer next ${this.direction === 'up' ? 'slide-in-up' : 'slide-in-down'}"
                 style="background: ${this.nextBackground}">
              <div class="text">${nextPost}</div>
            </div>
          `
        : null}
    `, this.root);
  }
}

export default App;