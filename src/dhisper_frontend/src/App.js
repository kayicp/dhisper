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
    this.isComposing = false;
    this.isSending = false;
    this.postContent = "";
    this.charCount = 0;
    this.assetType = "None";
    this.root = document.getElementById('root');
    this.background = this.getRandomGradient();

    this.setupScrollHandler();
    this.renderPosts();
  }

  updateCharCount(e) {
    this.postContent = e.target.value;
    this.charCount = this.postContent.length;
    this.renderPosts();
  }
  
  updateAssetType(e) {
    this.assetType = e.target.value;
    this.renderPosts();
  }
  
  async handleSubmit(e) {
    e.preventDefault();
    this.postContent = !this.postContent ? "" : this.postContent.trim();
    if (this.postContent.length === 0) return;

    this.isSending = true;
    this.renderPosts();

    try {
      const create_res = await dhisper_backend.kay4_create({
        thread: [],
        content: this.postContent,
        files: [],
        owners: [],
        metadata: [],
        authorization: { None: { subaccount: [] } },
      });
      this.isSending = false;
      if ('Err' in create_res) {
        alert(`Create post error: ${JSON.stringify(create_res.Err)}`);
      } else {
        alert("Post created!");
        const post_id = create_res.Ok;
        const contents = await dhisper_backend.kay4_contents_of([post_id]);
        
        this.posts = []
        for (const content of contents) {
          this.posts.push(content);
        }
        this.currentIndex = 0;
        this.isComposing = false;
        this.postContent = '';
        this.charCount = 0;
        this.assetType = 'None';
  
        this.startSlide(0, 'down');
      }
    } catch (e) {
      this.isSending = false;
    }

    
  }
  

  setupScrollHandler() {
    window.addEventListener('wheel', (e) => {
      if (this.isAnimating) return;
      if (this.isComposing) return;

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

  handleCreatePost() {
    alert("Create Post clicked!");
  }

  renderPosts() {
    const currentPost = this.posts[this.currentIndex];
    const nextPost = this.nextIndex !== null ? this.posts[this.nextIndex] : null;

    const postLayers = html`
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
    `;
    const drawer = html`
      ${this.isComposing
      ? html`<div class="backdrop" @click=${() => { 
          this.isComposing = false; 
          this.renderPosts(); 
        }}></div>`
      : null}
      <div class="compose-drawer ${this.isComposing ? 'open' : ''}">
        <div>Create New Post</div>
        <form @submit=${(e) => this.handleSubmit(e)}>
          <label class="field">
            <input type="text" maxlength="140" placeholder="What's on your mind?" 
                  @input=${(e) => this.updateCharCount(e)} 
                  .value=${this.postContent || ''}
                  required />
            <span class="char-count ${this.charCount >= 140 ? 'limit' : ''}">
              ${this.charCount}/140
            </span>
          </label>

          <label class="field">
            <select @change=${(e) => this.updateAssetType(e)} .value=${this.assetType}>
              <option value="None">None</option>
              <option value="ICRC_1">ICRC_1</option>
              <option value="ICRC_2">ICRC_2</option>
            </select>
          </label>

          <label class="field">
            <input type="text" placeholder="Subaccount (hex, optional)" />
          </label>

          ${this.assetType === 'ICRC_1'
            ? html`<div class="info">Your balance: 1.5 ICP, Token minimum: 1 ICP</div>`
            : this.assetType === 'ICRC_2'
            ? html`
                <label class="field">
                  <select>
                    <option value="ICP">Internet Computer (ICP)</option>
                    <option value="ckBTC">ckBTC (ckBTC)</option>
                  </select>
                </label>
                <div class="info">Fee: 0</div>
              `
            : null}

          <button type="submit" class="send-btn" ?disabled=${this.isSending}>
            ${this.isSending
              ? html`<span class="spinner"></span> Sending...`
              : html`➤ Send`}
          </button>
        </form>
      </div>
    `;
    render(html`
      <div class="post-wrapper">
        ${postLayers}
        ${drawer}
        <button class="create-post-btn" @click=${() => { 
          this.isComposing = true; 
          this.renderPosts();
        }}>+</button>
      </div>
    `, this.root);
  }
}

export default App;