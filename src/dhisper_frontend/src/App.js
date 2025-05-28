import { html, render } from 'lit-html';
import { dhisper_backend as dhisper_anon, createActor as genDhisper, canisterId as dhisper_id } from 'declarations/dhisper_backend';
import { createActor as genToken } from 'declarations/icp_token';
import { AuthClient } from "@dfinity/auth-client";
import { HttpAgent } from '@dfinity/agent';

let internet_identity = null;
let caller_principal = null;

let dhisper_user = null;
let token_anon = null;
let token_user = null;

const network = process.env.DFX_NETWORK;
const identityProvider =
  network === 'ic'
    ? 'https://identity.ic0.app' // Mainnet
    : 'http://rdmx6-jaaaa-aaaaa-aaadq-cai.localhost:5000'; // Local

BigInt.prototype.toJSON = function () {
  return this.toString();
};

/**
 * @typedef {'Int'|'Nat'|'Blob'|'Bool'|'Text'|'Principal'|'Array'|'Map'|'ValueMap'} Variant
 * @typedef {bigint|boolean|string|Uint8Array|number[]|Principal} Payload
 * @typedef {{ [K in Variant]?: any }} Type
 */

/**
 * Recursively converts your iced-typed value into a plain JS value.
 * 
 * - Int/Nat → number (via Number())
 * - Bool/Text/Principal/Blob → raw payload
 * - Array → JS array
 * - Map → plain object with string keys
 * - ValueMap → JS Map with arbitrary keys
 * 
 * @param {Type} typed 
 * @returns {any}
 */
function convertTyped(typed) {
  // find which variant this is
  const [[variant, payload]] = Object.entries(typed);

  switch (variant) {
    case 'Int':
    case 'Nat':
      // if you really need JS numbers:
      return Number(payload);
      // or, to preserve bigints, just: return payload;

    case 'Bool':
    case 'Text':
    case 'Principal':
      return payload;

    case 'Blob':
      // pass through Uint8Array or number[]
      return payload;

    case 'Array':
      // payload: Array<Type>
      return payload.map(convertTyped);

    case 'Map':
      // payload: Array<[string, Type]>
      return payload.reduce((obj, [key, val]) => {
        obj[key] = convertTyped(val);
        return obj;
      }, {});

    case 'ValueMap':
      // payload: Array<[Type, Type]>
      // we’ll return a JS Map so non-string keys are allowed
      return new Map(
        payload.map(([k, v]) => [ convertTyped(k), convertTyped(v) ])
      );

    default:
      throw new Error(`Unknown variant ${variant}`);
  }
}

const blob2hex = blob => Array.from(blob).map(byte => byte.toString(16).padStart(2, '0')).join('');
Uint8Array.prototype.toJSON = function () {
  return blob2hex(this) // Array.from(this).toString();
}

function randomGradient() {
  const colors = [];
  for (let i = 0; i < 2; i++) colors.push(`#${Math.floor(Math.random()*16777215).toString(16).padStart(6, '0')}`);
  return `linear-gradient(135deg, ${colors[0]}, ${colors[1]})`;
}

function timeAgo(date) {
  const now = new Date();
  const diffInSeconds = Math.floor((now - date) / 1000);

  const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });

  if (diffInSeconds < 60) {
    return rtf.format(-diffInSeconds, 'second');
  }

  const diffInMinutes = Math.floor(diffInSeconds / 60);
  if (diffInMinutes < 60) {
    return rtf.format(-diffInMinutes, 'minute');
  }

  const diffInHours = Math.floor(diffInMinutes / 60);
  if (diffInHours < 24) {
    return rtf.format(-diffInHours, 'hour');
  }

  const diffInDays = Math.floor(diffInHours / 24);
  if (diffInDays < 30) {
    return rtf.format(-diffInDays, 'day');
  }

  const diffInMonths = Math.floor(diffInDays / 30);
  if (diffInMonths < 12) {
    return rtf.format(-diffInMonths, 'month');
  }

  const diffInYears = Math.floor(diffInMonths / 12);
  return rtf.format(-diffInYears, 'year');
}

