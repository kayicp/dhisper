import { html, render } from 'lit-html';
import { dhisper_backend as dhisper_anon, createActor as genDhisper, canisterId as dhisper_id } from 'declarations/dhisper_backend';
import { createActor as genToken } from 'declarations/icp_token';
import { AuthClient } from "@dfinity/auth-client";
import { HttpAgent } from '@dfinity/agent';
import { Principal } from '@dfinity/principal';
import { AccountIdentifier } from '@dfinity/ledger-icp'

let internet_identity = null;
let caller_agent = null;
let caller_principal = null;
let caller_principal_copied = false;
let caller_principal_copy_failed = false;
let caller_account = '';
let caller_account_copied = false;
let caller_account_copy_failed = false;

const post_payment_pitches = [
  html`Most want to post. <strong>Few</strong> are willing to pay...<br><br>Are you like most?`,
  html`The 'Pay' button? It's a <strong>filter</strong>... <br><br>Most people never make it past this point.`,
  html`The fee is not a cost, it's a <strong>commitment</strong>...<br><br>Which most people lack.`,
  html`Only the <strong>bold</strong> will pay.`,
];

// jordan, don, appl, mboro
const post_input_pitches = [
  { header: "Got some words that'll stop the scroll?", body: "This is where the noise ends... and your influence begins.", placeholder: "Drop something they'll remember." },
  { header: "If it matters, put it in writing.", body: "What you say here could live longer than you.", placeholder: "Make it worth reading. Make it worth paying for." },
  { header: "Speak with intention.", body: "A post should be simple. Honest. Worth something.", placeholder: "Say less. Mean more." },
  { header: "Light one up.", body: "Every word should leave a mark. Make yours burn.", placeholder: "Write like you've got something to prove." },
];

const sign_in_pitches = [
  { header: "You're either in the room, or outside it.", body: "Sign in. Only members allowed past this point." },
  { header: "This is where things get real.", body: "If you're not signed in, you're just background noise."},
  { header: "Step in. Fully.", body: "Your voice deserves to be heard... by choice, not chance."},
  { header: "Be a real one.", body: "Posting here means showing up. Log in or log off."},
]; 

const top_up_pitches = [
  { header: "Top up. Lock in. Close the deal.", body: "This is pocket change for people who mean business." },
  { header: "If you want it to matter, it should cost something.", body: "Add funds... not just for access, but for meaning."},
  { header: "Just enough. Just right.", body: "Top up once. Let every post carry weight."},
  { header: "You want to post? Fuel it.", body: "No noise here... just the ones who show they mean it."},
]; 

const approval_pitches = [
  { header: "Approve once. Post like a machine.", body: "Set it and forget it... because time is the one thing you don't get back." },
  { header: "Approve future posts.", body: "You never know when the next important thing you'll say will come. Be ready."},
  { header: "Smarter posting starts now.", body: "Approve once. Create without friction."},
  { header: "Cut the delay. Light it faster.", body: "One approval. Many strikes. Keep the fire going."},
]; 

