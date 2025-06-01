import { html, render } from 'lit-html';
import { dhisper_backend as dhisper_anon, createActor as genDhisper, canisterId as dhisper_id } from 'declarations/dhisper_backend';
import { createActor as genToken } from 'declarations/icp_token';
import { AuthClient } from "@dfinity/auth-client";
import { HttpAgent } from '@dfinity/agent';
import { Principal } from '@dfinity/principal';
import { AccountIdentifier } from '@dfinity/ledger-icp'

let internet_identity = null;
let caller_principal = null;
let caller_principal_copied = false;
let caller_principal_copy_failed = false;
let caller_account = '';
let caller_account_copied = false;
let caller_account_copy_failed = false;

let dhisper_user = null;
let token_anon = null;
let token_user = null;

let create_fee_rates = null;
let delete_fee_rates = null;
let selected_create_fee_token_standard = null;
let selected_create_fee_token_canister = null;
let selected_create_fee_rate = null;
let selected_delete_fee_standard = null;
let selected_delete_token_canister = null;
let selected_delete_fee_rate = null;

let is_waiting_balance = false;
let is_viewing_token_details = false;
let is_waiting_approval = false;
let token_id = null;

let token_balance = 0;
let token_name = "";
let token_symbol = "";
let token_fee = 0;
let token_power = 0;
let token_total = { amount: 0, msg: ''};
let token_details = [];
let token_approval = null;
let token_approval_insufficient = true;
let token_approval_expired = true;
let token_approval_total = null;

let post_cost = 0;
let base_cost = 0;
let max_content_size = 0;
let extra_chars = 0;
let extra_cost = 0;

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
      // return Number(payload);
      return payload;
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