class App {
  constructor() {
    this.posts = [];
    this.currentIndex = 0;
    this.nextIndex = null;
    this.direction = null;
    this.isAnimating = false;
    this.isComposingNewThread = false;
    this.isCreatingNewThread = false;
    this.isSelectingWallet = false;
    this.isConnectingWallet = false;
    this.isSelectingToken = false;
    this.isRequireApproval = false;
    this.isApproving = false;
    this.postContent = "";
    this.charCount = 0;
    this.assetType = "None";
    this.root = document.getElementById('root');
    this.background = this.getRandomGradient();
    this.isCommentOpen = false;
    this.activeThread = null;
    this.threadComments = [];
    this.isCommentFormOpen = false;
    this.commentInput = "";
    this.commentCharCount = 0;
    this.commentAssetType = "None";
    this.commentSubaccount = "";
    this.commentToken = "ICP";

    this.setupScrollHandler();
    this.renderPosts();
    this.getPosts();
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

    this.isCreatingNewThread = true;
    this.renderPosts();

    try {
      const create_res = await dhisper_anon.kay4_create({
        thread: [],
        content: this.postContent,
        files: [],
        owners: [],
        metadata: [],
        authorization: { None: { subaccount: [] } },
      });
      this.isCreatingNewThread = false;
      if ('Err' in create_res) {
        alert(`Create post error: ${JSON.stringify(create_res.Err)}`);
      } else {
        const id = create_res.Ok;
        let content = '';
        let timestamp = '';
        await Promise.all([
          new Promise((resolve) => {(async () => {
            const contents = await dhisper_anon.kay4_contents_of([id]);
            content = contents[0].length > 0? contents[0][0] : "";
            resolve();
          })()}),
          new Promise((resolve) => {(async () => {
            const timestamps = await dhisper_anon.kay4_timestamps_of([id]);
            timestamp = timestamps[0].length > 0? new Date(Number(timestamps[0][0]) / 1000000) : null;
            resolve();
          })()}),
        ]);
        this.posts = [{ id, content, timestamp }];
        
        this.currentIndex = 0;
        this.isComposingNewThread = false;
        this.postContent = '';
        this.charCount = 0;
        this.assetType = 'None';
  
        this.startSlide(0, 'down');
      }
    } catch (e) {
      this.isCreatingNewThread = false;
    }
  }

  async getPosts() {
    let post_ids = [];
    if (this.posts.length > 0) {
      const last_post_id = this.posts[this.posts.length - 1].id;
      post_ids = await dhisper_anon.kay4_threads([last_post_id], []); 
    } else post_ids = await dhisper_anon.kay4_threads([], []);

    const posts = [];
    for (const id of post_ids) posts.push({ id });
    if (posts.length == 0) return;
    await Promise.all([
      new Promise((resolve) => {(async () => {
        const contents = await dhisper_anon.kay4_contents_of(post_ids);
        for (const i in contents) posts[i]['content'] = contents[i].length > 0? contents[i][0] : "";
        resolve();
      })()}),
      new Promise((resolve) => {(async () => {
        const timestamps = await dhisper_anon.kay4_timestamps_of(post_ids);
        for (const i in timestamps) posts[i]['timestamp'] = timestamps[i].length > 0? new Date(Number(timestamps[i][0]) / 1000000) : null;
        resolve();
      })()})
    ]);
    for (const post of posts) this.posts.push(post);
    this.renderPosts();
  }