function randomPitch(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

let post_payment_pitch = randomPitch(post_payment_pitches);
let post_input_pitch = randomPitch(post_input_pitches);
let sign_in_pitch = randomPitch(sign_in_pitches);
let top_up_pitch = randomPitch(top_up_pitches);
let approval_pitch = randomPitch(approval_pitches);

let is_composing_post = false;
let is_seeing_cost = false;
let is_paying = false;

let create_fee_rates = null;
let delete_fee_rates = null;
let selected_create_fee_token_standard = null;
let selected_create_fee_token_canister = null;
let selected_create_fee_rate = null;
let selected_delete_fee_standard = null;
let selected_delete_token_canister = null;
let selected_delete_fee_rate = null;

let is_comments_open = false;
let is_posting = false;
let is_creating_new_post = false;
let is_waiting_balance = false;
let is_viewing_cost_details = false;
let is_checking_balance = false;
let is_waiting_approval = false;
let is_approving = false;
let token_id = null;

let post_content = "";
let char_count = 0;
let selected_approval_plan = 'ten';

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
let max_content_size = 256;
let extra_chars = 0;
let extra_cost = 0;

let popup_html = null;

const network = process.env.DFX_NETWORK;
const identityProvider =
  network === 'ic'
    ? 'https://identity.ic0.app' // Mainnet
    : 'http://rdmx6-jaaaa-aaaaa-aaadq-cai.localhost:5000'; // Local

BigInt.prototype.toJSON = function () {
  return this.toString();
};

function shortPrincipal(p) {
  let str = p.toText();
  let splitted = str.split('-');
  return `${splitted[0]}-...-${splitted[splitted.length - 1]}`;
}

function normalizeNumber(num) {
  if (typeof num !== 'number' || isNaN(num)) return String(num);

  // Check if the number is in scientific notation
  if (num.toString().includes('e') || num.toString().includes('E')) {
    // Convert from scientific notation to decimal string
    let [coefficient, exponent] = num.toExponential().split('e');
    let sign = num < 0 ? '-' : '';
    coefficient = coefficient.replace('.', '');
    let exp = parseInt(exponent, 10);

    if (exp < 0) {
      let zeros = '0.' + '0'.repeat(Math.abs(exp) - 1);
      return sign + zeros + coefficient;
    } else {
      let zeros = '0'.repeat(exp - (coefficient.length - 1));
      return sign + coefficient + zeros;
    }
  }

  // Not in scientific notation, return as string
  return num.toString();
}

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
      // we'll return a JS Map so non-string keys are allowed
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

/* brightest to darkest
To sort colors from brightest to darkest, we can approximate brightness using the perceived luminance formula:

Brightness=0.299×R+0.587×G+0.114×B
#fbb03b
#29abe2
#f15a24
#ed1e79
#522785
*/

/*
#3b00b9
#1e005d

#29abe2
#522785
#ed1e79

#f15a24
#fbb03b

#6A85F1
#C572EF

#C0D9FF
#F0B9E5

#0E031F
#281447
*/

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
  if (
    create_fee_rates == null
    // || delete_fee_rates == null
  ) {
    try {
      await Promise.all([
        new Promise((resolve, reject) => {(async () => {
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
        // new Promise((resolve) => {(async () => {
        //     delete_fee_rates = convertTyped({ Map : await dhisper_anon.kay4_delete_fee_rates() });
        //     const standards = Object.keys(delete_fee_rates);
        //     if (standards.length == 1) {
        //       selected_delete_fee_standard = standards[0];
        //     }
        //     const token_map = delete_fee_rates[selected_delete_fee_standard];
        //     if (token_map.size == 1) {
        //       const [token_canister_id] = token_map.keys();
        //       selected_delete_token_canister = token_canister_id;
        //       selected_delete_fee_rate = token_map.get(token_canister_id);
        //     };
        //     resolve();
        // })()}),
      ]);
      console.log({ 
        // create_fee_rates, 
        selected_create_fee_standard: selected_create_fee_token_standard, selected_create_token_canister : selected_create_fee_token_canister.toText(), selected_create_fee_rate, 
        // // delete_fee_rates, 
        // selected_delete_fee_standard, selected_delete_token_canister : selected_delete_token_canister.toText(), selected_delete_fee_rate 
      });
    } catch (err) {
      this.catchPopup("Error while Fetching Fee Rates", err);
      this.renderPosts();
    }
  };
}

class App {
  constructor() {
    this.posts = [];
    this.currentIndex = null;
    this.nextIndex = null;
    this.direction = null;
    this.isSliding = false;
    
    this.isSelectingWallet = false;
    this.isConnectingWallet = false;
    this.isSelectingToken = false;
    this.isRequireApproval = false;
    this.isApproving = false;
    
    this.root = document.getElementById('root');
    
    this.activeThread = null;
    this.threadComments = [];
    this.commentInput = "";

    this.setupScroll();
    this.renderPosts();
    this.getPosts();
  }

  updateCharCount(e) {
    post_content = e.target.value;
    char_count = post_content.length;
    this.renderPosts();
  }
  
  async getPosts() {
    let post_ids = [];
    try {
      if (this.posts.length > 0) {
        const last_post_id = this.posts[this.posts.length - 1].id;
        post_ids = await dhisper_anon.kay4_threads([last_post_id], []); 
      } else post_ids = await dhisper_anon.kay4_threads([], []);
    } catch (err) {
      this.showPopup("Error while Fetching Post IDs");
    }
    if (post_ids.length == 0) return this.renderPosts();
    const posts = [];
    for (const id of post_ids) posts.push({ id });
    try {
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
        })()}),
        ...post_ids.map((post_id, i) => {
          return new Promise((resolve) => {(async () => {
            const owners = await dhisper_anon.kay4_owners_of(post_id, [], [1]);
            posts[i]['owner'] = owners.length > 0? owners[0].ICRC_1.owner : Principal.anonymous();
            resolve();
          })()})
        }),
      ]);
      for (const post of posts) this.posts.push(post);
      if (this.currentIndex == null) this.startSlide(0, 'up');
    } catch (err) {
      this.catchPopup("Error while Building Posts", err);
    }
    this.renderPosts();
  }

  setupScroll() {
    // Mouse wheel (desktop)
    window.addEventListener('wheel', async (e) => {
      if (this.isSliding) return;
      if (is_composing_post) return;
      if (is_comments_open) return;
  
      if (e.deltaY > 0 && this.currentIndex < this.posts.length - 1) {
        this.startSlide(this.currentIndex + 1, 'up');
      } else if (e.deltaY < 0 && this.currentIndex > 0) {
        this.startSlide(this.currentIndex - 1, 'down');
      }
    });
  
    // Touch (mobile)
    let touchStartY = 0;
    let touchEndY = 0;
  
    window.addEventListener('touchstart', (e) => {
      touchStartY = e.changedTouches[0].clientY;
    });
  
    window.addEventListener('touchend', (e) => {
      if (this.isSliding) return;
      if (is_composing_post) return;
      if (is_comments_open) return;
  
      touchEndY = e.changedTouches[0].clientY;
      const deltaY = touchStartY - touchEndY;
  
      if (deltaY > 30 && this.currentIndex < this.posts.length - 1) {
        // Swipe up
        this.startSlide(this.currentIndex + 1, 'up');
      } else if (deltaY < -30 && this.currentIndex > 0) {
        // Swipe down
        this.startSlide(this.currentIndex - 1, 'down');
      }
    });
  }

  startSlide(newIndex, direction) {
    return new Promise((resolve) => {
      this.nextIndex = newIndex;
      this.direction = direction;

      this.threadComments = [];
      this.renderPosts();
      this.isSliding = true;

      setTimeout(() => {
        this.currentIndex = newIndex;
        this.nextIndex = null;
        this.direction = null;
        this.isSliding = false;
        if (newIndex == this.posts.length - 1) this.getPosts(); 
        this.renderPosts();
        resolve();
      }, 600);
    });
  }

  closeReplies(e) {
    e.preventDefault();
    const panel = document.querySelector('.comment-panel');
    if (panel) {
      panel.classList.remove('slide-in');
      panel.classList.add('slide-out');
      setTimeout(() => {
        is_comments_open = false;
        this.activeThread = null;
        this.renderPosts();
      }, 500); // matches slideOut animation duration
    }
  }

  openReplies(e) {
    e.preventDefault();
    is_comments_open = true;
    this.activeThread = this.posts[
      this.nextIndex == null? 
      this.currentIndex : this.nextIndex];
    
    if (this.activeThread) {
      this.renderPosts();
      this.getComments();
    }
  }

  async getComments() {
    const thread_id = this.activeThread.id;
    const replies = [];
    let content_count = 0;
    let timestamp_count = 0;
    let owner_count = 0;
    while (true) {
      const last = replies.length - 1;
      const prev = replies.length == 0? [] : [replies[last].id];
      try {
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
          })()}),
          ...reply_ids.map((reply_id, i) => {
            return new Promise((resolve) => {(async () => {
              const owners = await dhisper_anon.kay4_owners_of(reply_id, [], [1]);
              replies[owner_count + +i]['owner'] = owners.length > 0? owners[0].ICRC_1.owner : Principal.anonymous();
              resolve();
            })()})
          })
        ]);
        owner_count += reply_ids.length;
      } catch (err) {
        this.catchPopup("Error while Fetching Comments", err);
        return this.renderPosts();
      }
    }
    this.threadComments = replies;
    this.renderPosts();
  }

  async createNewPost(e) {
    e.preventDefault();
    post_content = !post_content ? "" : post_content.trim();
    if (post_content.length === 0) {
      is_posting = false;
      return this.renderPosts();
    };
    is_posting = true;
    this.renderPosts();
    if (caller_principal == null) {
      return this.selectWallet(e);
    }
    // check for token balance
    if (selected_create_fee_token_standard == null) {
      // return this.selectTokenStandard();
    };
    if (selected_create_fee_token_canister == null) {
      // return this.selectTokenCanister();
    };
    
    try {
      const token_anon = genToken(selected_create_fee_token_canister);
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
      is_checking_balance = true;
      this.renderPosts();
      token_id = selected_create_fee_token_canister;
      token_fee = Number(await token_fee_promise);
      base_cost = Number(selected_create_fee_rate.minimum_amount);
      max_content_size = Number(await max_content_size_promise);
      extra_chars = post_content.length > max_content_size? (post_content.length - max_content_size) : 0;
      extra_cost = extra_chars > 0? extra_chars * Number(selected_create_fee_rate.additional_amount_numerator) / Number(selected_create_fee_rate.additional_byte_denominator) : 0;
      // console.log({ extra_chars, extra_cost, max_content_size });
      token_name = await token_name_promise;
      token_symbol = await token_symbol_promise;
      token_power = 10 ** Number(await token_decimals_promise);
      token_balance = Number(await token_balance_promise);
      token_approval = await token_approval_promise;
      is_checking_balance = false;
  
      post_cost = base_cost + token_fee + extra_cost;
      token_approval_insufficient = token_approval.allowance < post_cost;
      token_approval_expired = token_approval.expires_at.length > 0 && token_approval.expires_at[0] < (BigInt(Date.now()) * BigInt(1000000));
      const require_approval = token_approval_insufficient || token_approval_expired;     
      
      const total_cost = require_approval? post_cost + token_fee : post_cost;
      token_total = { amount: total_cost, msg: `Total posting fee: ${normalizeNumber(Number(total_cost) / token_power)} ${token_symbol}` };
      token_details = [
        { amount: base_cost, msg: `Posting fee: ${normalizeNumber(Number(base_cost) / token_power)} ${token_symbol}`, submsg: `helps keep Dhisper spam-free and ad-free for you`},
        { amount: token_fee, msg: `Payment fee: ${normalizeNumber(Number(token_fee) / token_power)} ${token_symbol}`, submsg: `covers the small cost of transferring your token`},
        { amount: require_approval ? token_fee : BigInt(0), msg: `Payment Approval fee: ${normalizeNumber(Number(token_fee) / token_power)} ${token_symbol}`, submsg: `allows Dhisper to deduct the posting fee automatically for you`},
        { amount: extra_cost, msg: `Extra characters fee: ${normalizeNumber(Number(extra_cost) / token_power)} ${token_symbol}`, submsg: `You exceed ${max_content_size} characters; either trim it, or pay a little extra` },
      ];
      if (!is_seeing_cost) {
        is_seeing_cost = true;
        return this.renderPosts();
      }
      if (token_balance < total_cost) {
        is_waiting_balance = true;
        return this.renderPosts();
      };
      is_waiting_balance = false;
      if (require_approval) {
        is_waiting_approval = true;
        return this.renderPosts();
      } else is_seeing_cost = false;
  
      is_posting = true;
      is_creating_new_post = true;
      this.renderPosts();
      const dhisper_user = genDhisper(dhisper_id, { agent: caller_agent });
      const create_post_res = await dhisper_user.kay4_create({
        thread: this.activeThread ? [this.activeThread.id] : [],
        content: post_content,
        files: [],
        owners: [],
        metadata: [],
        authorization: { ICRC_2: {
          subaccount: [],
          canister_id: selected_create_fee_token_canister,
          fee: [BigInt(base_cost + extra_cost)]
        } }
      });
      is_creating_new_post = false;
      is_posting = false;
      is_paying = false;
      is_composing_post = 'Err' in create_post_res;
      if (is_composing_post) {
        this.errPopup("Create Post Error", create_post_res.Err);
      } else {
        // todo: track background process instead of this
        if (this.activeThread) {
          this.getComments();
        } else try {
            const id = create_post_res.Ok;
            let content = '';
            let timestamp = '';
            let owner = Principal.anonymous();
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
              new Promise((resolve) => {(async () => {
                const owners = await dhisper_anon.kay4_owners_of(id, [], [1]);
                owner = owners.length > 0? owners[0].ICRC_1.owner : Principal.anonymous();
                resolve();
              })()}),
            ]);
            const new_post = { id, content, timestamp, owner };
            if (this.currentIndex == null) this.posts = [new_post]; else {
              this.posts = [new_post, this.posts[this.currentIndex]];
              this.currentIndex = 1;
            };
            this.startSlide(0, 'down');
            this.posts = [new_post];
            this.currentIndex = 0;
        } catch (err) {
          this.catchPopup("Error while Fetching Created Post", err);
        }
        post_content = '';
        char_count = 0;
      }
    } catch (err) {
      this.catchPopup("Error while Create Post", err);
      if (is_posting) {
        if (is_checking_balance) {
          is_checking_balance = false;
        } else if (is_paying) {
          is_paying = false;
        } else is_posting = false; 
      }
    }
    this.renderPosts();
  }

  errPopup(title, err) {
    for (const err_key in err) {
      subtitle = JSON.stringify(err[err_key], null, 2);
      return this.showPopup(err_key, subtitle)
    }
    this.showPopup(title);
    console.error(title, err);
  }

  catchPopup(title, e) {
    if (e instanceof Error) {
      this.showPopup(e.name, e.message);
    } else {
      this.showPopup(title);
      console.error(title, e);
    }
  }

  showPopup(title = 'Error', subtitle = 'Check console', buttons = [{ 
    label: 'Close', 
    click: (e) => {
      e.preventDefault();
      const popup_exist = document.querySelector('.popup');
      if (popup_exist) {
        popup_exist.classList.remove('in');
        popup_exist.classList.add('out');
        setTimeout(() => {
          popup_html = null;
          this.renderPosts();
        }, 300);
      }
    }}]) {
    popup_html = html`<p>
      <strong>${title}</strong><br>
      <small>${subtitle}</small>
    </p>
    ${buttons.map(v => html`<button class="action-btn compact" @click=${v.click}>${v.label}</button>`)}`;
  }

  viewTokenDetails(e) {
    e.preventDefault();
    is_viewing_cost_details = true;
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
    if (internet_identity == null) try {
      internet_identity = await AuthClient.create();
    } catch (err) {
      this.isConnectingWallet = false;
      this.catchPopup("Error while Creating Auth Client", err);
      return this.renderPosts();
    };
    internet_identity.login({
      // 7 days in nanoseconds
      maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000),
      identityProvider,
      onSuccess: async () => await this.handleAuthenticated(e),
    });
  }

  async handleAuthenticated(e) {
    try {
      const identity = await internet_identity.getIdentity();
      caller_agent = await HttpAgent.create({ identity });
      // if (network !== 'ic') await caller_agent.fetchRootKey();
      caller_principal = identity.getPrincipal();
      caller_account = AccountIdentifier.fromPrincipal({ principal: caller_principal }).toHex();
      // console.log({ identity, caller: caller_principal.toText(), caller_account });
      await prepareTokens();
      if (is_posting) {
        this.createNewPost(e);
      };
    } catch (err) {
      this.catchPopup("Error after Authentication", err);
    }
    this.isSelectingWallet = false;
    this.isConnectingWallet = false;
    this.renderPosts();
  }

  async approveToken(e) {
    e.preventDefault();
    is_approving = true;
    this.renderPosts();
    try {
      const token_user = genToken(selected_create_fee_token_canister, { agent: caller_agent });
      const approve_res = await token_user.icrc2_approve({
        from_subaccount: [],
        amount: BigInt(post_cost * (selected_approval_plan == 'ten' ? 10 : selected_approval_plan == 'hundred' ? 100 : 1)),
        spender : { owner : Principal.fromText(dhisper_id), subaccount : [] },
        expected_allowance: [],
        expires_at: [],
        fee: [token_fee],
        memo: [],
        created_at_time: [],
      });
      is_approving = false;
      if ('Err' in approve_res) {
        const err_obj = approve_res.Err;
        console.error('approve err', err_obj);
        let title, subtitle;
        for (const err_key in err_obj) {
          title = err_key;
          subtitle = JSON.stringify(err_obj[err_key]);
          break;
        }
        this.showPopup(title, subtitle);
      } else is_waiting_approval = false;
      if (is_posting) {
        this.createNewPost(e);
      }; 
    } catch (err) {
      is_approving = false;
      this.catchPopup("Error while Approving Payment", err);
    }
    this.renderPosts();
  }
  // todo: add logo

  closeCompose(e) {
    e.preventDefault();
    if (is_posting) return;
    is_composing_post = false;
    is_seeing_cost = false;
    is_paying = false;
    this.renderPosts(); 
  }

  closePayment(e) {
    e.preventDefault();
    if (is_paying) return;
    is_seeing_cost = false;
    is_posting = false;
    this.renderPosts(); 
  };

  closeLogin(e) {
    e.preventDefault();
    this.isSelectingWallet = false; 
    this.isConnectingWallet = false;
    is_posting = false;
    this.renderPosts(); 
  }

  closeBalanceWaiter(e) {
    e.preventDefault();
    if (is_checking_balance) return;
    is_waiting_balance = false;
    is_paying = false;
    this.renderPosts(); 
  }

  closeApprovalWaiter(e) {
    e.preventDefault();
    if (is_approving) return;
    is_waiting_approval = false;
    is_paying = false;
    this.renderPosts();
  }

  closeCostDetails(e) {
    e.preventDefault();
    is_viewing_cost_details = false; 
    this.renderPosts(); 
  }

  // todo: optimistic rendering
  renderPosts() {
    if (this.isSliding) return;
    let current_post;
    if (this.currentIndex == null) {
      current_post = html`<div class="post-content-wrapper">
        <span class="spinner"></span>
        <div class="subtext">Loading</div>
      </div>`;
    } else {
      const currentPost = this.posts[this.currentIndex];
      current_post = html`<div class="post-content-wrapper">
        <div class="text">${currentPost?.content ?? ''}</div>
        <div class="subtext">${currentPost? shortPrincipal(currentPost.owner) : ''}<br>${currentPost ? timeAgo(currentPost.timestamp) : ''}</div>
      </div>`;
    }
    let next_post;
    if (this.nextIndex == null) next_post = null; else {
      const nextPost = this.posts[this.nextIndex];
      console.log({ nextPost });
      next_post = nextPost ? html`<div class="post-content-wrapper">
        <div class="text">${nextPost.content}</div>
        <div class="subtext">${shortPrincipal(nextPost.owner)}<br>${timeAgo(nextPost.timestamp)}</div>
      </div>` : null;
    }
    
    const threads_pane = html`<div class="post-layer current ${this.direction === 'up' ? 'slide-out-up' : this.direction === 'down' ? 'slide-out-down' : ''}">${current_post}</div>
      ${next_post !== null? html`<div class="post-layer next ${this.direction === 'up' ? 'slide-in-up' : 'slide-in-down'}">${next_post}</div>` : null}
    `;
    const replies_pane = this.posts.length > 0 && is_comments_open && this.activeThread
    ? html`
        <div class="comment-panel slide-in">
          <div class="comment-list">
            <div class="action-size"></div>
            <div class="comment">
              <div class="meta">#${this.activeThread.id} • ${shortPrincipal(this.activeThread.owner)}${this.activeThread.timestamp ? ' • ' + timeAgo(this.activeThread.timestamp) : ''}</div>
              <div class="content">${this.activeThread.content}</div>
            </div>
            ${this.threadComments.map(comment => html`
              <div class="comment">
                <div class="meta">#${comment.id} • ${shortPrincipal(comment.owner)}${comment.timestamp ? ` • ${timeAgo(comment.timestamp)}` : ''}</div>
                <div class="content">${comment.content}</div>
              </div>
            `)}
            <div class="action-size"></div>
          </div>
          <div class="action-bar sticky">
            <button class="action-btn" @click=${(e) => this.closeReplies(e)}>Close</button>
            <button class="action-btn" @click=${() => { 
              is_composing_post = true; 
              post_input_pitch = randomPitch(post_input_pitches);
              this.renderPosts();
            }}>Add Reply</button>
          </div>
        </div>
      ` : null;
      // todo: fix the small text since we've using 1.25 rem
      // todo: reduce to 1rem on default text
    const create_new_post_form = html`
      ${is_composing_post
      ? html`<div class="compose-backdrop" @click=${(e) => this.closeCompose(e)}></div>` : null}
      <div class="drawer compose ${is_composing_post ? 'open' : ''}">
        <p>
          <strong>${post_input_pitch.header}</strong><br>
          <small><small>${post_input_pitch.body}</small></small>
          <br><br>
          <input type="text" placeholder="${post_input_pitch.placeholder}"
              @input=${(e) => this.updateCharCount(e)} 
              .value=${post_content || ''}/>
          <span class="char-count">${char_count}</span>
        </p>
        <div class="action-bar">
          <button class="action-btn" ?disabled=${is_posting} @click=${(e) => this.closeCompose(e)}>Close</button>
          <button class="action-btn success" ?disabled=${is_posting} @click=${(e) => {
            post_payment_pitch = randomPitch(post_payment_pitches);
            sign_in_pitch = randomPitch(sign_in_pitches);
            top_up_pitch = randomPitch(top_up_pitches);
            approval_pitch = randomPitch(approval_pitches);
            this.createNewPost(e);
          }}>${is_posting
            ? html`<span class="spinner"></span> Posting...`
            : html`➤ Post`}</button>
        </div>
      </div>
    `;
    const wallet_selectors = html`
      ${this.isSelectingWallet
      ? html`<div class="wallet-backdrop" @click=${(e) => this.closeLogin(e)}></div>`
      : null}
      <div class="drawer wallet ${this.isSelectingWallet ? 'open' : ''}">
        <p>
          <strong>${sign_in_pitch.header}</strong><br>
          <small><small>${sign_in_pitch.body}</small></small>
        </p>
        <div class="action-bar">
          <button class="action-btn" @click=${(e) => this.closeLogin(e)}>Close</button>
          <button class="action-btn success" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>${this.isConnectingWallet
            ? html`<span class="spinner"></span> Connecting...`
            : html`Connect via Internet Identity`}</button>
        </div>
      </div>
    `;

  //   const token_selectors = html`
  //   ${this.isSelectingToken
  //   ? html`<div class="token-backdrop" @click=${() => { 
  //       this.isSelectingToken = false; 
  //       this.renderPosts(); 
  //     }}></div>`
  //   : null}
  //   <div class="drawer token ${this.isSelectingToken ? 'open' : ''}">
  //     <div>Select the token of your post</div>
      
  //     <button class="send-btn" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>
  //         ${this.isConnectingWallet
  //           ? html`<span class="spinner"></span> Sending...`
  //           : html`Pay & Send`}
  //       </button>
  //   </div>
  // `;
      const cost_and_reasons = html`
      ${is_seeing_cost
      ? html`<div class="cost-backdrop" @click=${(e) => this.closePayment(e)}></div>`
      : null}
      <div class="drawer cost ${is_seeing_cost ? 'open' : ''}">
        <p>
          <strong>${token_total.msg}</strong>
          <button class="action-btn compact" @click=${(e) => this.viewTokenDetails(e)}>Show fee details</button>
          <br><br>
          <small>${post_payment_pitch}</small>
        </p>
        <div class="action-bar">
          <button class="action-btn" ?disabled=${is_paying} @click=${(e) => this.closePayment(e)}>Close</button>
          <button class="action-btn success" ?disabled=${is_paying} @click=${(e) => {
            is_paying = true;
            this.createNewPost(e);
          }}>${is_paying ? html`<span class="spinner"></span> Paying...` : html`Pay`}</button>
        </div>
      </div>
    `;
    const token_balance_waiter_details = html`
    ${is_viewing_cost_details
    ? html`<div class="cost-breakdown-backdrop" @click=${(e) => this.closeCostDetails(e)}></div>`
    : null}
    <div class="drawer cost-breakdown ${is_viewing_cost_details ? 'open' : ''}">
      <p>
      <strong>Fee Details</strong>
      <br>
      <br>
      ${token_details.map(detail => {
        return detail.amount > 0? html` + <strong>${detail.msg}</strong><br>
        <small><small>${detail.submsg}</small></small>
        <br><br>` : null
      })} = <strong>${token_total.msg}</strong>
      </p>
      <div class="action-bar">
        <button class="action-btn" @click=${(e) => this.closeCostDetails(e)}>Close</button>
      </div>
    </div>
  `;
    const token_balance_waiter = html`${is_waiting_balance
    ? html`<div class="balance-backdrop" @click=${(e) => this.closeBalanceWaiter(e)}></div>`
    : null}
    <div class="drawer balance ${is_waiting_balance ? 'open' : ''}">
      <p>
        <strong>${top_up_pitch.header}</strong><br>
        <small><small>${top_up_pitch.body}</small></small>
        <br><br><small>${token_total.msg}</small>
        <br><small>Your balance: ${is_checking_balance ? html`<span class="spinner"></span>` : normalizeNumber(token_balance / token_power)} ${token_symbol}</small>
        <br>
        <br>You need to <strong>send ${is_checking_balance ? html`<span class="spinner"></span>` : normalizeNumber((token_total.amount - token_balance) / token_power)} ${token_symbol}</strong> to one of your ${token_symbol} addresses below:<br>
        <br><strong>• Principal</strong>: <button class="action-btn ${caller_principal_copied ? "success" : caller_principal_copy_failed ? 'failed' : ''} compact" @click=${async (e) => { 
          e.preventDefault();
          try {
            await navigator.clipboard.writeText(caller_principal.toText());
            caller_principal_copied = true;
          } catch (err) {
            console.error('copy principal', err);
            const to_copy = document.getElementById("caller_principal_text");
            to_copy.value = caller_principal.toText();
            to_copy.select();
            if (document.execCommand('copy')) {
              caller_principal_copied = true;
            } else caller_principal_copy_failed = true;
            // to_copy.setSelectionRange(0, 0);
            to_copy.value = '';
          }        
          this.renderPosts(); 
          setTimeout(() => {
            caller_principal_copied = false;
            this.renderPosts();
          }, 2000);
        }}>${caller_principal_copied ? 'Copied' : caller_principal_copy_failed ? 'Failed' : 'Copy'}</button>
        <br>
        <small><small><code>${caller_principal? caller_principal.toText() : ''}</code></small></small>
        <textarea id="caller_principal_text" class="copy-only"></textarea>
        <br><br><strong>• Account</strong>: <button class="action-btn ${caller_account_copied ? "success" : caller_account_copy_failed? 'failed' : ''} compact" @click=${async (e) => { 
          e.preventDefault();
          try {
            await navigator.clipboard.writeText(caller_account);
            caller_account_copied = true;
          } catch (err) {
            console.error('copy account', err);
            const to_copy = document.getElementById("caller_account_text");
            to_copy.value = caller_account;
            to_copy.select();
            if (document.execCommand('copy')) {
              caller_account_copied = true;
            } else caller_account_copy_failed = true;
            // to_copy.setSelectionRange(0, 0);
            to_copy.value = '';
          }        
          this.renderPosts(); 
          setTimeout(() => {
            caller_account_copied = false;
            caller_account_copy_failed = false;
            this.renderPosts();
          }, 2000);
        }}>${caller_account_copied ? 'Copied' : caller_account_copy_failed ? 'Failed' : 'Copy'}</button>
        <br><small><small><code>${caller_account}</code></small></small>
        <textarea id="caller_account_text" class="copy-only"></textarea>
        <br>
        <br><small><small>After you've topped up, let us know.</small></small>
      </p>
      <div class="action-bar">
        <button class="action-btn" ?disabled=${is_checking_balance} @click=${(e) => this.closeBalanceWaiter(e)}>Close</button>
        <button class="action-btn success" ?disabled=${is_checking_balance} @click=${(e) => this.createNewPost(e)}>
          ${is_checking_balance
            ? html`<span class="spinner"></span> Checking...`
            : html`I have sent`}
        </button>
      </div>
    </div>
`;
  const token_approve_form = html`
      ${is_waiting_approval
      ? html`<div class="approve-backdrop" @click=${(e) => this.closeApprovalWaiter(e)}></div>`
      : null}
      <div class="drawer approve ${is_waiting_approval ? 'open' : ''}">
        <p>
          <strong>${approval_pitch.header}</strong><br>
          <small><small>Save time and cut down on ${token_symbol} approval fees.</small></small><br>
          <br>
          <small><strong>Choose</strong> how many future posts to include in this one-time approval:</small>
        </p>
        <div class="radio-option">
          <input type="radio" id="approval1" name="approval" ?checked=${selected_approval_plan == 'one'} ?disabled=${selected_approval_plan != 'one' && is_approving} @change=${() => {
            const radio = document.getElementById("approval1");
            if (radio.checked) selected_approval_plan = 'one';
            this.renderPosts();
          }}>
          <label for="approval1">
            <small><strong>Just this post</strong></small><br>
            <small><small>You'll need to approve again next time. Good if you rarely post.</small></small>
          </label>
        </div>
        <div class="radio-option">
          <input type="radio" id="approval2" name="approval" ?checked=${selected_approval_plan == 'ten'} ?disabled=${selected_approval_plan != 'ten' && is_approving} @change=${() => {
            const radio = document.getElementById("approval2");
            if (radio.checked) selected_approval_plan = 'ten';
            this.renderPosts();
          }}>
          <label for="approval2">
            <small><strong>10 posts</strong></small><br>
            <small><small>Skip approval steps and save fees for your next 9 posts. <strong>Recommended.</strong></small></small>
          </label>
        </div>
        <div class="radio-option">
          <input type="radio" id="approval3" name="approval" ?checked=${selected_approval_plan == 'hundred'} ?disabled=${selected_approval_plan != 'hundred' && is_approving} @change=${() => {
            const radio = document.getElementById("approval3");
            if (radio.checked) selected_approval_plan = 'hundred';
            this.renderPosts();
          }}>
          <label for="approval3">
            <small><strong>100 posts</strong></small><br>
            <small><small>Enjoy a smoother, faster experience for the long run. <strong>Best for active posters.</strong></small></small>
          </label>
        </div>
        <br>
        <div class="action-bar">
          <button class="action-btn" ?disabled=${is_approving} @click=${(e) => this.closeApprovalWaiter(e)}>Close</button>
          <button class="action-btn success" ?disabled=${is_approving} @click=${(e) => this.approveToken(e)}>
            ${is_approving
              ? html`<span class="spinner"></span> Approving...`
              : html`Approve`}
          </button>
        </div>
      </div>
    `;
  const popup = popup_html ? html`
    <div class="popup-backdrop"></div>
    <div class="popup in">${popup_html}</div>
  ` : null;

    render(html`
    <header class="logo-bar">
      <img src="dhisper_logo.svg" alt="Dhisper Logo"/>
    </header>
    ${threads_pane}
    <div class="action-bar thread">
      <!--<button class="action-btn" disabled>Refresh</button>-->
      <button class="action-btn" @click=${() => { 
        is_composing_post = true;
        post_input_pitch = randomPitch(post_input_pitches);
        this.renderPosts();
      }}>New Thread</button>
      <button class="action-btn" @click=${(e) => this.openReplies(e)}>Open Replies</button>
    </div>
    ${replies_pane}
    ${create_new_post_form}        
    ${wallet_selectors}
    ${cost_and_reasons}
    ${token_balance_waiter}
    ${token_balance_waiter_details}
    ${token_approve_form}
    ${popup}
    `, this.root);
  }
}

export default App;