async function prepareTokens() {
  // todo: get all tokens and generate their actors
  if (create_fee_rates == null || delete_fee_rates == null) {
    await Promise.all([
      new Promise((resolve) => {(async () => {
        create_fee_rates = convertTyped({ Map : await dhisper_anon.kay4_create_fee_rates() });
        const standards = Object.keys(create_fee_rates);
        if (standards.length == 1) {
          selected_create_fee_token_standard = standards[0];
        }
        const token_map = create_fee_rates[selected_create_fee_token_standard];
        if (token_map.size == 1) {
          const [token_canister_id] = token_map.keys();
          selected_create_fee_token_canister = token_canister_id;
          selected_create_fee_rate = token_map.get(token_canister_id);
        };
        resolve();
      })()}),
      new Promise((resolve) => {(async () => {
        delete_fee_rates = convertTyped({ Map : await dhisper_anon.kay4_delete_fee_rates() });
        const standards = Object.keys(delete_fee_rates);
        if (standards.length == 1) {
          selected_delete_fee_standard = standards[0];
        }
        const token_map = delete_fee_rates[selected_delete_fee_standard];
        if (token_map.size == 1) {
          const [token_canister_id] = token_map.keys();
          selected_delete_token_canister = token_canister_id;
          selected_delete_fee_rate = token_map.get(token_canister_id);
        };
        resolve();
      })()}),
    ]);
  };
  console.log({ 
    // create_fee_rates, 
    selected_create_fee_standard: selected_create_fee_token_standard, selected_create_token_canister : selected_create_fee_token_canister.toText(), selected_create_fee_rate, 
    // delete_fee_rates, 
    selected_delete_fee_standard, selected_delete_token_canister : selected_delete_token_canister.toText(), selected_delete_fee_rate });
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

  async createNewThread(e) {
    e.preventDefault();
    this.postContent = !this.postContent ? "" : this.postContent.trim();
    if (this.postContent.length === 0) {
      this.isCreatingNewThread = false;
      return this.renderPosts();
    };
    this.isCreatingNewThread = true;
    this.renderPosts();
    if (dhisper_user == null || caller_principal == null) {
      return this.selectWallet(e);
    }
    // check for token balance
    if (selected_create_fee_token_standard == null) {
      // return this.selectTokenStandard();
    };
    if (selected_create_fee_token_canister == null) {
      // return this.selectTokenCanister();
    };
    token_anon = genToken(selected_create_fee_token_canister);
    const token_fee_promise = token_anon.icrc1_fee();
    const token_name_promise = token_anon.icrc1_name();
    const token_symbol_promise = token_anon.icrc1_symbol();
    const token_decimals_promise = token_anon.icrc1_decimals();
    const max_content_size_promise = dhisper_anon.kay4_max_content_size();
    const token_balance_promise = token_anon.icrc1_balance_of({ owner : caller_principal, subaccount : [] });
    const token_approval_promise = token_anon.icrc2_allowance({
      spender : { owner : Principal.fromText(dhisper_id), subaccount : [] },
      account : { owner : caller_principal, subaccount : [] }
    });

    token_id = selected_create_fee_token_canister;
    token_fee = Number(await token_fee_promise);
    base_cost = Number(selected_create_fee_rate.minimum_amount);
    max_content_size = Number(await max_content_size_promise);
    extra_chars = this.postContent.length > max_content_size? (this.postContent.length - max_content_size) : 0;
    extra_cost = extra_chars > 0? extra_chars * Number(selected_create_fee_rate.additional_amount_numerator) / Number(selected_create_fee_rate.additional_byte_denominator) : 0;
    console.log({ extra_chars, extra_cost, max_content_size });
    token_name = await token_name_promise;
    token_symbol = await token_symbol_promise;
    token_power = 10 ** Number(await token_decimals_promise);
    token_balance = Number(await token_balance_promise);
    token_approval = await token_approval_promise;

    post_cost = base_cost + token_fee + extra_cost;
    token_approval_insufficient = token_approval.allowance < post_cost; 
    token_approval_expired = token_approval.expires_at.length > 0 && token_approval.expires_at[0] < (BigInt(Date.now()) * BigInt(1000000));
    const require_approval = token_approval_insufficient || token_approval_expired;     
    
    const total_cost = require_approval? post_cost + token_fee : post_cost;
    if (token_balance < total_cost) {
      token_total = { amount: total_cost, msg: `Total cost to post: ${Number(total_cost) / token_power} ${token_symbol}` };
      token_details = [
        { amount: base_cost, msg: `Post creation fee: ${Number(base_cost) / token_power} ${token_symbol}`, submsg: `helps keep Dhisper spam-free & running smoothly`},
        { amount: token_fee, msg: `Transfer fee: ${Number(token_fee) / token_power} ${token_symbol}`, submsg: `covers the fee to send ${token_symbol} tokens`},
        { amount: extra_cost, msg: `Extra characters fee: ${Number(extra_cost) / token_power} ${token_symbol}`, submsg: `you exceeded the ${max_content_size}-character limit; try trimming your text` },
        { amount: require_approval ? token_fee : BigInt(0), msg: `Approval fee: ${Number(token_fee) / token_power} ${token_symbol}`, submsg: `covers the fee to approve Dhisper to spend your ${token_symbol} tokens`}
      ];
      is_waiting_balance = true;
      return this.renderPosts();
    };
    if (require_approval) {
      token_approval_total = { amount : post_cost, msg: `Approve Dhisper to spend ${Number(post_cost) / token_power} ${token_symbol}` }
      is_waiting_approval = true;
      return this.renderPosts();
    }
    // call the create_post endpoint now that we have enough balance & approval

    this.isCreatingNewThread = false;
    return this.renderPosts();
  }

  viewTokenDetails(e) {
    e.preventDefault();
    is_viewing_token_details = true;
    this.renderPosts();
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
    caller_account = AccountIdentifier.fromPrincipal({ principal: caller_principal }).toHex();
    console.log({ identity, caller: caller_principal.toText(), caller_account });

    await prepareTokens();

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
    const token_balance_waiter = html`${is_waiting_balance
    ? html`<div class="balance-backdrop" @click=${() => { 
        is_waiting_balance = false; 
        this.renderPosts(); 
      }}></div>`
    : null}
    <div class="balance-drawer ${is_waiting_balance ? 'open' : ''}">
      <div>Not enough ${token_symbol} in your wallet</div>
      <p>${token_total.msg}</p>
      <button class="send-btn" @click=${(e) => this.viewTokenDetails(e)}>View details</button>
      <p>Send ${(token_total.amount - token_balance) / token_power} ${token_symbol} to your ... </p>
      <span><label>Principal: </label><button class="copy-btn ${caller_principal_copied ? "copied" : caller_principal_copy_failed ? 'copy-failed' : ''}" @click=${async (e) => { 
        e.preventDefault();
        try {
          await navigator.clipboard.writeText(caller_principal.toText());
          caller_principal_copied = true;
        } catch (e) {
          console.error('copy principal', e);
          const to_copy = document.getElementById("caller_principal_text");
          to_copy.select();
          if (document.execCommand('copy')) {
            caller_principal_copied = true;
          } else caller_principal_copy_failed = true;
          to_copy.setSelectionRange(0, 0);
        }        
        this.renderPosts(); 
        setTimeout(() => {
          caller_principal_copied = false;
          this.renderPosts();
        }, 2000);
      }}>${caller_principal_copied ? 'Copied' : caller_principal_copy_failed ? 'Failed' : 'Copy'}</button></span>
      <pre>${caller_principal? caller_principal.toText() : ''}</pre>
      <textarea id="caller_principal_text" class="copy-only">${caller_principal? caller_principal.toText() : ''}</textarea>
      <span><label>or Account: </label><button class="copy-btn ${caller_account_copied ? "copied" : caller_account_copy_failed? 'copy-failed' : ''}" @click=${async (e) => { 
        e.preventDefault();
        try {
          await navigator.clipboard.writeText(caller_account);
          caller_account_copied = true;
        } catch (e) {
          console.error('copy account', e);
          const to_copy = document.getElementById("caller_account_text");
          to_copy.select();
          if (document.execCommand('copy')) {
            caller_account_copied = true;
          } else caller_account_copy_failed = true;
          to_copy.setSelectionRange(0, 0);
        }        
        this.renderPosts(); 
        setTimeout(() => {
          caller_account_copied = false;
          caller_account_copy_failed = false;
          this.renderPosts();
        }, 2000);
      }}>${caller_account_copied ? 'Copied' : caller_account_copy_failed ? 'Failed' : 'Copy'}</button></span>
      <pre>${caller_account}</pre>
      <textarea id="caller_account_text" class="copy-only">${caller_account}</textarea>
      
    </div>
`;
    const token_balance_waiter_details = html`
    ${is_viewing_token_details
    ? html`<div class="cost-breakdown-backdrop" @click=${() => { 
        is_viewing_token_details = false; 
        this.renderPosts(); 
      }}></div>`
    : null}
    <div class="cost-breakdown-drawer ${is_viewing_token_details ? 'open' : ''}">
      ${token_details.map((detail, detail_index) => {
          return detail.amount > 0? html`
          <label> + ${detail.msg}</label>
          <pre>${detail.submsg}</pre>` : null
        })}
      <label> = ${token_total.msg}</label>
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
        ${token_balance_waiter}
        ${token_balance_waiter_details}
        ${token_approve_form}
      </div>
    `, this.root);
  }
}

export default App;