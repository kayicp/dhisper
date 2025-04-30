import { html, render } from 'lit-html';
import { dhisper_backend } from 'declarations/dhisper_backend';

// Utility: Generate random gradient
function randomGradient() {
  const colors = [];
  for (let i = 0; i < 2; i++) colors.push(`#${Math.floor(Math.random()*16777215).toString(16).padStart(6, '0')}`);
  return `linear-gradient(135deg, ${colors[0]}, ${colors[1]})`;
}

// Confirmation Dialog
class ConfirmDialog {
  constructor(message, onConfirm) {
    this.message = message;
    this.onConfirm = onConfirm;
    this.visible = false;
  }
  open() { this.visible = true; this.update(); }
  close() { this.visible = false; this.update(); }
  update() { render(this.render(), document.getElementById('modal-root')); }
  render() {
    if (!this.visible) return html``;
    return html`
      <div class="modal-overlay" @click="${() => this.close()}">
        <div class="modal" @click="${e => e.stopPropagation()}">
          <p>${this.message}</p>
          <div class="actions">
            <button @click="${() => this.close()}">Cancel</button>
            <button class="danger" @click="${() => { this.onConfirm(); this.close(); }}">Delete</button>
          </div>
        </div>
      </div>
    `;
  }
}

// Comment Viewer Pane
class CommentViewer {
  constructor(post, onBack) {
    this.post = post;
    this.comments = [];
    this.onBack = onBack;
    this.body = '';
    this.auth = 'ICRC_1';
    this.loading = false;
    this.loadComments();
  }

  async loadComments() {
    this.loading = true;
    this.update();
    this.comments = [{ body: 'get comment', timestamp: new Date(), mine: false }]; // await dhisper_backend.get_comments({ postId: this.post.id });
    this.loading = false;
    this.update();
  }

  handleInput(e) {
    this.body = e.target.value;
    this.update();
  }

  handleAuth(e) {
    this.auth = e.target.value;
    this.update();
  }

  async submit() {
    if (this.body.length < 1 || this.body.length > 200) return;
    this.loading = true;
    this.update();
    // const newComment = await dhisper_backend.create_comment({ postId: this.post.id, body: this.body, auth: this.auth });
    this.comments.push({ body: 'new comment', timestamp: new Date(), mine: true });
    this.body = '';
    this.loading = false;
    this.update();
  }

  render() {
    return html`
      <div class="two-pane">
        <section class="left-pane">
          ${new PostCard(this.post, true).render()}
          <button @click="${this.onBack}" class="back-btn">← Back</button>
        </section>
        <section class="right-pane">
          <header class="sticky">Comments</header>
          <div class="comments-list">
            ${this.comments.map((c, i) => html`
              <div class="comment-card" style="background: ${i % 2 ? '#fafafa' : '#f0f0f0'}">
                <p>${c.body}</p>
                <small>${new Date(c.timestamp).toLocaleString()}</small>
                ${c.mine ? html`<button class="delete-btn" @click="${() => this.confirmDelete(c.id)}">🗑️</button>` : ''}
              </div>
            `)}
          </div>
          <div class="add-comment">
            <textarea maxlength="200" .value="${this.body}" @input="${this.handleInput.bind(this)}"></textarea>
            <div class="controls">
              <span class="counter" style="color: ${this.body.length>=180?'red':'inherit'}">${this.body.length}/200</span>
              <select @change="${this.handleAuth.bind(this)}">
                <option>ICRC_1</option><option>ICRC_2</option>
              </select>
              <button ?disabled="${this.body.length<1}" @click="${() => this.submit()}">Add Comment</button>
            </div>
          </div>
        </section>
      </div>
    `;
  }

  confirmDelete(commentId) {
    const dlg = new ConfirmDialog('Delete this comment? This cannot be undone.', async () => {
      // await dhisper_backend.delete_comment({ commentId });
      // this.comments = this.comments.filter(c => c.id !== commentId);
      // this.update();
    });
    dlg.open();
  }
}


// PostCard component
class PostCard {
  constructor(post, standalone=false) {
    this.post = post;
    this.gradient = randomGradient();
    this.standalone = standalone;
  }

  render() {
    const { id, author, content, timestamp, commentsCount, mine } = this.post;
    const preview = content.length > 100 ? content.slice(0, 100) + '...' : content;
    return html`
      <section class="post-card" tabindex="0" style="background:${this.gradient}; color:white;">
        <div class="header">
          <span class="author">${author}</span>
          <span class="timestamp">${new Date(timestamp).toLocaleString()}</span>
          ${mine ? html`<button class="small delete-btn" @click="${() => this.confirmDelete()}">🗑️</button>` : ''}
        </div>
        <div class="content">${preview}</div>
        ${!this.standalone ? html`<button class="comment-btn" @click="${() => this.openComments()}">💬 ${commentsCount}</button>` : ''}
      </section>
    `;
  }