  setupScrollHandler() {
    window.addEventListener('wheel', (e) => {
      if (this.isAnimating) return;
      if (this.isComposingNewThread) return;
      if (this.isCommentOpen) return;
      if (this.isCommentFormOpen) return;

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

    if (newIndex == this.posts.length - 1) this.getPosts();

    this.threadComments = [];
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

  handleCommentClick(post) {
    this.activeThread = post;
    this.isCommentOpen = true;
    this.renderPosts(); // re-render to show the comment UI
    this.getComments();
  }

  async getComments() {
    const thread_id = this.activeThread.id;
    const replies = [];
    let content_count = 0;
    let timestamp_count = 0;
    while (true) {
      const last = replies.length - 1;
      const prev = replies.length == 0? [] : [replies[last].id];
      const reply_ids = await dhisper_anon.kay4_replies_of(thread_id, prev, []);
      if (reply_ids.length == 0) break;
      for (const id of reply_ids) replies.push({ id });
      console.log({ replies });
      await Promise.all([
        new Promise((resolve) => {(async () => {
          const contents = await dhisper_anon.kay4_contents_of(reply_ids);
          for (const i in contents) {
            replies[content_count + +i]['content'] = contents[i].length > 0? contents[i][0] : "";
          };
          content_count += contents.length;
          resolve();
        })()}),
        new Promise((resolve) => {(async () => {
          const timestamps = await dhisper_anon.kay4_timestamps_of(reply_ids);
          for (const i in timestamps) {
            replies[timestamp_count + +i]['timestamp'] = timestamps[i].length > 0? new Date(Number(timestamps[i][0]) / 1000000) : null;
          };
          timestamp_count += timestamps.length;
          resolve();
        })()})
      ]);
    }
    this.threadComments = replies;
    this.renderPosts();
  }

  closeCommentForm() {
    const form = document.querySelector('.comment-form');
    if (form) {
      form.classList.remove('slide-up');
      form.classList.add('slide-down');
      setTimeout(() => {
        this.isCommentFormOpen = false;
        this.renderPosts();
      }, 400); // must match animation duration
    }
  }

  async handleCommentSend() {
    this.commentInput = !this.commentInput ? "" : this.commentInput.trim();
    if (this.commentInput.length === 0) return;

    const comment_res = await dhisper_anon.kay4_create({
      thread: [this.activeThread.id],
      content: this.commentInput,
      files: [],
      owners: [],
      metadata: [],
      authorization: { None: { subaccount: [] } },
    });
    if ('Err' in comment_res) {
      alert(`Send comment error: ${JSON.stringify(comment_res.Err)}`);
    } else {
      const id = comment_res.Ok;
      let content = '';
      let timestamp = '';
      await Promise.all([
        new Promise((resolve) => {(async () => {
          const contents = await dhisper_anon.kay4_contents_of([id]);
          content = contents[0].length > 0? contents[0][0] : "";
          resolve();
        })()}),
        new Promise((resolve) => {(async () => {
          const timestamps = await dhisper_anon.kay4_timestamps_of([id]);
          timestamp = timestamps[0].length > 0? new Date(Number(timestamps[0][0]) / 1000000) : null;
          resolve();
        })()}),
      ]);
      this.commentInput = "";
      this.commentCharCount = 0;
      this.isCommentFormOpen = false;
      this.threadComments.push({ id, content, timestamp });
      this.commentAssetType = 'None';
      this.renderPosts();
    }
  }

  createNewThread(e) {
    e.preventDefault();
    this.postContent = !this.postContent ? "" : this.postContent.trim();
    if (this.postContent.length === 0) {
      this.isCreatingNewThread = false;
      this.renderPosts();
      return;
    };
    this.isCreatingNewThread = true;
    this.renderPosts();
    if (dhisper_user == null || caller_principal == null) {
      return this.selectWallet(e);
    }
    // check for token approval
  }

  selectWallet(e) {
    e.preventDefault();
    this.isSelectingWallet = true;
    this.renderPosts();
  }

  async loginInternetIdentity(e) {
    e.preventDefault();
    this.isConnectingWallet = true;
    this.renderPosts();
    if (internet_identity == null) internet_identity = await AuthClient.create();
    internet_identity.login({
      // 7 days in nanoseconds
      maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000),
      identityProvider,
      onSuccess: async () => await this.handleAuthenticated(e),
    });
  }

  async handleAuthenticated(e) {
    const identity = await internet_identity.getIdentity();
    caller_principal = identity.getPrincipal();
    console.log({ identity, caller: caller_principal.toText() });

    // todo: get all tokens and generate their actors
    const create_fee_rates = convertTyped({ Map : await dhisper_anon.kay4_create_fee_rates() });

    const delete_fee_rates = convertTyped({ Map : await dhisper_anon.kay4_delete_fee_rates() });

    console.log({ create_fee_rates, delete_fee_rates });

    dhisper_user = genDhisper(dhisper_id, { agent: await HttpAgent.create({ identity }) });
    this.isSelectingWallet = false;
    this.isConnectingWallet = false;
    
    if (this.isCreatingNewThread) {
      this.createNewThread(e);
    };
  }

  renderPosts() {
    const currentPost = this.posts.length > 0? this.posts[this.currentIndex] : { content: 'Create the first post by clicking the "+" below!', timestamp: '' };
    const nextPost = this.nextIndex !== null ? this.posts[this.nextIndex] : null;

    const threads_pane = html`
      <div class="post-layer current ${this.direction === 'up' ? 'slide-out-up' : this.direction === 'down' ? 'slide-out-down' : ''}"
          style="background: ${this.background}">
        <div class="post-content-wrapper">
          <div class="text">${currentPost.content}</div>
          ${this.posts.length > 0? html`<div class="post-actions-right">
            <button class="comment-btn" @click=${() => this.handleCommentClick(currentPost)}>
              💬 ${currentPost.comment_count || 0}
            </button>
          </div>` : ''}
        </div>
      </div>
      ${nextPost !== null
        ? html`
            <div class="post-layer next ${this.direction === 'up' ? 'slide-in-up' : 'slide-in-down'}"
                style="background: ${this.nextBackground}">
              <div class="post-content-wrapper">
                <div class="text">${nextPost.content}</div>
                ${this.posts.length > 0? html`<div class="post-actions-right">
                  <button class="comment-btn" @click=${() => this.handleCommentClick(nextPost)}>
                    💬 ${nextPost.comment_count || 0}
                  </button>
                </div>` : ''}
              </div>
            </div>
          `
        : null}
    `;
    const create_new_thread_btn = html`<button class="create-post-btn" @click=${() => { 
      this.isComposingNewThread = true; 
      this.renderPosts();
    }}>+</button>`;
    const create_new_thread_form = html`
      ${this.isComposingNewThread
      ? html`<div class="backdrop" @click=${() => { 
          this.isComposingNewThread = false; 
          this.renderPosts(); 
        }}></div>`
      : null}
      <div class="compose-drawer ${this.isComposingNewThread ? 'open' : ''}">
        <div>Create New Thread</div>
        <form @submit=${(e) => this.createNewThread(e)}>
          <label class="field">
            <input type="text" placeholder="What's on your mind?" 
                  @input=${(e) => this.updateCharCount(e)} 
                  .value=${this.postContent || ''}
                  required />
            <span class="char-count ${this.charCount >= 256 ? 'limit' : ''}">
              ${this.charCount}/256
            </span>
          </label>

          <!-- 
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
          -->
            
          <button type="submit" class="send-btn" ?disabled=${this.isCreatingNewThread}>
            ${this.isCreatingNewThread
              ? html`<span class="spinner"></span> Sending...`
              : html`➤ Send`}
          </button>
        </form>
      </div>
    `;
    const wallet_selectors = html`
      ${this.isSelectingWallet
      ? html`<div class="wallet-backdrop" @click=${() => { 
          this.isSelectingWallet = false; 
          this.renderPosts(); 
        }}></div>`
      : null}
      <div class="wallet-drawer ${this.isSelectingWallet ? 'open' : ''}">
        <div>Connect your wallet</div>

        <button class="send-btn" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>
            ${this.isConnectingWallet
              ? html`<span class="spinner"></span> Connecting...`
              : html`Internet Identity`}
          </button>
      </div>
    `;
    const replies_pane = this.posts.length > 0 && this.isCommentOpen && this.activeThread
    ? html`
        <div class="comment-panel slide-in">
          <button class="close-btn" @click=${() => {
            const panel = document.querySelector('.comment-panel');
            if (panel) {
              panel.classList.remove('slide-in');
              panel.classList.add('slide-out');
              setTimeout(() => {
                this.isCommentOpen = false;
                this.activeThread = null;
                this.renderPosts();
              }, 500); // matches slideOut animation duration
              this.closeCommentForm();
            }
          }}>✕</button>
  
          <div class="comment-list">
            <div class="thread-post">
              <div class="meta">#${this.activeThread.id} • ${this.activeThread.timestamp ? timeAgo(this.activeThread.timestamp) : "Unknown time"}</div>
              <div class="content">${this.activeThread.content}</div>
            </div>
  
            ${this.threadComments.map(comment => html`
              <div class="comment">
                <div class="meta">#${comment.id} • ${comment.timestamp ? timeAgo(comment.timestamp) : "Unknown time"}</div>
                <div class="content">${comment.content}</div>
              </div>
            `)}
          </div>
  
          <button class="add-comment-btn" @click=${() => {
            this.isCommentFormOpen = true;
            this.renderPosts();
          }}>
            ➕ Add a Comment
          </button>
        </div>
      `
    : null;
    const add_reply_form = replies_pane && this.isCommentFormOpen
    ? html`
        <div
          class="comment-form-overlay"
          @click=${(e) => {
            if (e.target.classList.contains('comment-form-overlay')) {
              this.closeCommentForm();
            }
          }}
        >
          <div class="comment-form slide-up">
            <div class="form-row">
              <button class="comment-close-btn" @click=${() => this.closeCommentForm()}>✕</button>
              <input
                type="text"
                placeholder="Write your comment..."
                maxlength="256"
                .value=${this.commentInput}
                @input=${(e) => {
                  this.commentInput = e.target.value;
                  this.commentCharCount = e.target.value.length;
                  this.renderPosts();
                }}
              />
              <div class="char-count ${this.commentCharCount >= 256 ? 'limit' : ''}">
                ${this.commentCharCount}/256
              </div>
            </div>
    
            <div class="form-row">
              <select
                .value=${this.commentAssetType}
                @change=${(e) => {
                  this.commentAssetType = e.target.value;
                  this.renderPosts();
                }}
              >
                <option value="None">None</option>
                <option value="ICRC_1">ICRC_1</option>
                <option value="ICRC_2">ICRC_2</option>
              </select>
            </div>
    
            <div class="form-row">
              <input
                type="text"
                placeholder="Subaccount (hex, optional)"
                .value=${this.commentSubaccount}
                @input=${(e) => {
                  this.commentSubaccount = e.target.value;
                }}
              />
            </div>
    
            ${this.commentAssetType === 'ICRC_1'
              ? html`<div class="info-label">Your balance: 1.5 ICP, Token minimum: 1 ICP</div>`
              : this.commentAssetType === 'ICRC_2'
              ? html`
                  <div class="form-row">
                    <select
                      .value=${this.commentToken}
                      @change=${(e) => {
                        this.commentToken = e.target.value;
                      }}
                    >
                      <option value="ICP">Internet Computer (ICP)</option>
                      <option value="ckBTC">ckBTC (ckBTC)</option>
                    </select>
                  </div>
                  <div class="info-label">Fee: 0</div>
                `
              : null}
    
            <div class="form-row">
              <button class="send-btn" @click=${() => this.handleCommentSend()}>🚀 Send</button>
            </div>
          </div>
        </div>
      ` : null;

  //   const token_selectors = html`
  //   ${this.isSelectingToken
  //   ? html`<div class="token-backdrop" @click=${() => { 
  //       this.isSelectingToken = false; 
  //       this.renderPosts(); 
  //     }}></div>`
  //   : null}
  //   <div class="token-drawer ${this.isSelectingToken ? 'open' : ''}">
  //     <div>Select the token of your post</div>
      
  //     <button class="send-btn" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>
  //         ${this.isConnectingWallet
  //           ? html`<span class="spinner"></span> Sending...`
  //           : html`Pay & Send`}
  //       </button>
  //   </div>
  // `;
    const token_approve_form = html`
      ${this.isRequireApproval
      ? html`<div class="approve-backdrop" @click=${() => { 
          this.isRequireApproval = false; 
          this.renderPosts();
        }}></div>`
      : null}
      <div class="approve-drawer ${this.isRequireApproval ? 'open' : ''}">
        <div>Select your token approval:</div>
        
        <button class="send-btn" ?disabled=${this.isApproving} @click=${(e) => this.approveToken(e)}>
            ${this.isApproving
              ? html`<span class="spinner"></span> Approving...`
              : html`Confirm Approval`}
          </button>
      </div>
    `;
    render(html`
      <div class="post-wrapper">
        ${threads_pane}
        ${create_new_thread_btn}
        ${create_new_thread_form}

        ${replies_pane}
        ${add_reply_form}
        
        ${wallet_selectors}
        ${token_approve_form}
      </div>
    `, this.root);
  }
}

export default App;