  openComments() {
    const app = window.__feedApp;
    app.showComments(this.post);
  }

  confirmDelete() {
    const dlg = new ConfirmDialog('Delete this post? This cannot be undone.', async () => {
      // await dhisper_backend.delete_post({ postId: this.post.id });
      // const app = window.__feedApp;
      // app.removePost(this.post.id);
    });
    dlg.open();
  }
}


// Tabs control
class FeedTabs {
  constructor(onChange) {
    this.active = 'New';
    this.onChange = onChange;
  }

  setActive(tab) {
    if (this.active !== tab) {
      this.active = tab;
      this.onChange(tab);
    }
  }

  render() {
    return html`
      <nav class="tabs">
        ${['New', 'Hot'].map(tab => html`
          <div
            class="tab ${this.active === tab ? 'active' : ''}"
            @click="${() => this.setActive(tab)}"
          >
            ${tab}
          </div>
        `)}
        <div class="underline" style="transform: translateX(${this.active === 'Hot' ? '100%' : '0'})"></div>
      </nav>
    `;
  }
}

// Create Post Modal
class CreatePostModal {
  constructor(onSubmit) {
    this.visible = false;
    this.body = '';
    this.auth = 'ICRC_1';
    this.onSubmit = onSubmit;
  }

  open() { this.visible = true; this.update(); }
  close() { this.visible = false; this.update(); }

  update() {
    render(this.render(), document.getElementById('modal-root'));
  }

  handleInput(e) {
    this.body = e.target.value;
    this.update();
  }

  handleAuth(e) {
    this.auth = e.target.value;
    this.update();
  }

  async submit() {
    if (this.body.length < 10) return;
    try {
      // await dhisper_backend.create_post({ body: this.body, auth: this.auth });
      // this.close();
      // this.onSubmit();
    } catch (err) {
      console.error(err);
      alert('Failed to create post');
    }
  }

  render() {
    if (!this.visible) return html``;
    const count = this.body.length;
    return html`
      <div class="modal-overlay" @click="${() => this.close()}">
        <div class="modal" @click="${e => e.stopPropagation()}">
          <h2>Create New Post</h2>
          <textarea
            rows="3"
            maxlength="280"
            .value="${this.body}"
            @input="${this.handleInput.bind(this)}"
          ></textarea>
          <div class="controls">
            <span class="counter" style="color: ${count >= 280 ? 'red' : count >= 252 ? 'orange' : 'inherit'}">
              ${count}/280
            </span>
            <select @change="${this.handleAuth.bind(this)}">
              <option>ICRC_1</option>
              <option>ICRC_2</option>
            </select>
          </div>
          <div class="actions">
            <button @click="${() => this.close()}">Cancel</button>
            <button
              ?disabled="${count < 10}"
              @click="${() => this.submit()}">
              Submit
            </button>
          </div>
        </div>
      </div>
    `;
  }
}

// Main App
// type SortMode = 'new' | 'hot';
class FeedApp {
  constructor() {
    window.__feedApp = this;
    this.posts = [];
    this.commentsViewer = null;
    this.sort = 'new';
    this.tabs = new FeedTabs(this.switchTab.bind(this));
    this.modal = new CreatePostModal(this.refresh.bind(this));
    this.init();
  }

  async init() { 
    // await this.loadPosts(); 
    this.render(); 
  }
  async loadPosts() {
    // this.posts = await dhisper_backend.get_feed({ sort: this.sort });
    this.render();
  }
  async refresh() { 
    // await this.loadPosts(); 
  }
  switchTab(tab) { this.sort = tab.toLowerCase(); this.loadPosts(); }
  showComments(post) { this.commentsViewer = new CommentViewer(post, () => { this.commentsViewer = null; this.render(); }); this.render(); }
  removePost(postId) { this.posts = this.posts.filter(p => p.id !== postId); this.render(); }

  render() {
    const feed = html`
      <div class="feed-container">
        ${this.tabs.render()}
        ${this.commentsViewer
          ? this.commentsViewer.render()
          : html`<div class="scroll-container">${this.posts.map(p => new PostCard(p).render())}</div>`
        }
        <button class="create-btn" @click="${() => this.modal.open()}">Create New Post</button>
      </div>
    `;
    render(html`<div id="modal-root"></div>${feed}`, document.getElementById('root'));
  }
}

// Render App
function renderMain() { new FeedApp(); }
class App { constructor() { renderMain(); } }
export default App;
