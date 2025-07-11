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

/*
newplan:
- anon free: reply only, 16 chars limit, 8 minutes cooldown, untippable, cannot delete other posts, wont bump thread
- user free: same as anon free, but 64 chars limit, 2 minutes cooldown.
- user paid: thread/reply, 256 chars limit, no cooldown, tippable, thread owner able to delete free posts (won't remove the owner detail), bumps thread

todo: new payment plan - redo canister metadata (sort the key)
todo: add Free button
todo: add cooldown timer
todo: change gradient 
todo: start 2x3 keypad, each button will open their own pane (balance, approval, etc.) 
todo: put thread details in comment panel
todo: replace css animation with css transition
todo: replace input with textarea
todo: whitespace cleaner
todo: long text cut-off with "..."
todo: optimistic rendering
todo: cache threads/replies 
todo: tipping button, tipping form, tipped view
todo: report button, report form, reported view
todo: appeal button, appeal form, appealed view
todo: combine post+pay popup?
todo: load comments on slide
todo: fix normal button's gloss
todo: fix radio button disabled css
todo: sunglasses (dark mode)
todo: ambience music
todo: buttons sound
todo: snap scroll
*/

const post_payment_pitches = [
  html`Value your words.`,
  html`Bots post for free. We don't.`,
  html`Reach everyone. No followers needed.`,
  html`Claim your space.`,
  html`Cut the noise. Keep the signal.`,
  html`Leave your mark.`,
];

const thread_input_pitches = [
  { header: "", body: "If it matters, put it in writing.", placeholder: "Drop something they'll remember." },
  { header: "", body: "Say something worth reading.", placeholder: "Got some words that'll stop the scroll?" },
  { header: "", body: "Broadcast to everyone.", placeholder: "What should they read about?" },
];

const reply_input_pitches = [
  { header: "", body: "Revive the thread.", placeholder: "What do you have to say?" },
  { header: "", body: "Push the thread further.", placeholder: "Keep it going..." },
  { header: "", body: "Keep the chain alive.", placeholder: "Make the thread longer..." },
];

const sign_in_pitches = [
  { header: "AI is flooding the Internet.", body: "You found the high ground. You found us." },
  { header: "Algorithms ruined the Internet.", body: "Here, your words reach everyone, not the void." },
  { header: "Welcome to the New Internet.", body: "No vanity. No followers. Just posts." },
  { header: "Dead Internet Theory is no longer a theory.", body: "Let's keep this new one alive." },
  { header: "Every word has an author.", body: "You wrote it. Now own it." },
  { header: "We've been expecting you.", body: "Join us to reach the rest." },
  { header: "You're posting on the New Internet.", body: "Be one of the pioneers." },
  { header: "Built different?", body: "So is this place. Let's get along." },
];

const top_up_pitches = [
  { header: "Top-up now. Post anytime.", body: ""},  
]; 

const approval_pitches = [
  { header: "Approve more. Skip more. Save more.", body: "" },
  { header: "Post faster. Pay lesser.", body: ""},
  { header: "Bigger approval. Fewer interruptions.", body: ""},
]; 

function randomPitch(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

let post_payment_pitch = randomPitch(post_payment_pitches);
let thread_input_pitch = randomPitch(thread_input_pitches);
let reply_input_pitch = randomPitch(reply_input_pitches);
let sign_in_pitch = randomPitch(sign_in_pitches);
let top_up_pitch = randomPitch(top_up_pitches);
let approval_pitch = randomPitch(approval_pitches);

let is_composing_post = false;
let is_seeing_cost = false;
let is_paying = false;

let create_fee_rates = null;
let selected_create_fee_token_standard = null;
let selected_create_fee_token_canister = null;
let selected_create_fee_rate = null;
let delete_fee_rates = null;
let selected_delete_fee_standard = null;
let selected_delete_token_canister = null;
let selected_delete_fee_rate = null;

let selected_sorting = 'new';
let is_start_open = false;
let is_comments_open = false;
let is_comment_action_open = false;
let is_posting = false;
let is_waiting_balance = false;
let is_viewing_cost_details = false;
let is_checking_balance = false;
let is_waiting_approval = false;
let is_approving = false;
let is_delete_open = false;
let is_deleting = false;
let is_withdraw_open = false;
let is_transferring = false;
let is_revoke_open = false;
let token_id = null;

let withdraw_receiver = "";
let withdraw_tips = "";
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

function shortPrincipal(p, show_middle = false) {
  let str = p.toText();
  let splitted = str.split('-');
  if (show_middle) {
    return splitted.length <= 3? str : `${splitted[0]}-...-${splitted[Math.floor(splitted.length / 2)]}-...-${splitted[splitted.length - 1]}`;
  } else return splitted.length <= 2? str : `${splitted[0]}-...-${splitted[splitted.length - 1]}`;
}

function shortAccount(hex) {
  const first = hex.slice(0, 4);
  const middle = hex.slice(30, 34); // center-ish
  const last = hex.slice(-4);
  return `${first}…${middle}…${last}`;
}

function hex64ToBytes32(hex64) {
  const bytes = new Uint8Array(32);
  for (let i = 0; i < 32; i++) {
    bytes[i] = parseInt(hex64.slice(i * 2, i * 2 + 2), 16);
  }
  return { bytes, toUint8Array: () => Array.from(bytes) };
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

function isValidDestination(str) {
  const dest = str.trim().replace(' ', '');
  withdraw_receiver = dest;
  let p = null;
  let a = null;
  let tips = 'Destination is empty.';
  let is_valid = false;
  if (dest.length > 0) {
    try {
      p = Principal.fromText(dest);
      if (p.isAnonymous()) {
        tips = 'Invalid Principal: Anonymous';
      } else if (p.compareTo(Principal.managementCanister()) == 'eq') {
        tips = 'Invalid Principal: Management Canister';
      } else {
        a = AccountIdentifier.fromPrincipal({ principal: p }).toHex();
        tips = `Principal detected (${shortPrincipal(p, true)}). Remember to double-check.`;
        is_valid = true;
      }
    } catch (err1) {
      console.error('Invalid Principal ID', err1);
      p = null;
      is_valid = /^[0-9a-fA-F]{64}$/.test(dest);
      if (is_valid) {
        a = dest; // hex64ToBytes32(dest);
        tips = `Account ID detected (${shortAccount(dest)}). Remember to double-check.`;
      } else {
        a = null;
        tips = 'Invalid destination format.';
      }
    }
  }
  return { p, a, tips, is_valid, dest }
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

function timeUntil(futureDate) {
  const now = new Date();
  const diffInSeconds = Math.floor((futureDate - now) / 1000);

  const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });

  if (diffInSeconds < 0) {
    return 'Expired';
  }

  if (diffInSeconds < 60) {
    return rtf.format(diffInSeconds, 'second');
  }

  const diffInMinutes = Math.floor(diffInSeconds / 60);
  if (diffInMinutes < 60) {
    return rtf.format(diffInMinutes, 'minute');
  }

  const diffInHours = Math.floor(diffInMinutes / 60);
  if (diffInHours < 24) {
    return rtf.format(diffInHours, 'hour');
  }

  const diffInDays = Math.floor(diffInHours / 24);
  if (diffInDays < 30) {
    return rtf.format(diffInDays, 'day');
  }

  const diffInMonths = Math.floor(diffInDays / 30);
  if (diffInMonths < 12) {
    return rtf.format(diffInMonths, 'month');
  }

  const diffInYears = Math.floor(diffInMonths / 12);
  return rtf.format(diffInYears, 'year');
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
      return this.renderPosts();
    }
  };
}

function focusPostInput() {
  const input = document.getElementById('post_input');
  const submit = document.getElementById('post_btn'); // The button under input

  setTimeout(() => {
    input.blur();
    input.focus();
    input.click();
    setTimeout(() => {
      submit.scrollIntoView({ behavior: 'smooth', block: 'end' });
    }, 200); // Wait for keyboard to show (tweak for device)
  }, 400); // Wait for slide-in animation to end
}

function closeDrawer(name, cb) {
  const drawer = document.querySelector('.drawer.' + name);
  if (drawer) {
    drawer.classList.remove('slide-in-up');
    drawer.classList.add('slide-out-down');
  };
  const backdraw = document.querySelector('.backdraw.' + name);
  if (backdraw) {
    backdraw.classList.remove('fade-in');
    backdraw.classList.add('fade-out');
  }
  setTimeout(cb, 400);
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
    this.interestingReply = null;
    this.threadComments = [];
    this.commentInput = "";

    this.setupScroll();
    // this.setupIdentity(); //todo: enable this
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
      const get_threads_fn = selected_sorting == 'new'? dhisper_anon.kay4_threads : dhisper_anon.kay4_bumps;
      if (this.posts.length > 0) {
        const last_post_id = this.posts[this.posts.length - 1].id;
        post_ids = await get_threads_fn([last_post_id], []); 
      } else post_ids = await get_threads_fn([], []);
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
    this.root.addEventListener('wheel', async (e) => {
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
    let touchStartX = 0;
    let touchEndX = 0;
    let touchStartY = 0;
    let touchEndY = 0;
  
    this.root.addEventListener('touchstart', (e) => {
      touchStartX = e.changedTouches[0].clientX;
      touchStartY = e.changedTouches[0].clientY;
    });
  
    this.root.addEventListener('touchend', (e) => {
      if (this.isSliding) return;
      if (is_composing_post) return;
      if (is_comments_open) return;
      touchEndX = e.changedTouches[0].clientX;
      touchEndY = e.changedTouches[0].clientY;
      const deltaX = touchStartX - touchEndX;
      const deltaY = touchStartY - touchEndY;
      if (Math.abs(deltaX) > Math.abs(deltaY)) {
        // horizontal swipe
      } else { // vertical
        if (deltaY > 40 && this.currentIndex < this.posts.length - 1) {
          this.startSlide(this.currentIndex + 1, 'up');
        } else if (deltaY < -40 && this.currentIndex > 0) {
          this.startSlide(this.currentIndex - 1, 'down');
        }
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
      }, 400);
    });
  }

  closeReplies(e) {
    e.preventDefault();
    const panel = document.querySelector('.panel.comments');
    if (panel) {
      panel.classList.remove('slide-in-left');
      panel.classList.add('slide-out-right');
      setTimeout(() => {
        is_comments_open = false;
        this.activeThread = null;
        this.renderPosts();
      }, 400); // matches slideOut animation duration
    }
  }

  closeReply(e) {
    e.preventDefault();
    const panel = document.querySelector('.panel.comment-actions');
    if (panel) {
      panel.classList.remove('slide-in-left');
      panel.classList.add('slide-out-right');
      setTimeout(() => {
        is_comment_action_open = false;
        this.interestingReply = null;
        this.renderPosts();
      }, 400); // matches slideOut animation duration
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
    if (caller_principal == null || caller_agent == null) {
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
      const max_content_size_promise = dhisper_anon.kay4_max_content_size();
      await this.checkBalance();
      base_cost = Number(selected_create_fee_rate.minimum_amount);
      max_content_size = Number(await max_content_size_promise);
      extra_chars = post_content.length > max_content_size? (post_content.length - max_content_size) : 0;
      extra_cost = extra_chars > 0? extra_chars * Number(selected_create_fee_rate.additional_amount_numerator) / Number(selected_create_fee_rate.additional_byte_denominator) : 0;
  
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
      this.closeBalanceWaiter(e, true);

      if (require_approval) {
        is_waiting_approval = true;
        return this.renderPosts();
      } else this.closePayment(e, true);
  
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
      is_paying = false;
      is_posting = false;
      if ('Err' in create_post_res) {
        this.errPopup("Create Post Error", create_post_res.Err);
      } else {
        this.closeCompose(e);
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
      const subtitle = JSON.stringify(err[err_key], null, 2);
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

  closePopup(e) {
    e.preventDefault();
    const popup_exist = document.querySelector('.popup');
    if (popup_exist) {
      popup_exist.classList.remove('in');
      popup_exist.classList.add('out');
      setTimeout(() => {
        popup_html = null;
        this.renderPosts();
      }, 400);
    }
  }

  showPopup(title = 'Error', subtitle = 'Check console', buttons = [{
    label: 'Close', 
    click: (e) => this.closePopup(e) }
  ]) {
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

  async setupIdentity() {
    this.isConnectingWallet = true;
    if (internet_identity == null) try {
      internet_identity = await AuthClient.create();
    } catch (err) {
      this.isConnectingWallet = false;
      return console.error("BG Error while Creating Auth Client", err);
    };
    try {
      if (await internet_identity.isAuthenticated()) {
        this.handleAuthenticated(null);
      } else console.log("No delegation");
    } catch (err) {
      console.error("BG Error while Checking Identity Delegation", err);
    };
    this.isConnectingWallet = false;
  }

  async logoutInternetIdentity(e) {
    e.preventDefault();
    this.isConnectingWallet = true;
    this.renderPosts();
    try {
      await internet_identity.logout();
      internet_identity = null;
      caller_agent = null;
      caller_principal = null;
      caller_account = '';
      
      token_balance = 0;
      token_power = 0;
      token_approval = null;
    } catch (err) {
      this.catchPopup("Error while Signing Out", err);
    }
    this.isConnectingWallet = false;
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
    try {
      if (await internet_identity.isAuthenticated()) {
        this.handleAuthenticated(e);
      } else internet_identity.login({
        // 30 days in nanoseconds
        maxTimeToLive: BigInt(30 * 24 * 60 * 60 * 1000 * 1000 * 1000),
        identityProvider,
        onSuccess: async () => await this.handleAuthenticated(e),
      });
    } catch (err) {
      this.isConnectingWallet = false;
      this.catchPopup("Error while Checking Identity Delegation", err);
      this.renderPosts();
    };
  }

  async handleAuthenticated(e) {
    try {
      const identity = await internet_identity.getIdentity();
      caller_agent = await HttpAgent.create({ identity });
      // if (network !== 'ic') await caller_agent.fetchRootKey();
      caller_principal = identity.getPrincipal();
      caller_account = AccountIdentifier.fromPrincipal({ principal: caller_principal }).toHex();
      console.log({ caller: shortPrincipal(caller_principal), caller_account });
      await prepareTokens();
      if (e != null && is_posting) {
        this.createNewPost(e);
      } else this.checkBalance();
    } catch (err) {
      const err_title = "Error after Authentication";
      if (e == null) this.catchPopup(err_title, err); else console.error(err_title, err);
    }
    if (e != null) {
      this.closeLogin(e, !is_posting);
    } else this.closeLogin(e);
  }

  async approveToken(e) {
    e.preventDefault();
    is_approving = true;
    this.renderPosts();
    try {
      const token_user = genToken(selected_create_fee_token_canister, { agent: caller_agent });
      const days30ms = 30n * 24n * 60n * 60n * 1000n; // 30 days in ms as BigInt
      const approve_res = await token_user.icrc2_approve({
        from_subaccount: [],
        amount: BigInt(post_cost * (selected_approval_plan == 'ten' ? 10 : selected_approval_plan == 'hundred' ? 100 : 1)),
        spender : { owner : Principal.fromText(dhisper_id), subaccount : [] },
        expected_allowance: [],
        expires_at: [BigInt(Date.now()) * 1_000_000n + days30ms * 1_000_000n],
        fee: [token_fee],
        memo: [],
        created_at_time: [],
      });
      is_approving = false;
      if ('Err' in approve_res) {
        this.errPopup("Approve Error", approve_res.Err);
      } else this.closeApprovalWaiter(e, true);
      if (is_posting) {
        this.createNewPost(e);
      }; 
    } catch (err) {
      is_approving = false;
      this.catchPopup("Error while Approving Payment", err);
    }
    this.renderPosts();
  }

  closeCompose(e) {
    e.preventDefault();
    if (is_posting) return;
    closeDrawer('compose', () => {
      is_composing_post = false;
      is_seeing_cost = false;
      is_paying = false;
      this.renderPosts(); 
    });
  }

  closePayment(e, force = false) {
    e.preventDefault();
    if (!force && is_paying) return;
    closeDrawer('cost', () => {
      is_seeing_cost = false;
      if (!force) is_posting = false;
      this.renderPosts();
    })     
  };

  closeLogin(e, reset = true) {
    e.preventDefault();
    closeDrawer('wallet', () => {
      this.isSelectingWallet = false; 
      this.isConnectingWallet = false;
      if (reset) {
        is_posting = false;
      };
      this.renderPosts(); 
    });
  }

  closeBalanceWaiter(e, force = false) {
    e.preventDefault();
    if (!force && is_checking_balance) return;
    closeDrawer('balance', () => {
      is_waiting_balance = false;
      if (!force) is_paying = false;
      this.renderPosts(); 
    })
  }

  closeApprovalWaiter(e, force = false) {
    e.preventDefault();
    if (!force && is_approving) return;
    closeDrawer('approve', () => {
      is_waiting_approval = false;
      if (!force) is_paying = false;
      this.renderPosts();
    })
  }

  closeCostDetails(e) {
    e.preventDefault();
    closeDrawer('cost-breakdown', () => {
      is_viewing_cost_details = false; 
      this.renderPosts(); 
    })
  }

  openReply(e, post) {
    e.preventDefault();
    is_comment_action_open = true;
    this.interestingReply = post;
    this.renderPosts();
  }

  openDeleteConfirm(e) {
    e.preventDefault();
    // this.showPopup('Delete Confirmation', "There's no going back. Are you sure?", [{
    //   label: 'Cancel',
    //   click: (ee) => this.closePopup(ee),
    // }, {
    //   label: 'Delete',
    //   click: (ee) => {},
    // }]);
    is_delete_open = true;
    this.renderPosts();
  }

  closeDeleteConfirm(e) {
    e.preventDefault();
    if (is_deleting) return;
    closeDrawer('delete-confirm', () => {
      is_delete_open = false;
      this.renderPosts();
    });
  }

  async deletePost(e) {
    e.preventDefault();
    if (caller_agent == null) {
      return this.selectWallet(e);
    };
    const dhisper_user = genDhisper(dhisper_id, { agent: caller_agent });
    is_deleting = true;
    this.renderPosts();
    try {
      const delete_post_res = await dhisper_user.kay4_delete({
        id: this.interestingReply.id,
        authorization: {
          None : { subaccount: [] }
        }
      });
      is_deleting = false;
      if ('Err' in delete_post_res) {
        this.errPopup("Delete Post Error", delete_post_res.Err);
      } else {
        // this.showPopup("Delete Successful", "");
        this.closeDeleteConfirm(e);
        if (this.activeThread) {
          this.getComments();
        }
        this.interestingReply.content = "";
        this.interestingReply.owner = Principal.anonymous();
      }
    } catch (err) {
      is_deleting = false;
      this.catchPopup("Error while Delete Post", err);
    }
    this.renderPosts();
  }

  openCompose(e) {
    e.preventDefault();
    is_composing_post = true;
    thread_input_pitch = randomPitch(thread_input_pitches);
    reply_input_pitch = randomPitch(reply_input_pitches);
    this.renderPosts();
    focusPostInput();
  }

  async openStart(e) {
    e.preventDefault();
    is_start_open = true;
    await prepareTokens();
    if (caller_principal) {
      this.checkBalance()
    } else this.renderPosts();
  }

  closeStart(e) {
    e.preventDefault();
    const panel = document.querySelector('.panel.start');
    if (panel) {
      panel.classList.remove('slide-in-right');
      panel.classList.add('slide-out-left');
      setTimeout(() => {
        is_start_open = false;
        this.isConnectingWallet = false;
        this.renderPosts();
      }, 400); // matches slideOut animation duration
    }
  }

  async checkBalance() {
    const token_anon = genToken(selected_create_fee_token_canister);
    const token_fee_promise = token_anon.icrc1_fee();
    const token_name_promise = token_anon.icrc1_name();
    const token_symbol_promise = token_anon.icrc1_symbol();
    const token_decimals_promise = token_anon.icrc1_decimals();
    
    const token_balance_promise = token_anon.icrc1_balance_of({ owner : caller_principal, subaccount : [] });
    const token_approval_promise = token_anon.icrc2_allowance({
      spender : { owner : Principal.fromText(dhisper_id), subaccount : [] },
      account : { owner : caller_principal, subaccount : [] }
    });
    is_checking_balance = true;
    this.renderPosts();
    token_id = selected_create_fee_token_canister;
    try {
      token_fee = Number(await token_fee_promise);
      token_name = await token_name_promise;
      token_symbol = await token_symbol_promise;
      token_power = 10 ** Number(await token_decimals_promise);
      token_balance = Number(await token_balance_promise);
      token_approval = await token_approval_promise;
    } catch (err) {
      this.catchPopup("Error while Checking Balance", err);
    }
    console.log({ token_balance, token_power, token_approval });
    is_checking_balance = false;
    this.renderPosts();
  }

  refresh(e, sort) {
    e.preventDefault();
    selected_sorting = sort;
    this.currentIndex = null;
    this.nextIndex = null;
    this.posts = [];
    this.getPosts();
    this.closeStart(e);
  }

  openWithdraw(e) {
    e.preventDefault();
    is_withdraw_open = true;
    this.renderPosts();
  }

  closeWithdraw(e) {
    e.preventDefault();
    if (is_transferring) return;
    closeDrawer('withdraw', () => {
      is_withdraw_open = false;
      this.renderPosts();
    });
  }

  async withdraw(e) {
    e.preventDefault();
    is_transferring = true;
    this.renderPosts();
    const addr = isValidDestination(withdraw_receiver);
    const token_user = genToken(selected_create_fee_token_canister, { agent: caller_agent });
    if (addr.p) {
      try {
        const transfer_res = await token_user.icrc1_transfer({
          amount: BigInt(token_balance - token_fee),
          from_subaccount: [],
          to: { owner: addr.p, subaccount: [] },
          fee: [token_fee],
          created_at_time: [],
          memo: [],
        });
        is_transferring = false;
        if ('Err' in transfer_res) {
          this.errPopup("Withdraw (via Principal) Error", transfer_res.Err);
        } else this.closeWithdraw(e);
      } catch (err) {
        is_transferring = false;
        this.catchPopup("Error while Withdrawing (via Principal)", err);
      }
    } else if (addr.a) {
      try {
        const transfer_block_id = await token_user.send_dfx({
          to: addr.a,
          fee: { e8s: token_fee },
          memo: 0,
          from_subaccount: [],
          created_at_time: [],
          amount: { e8s: token_balance - token_fee }
        });
        is_transferring = false;
        console.log("Withdraw (via Account ID) OK", 'Block ID: ' + transfer_block_id);
        this.closeWithdraw(e);
      } catch (err) {
        is_transferring = false;
        this.catchPopup("Error while Withdrawing (via Account ID)", err);
      }
    } else this.showPopup("Invalid Withdrawal Destination", "Please provide a Principal or an Account ID.");
    this.checkBalance();
  }

  openRevoke(e) {
    e.preventDefault();
    is_revoke_open = true;
    this.renderPosts();
  }

  closeRevoke(e) {
    e.preventDefault();
    if (is_approving) return;
    closeDrawer('revoke', () => {
      is_revoke_open = false;
      this.renderPosts();
    })
  };

  async revoke(e) {
    e.preventDefault();
    is_approving = true;
    this.renderPosts();
    try {
      const token_user = genToken(selected_create_fee_token_canister, { agent: caller_agent });
      const revoke_res = await token_user.icrc2_approve({
        from_subaccount: [],
        amount: 0,
        spender : { owner : Principal.fromText(dhisper_id), subaccount : [] },
        expected_allowance: [],
        expires_at: [],
        fee: [token_fee],
        memo: [],
        created_at_time: [],
      });
      is_approving = false;
      if ('Err' in revoke_res) {
        this.errPopup("Revoke Error", revoke_res.Err);
      } else this.closeRevoke(e);
    } catch (err) {
      is_approving = false;
      this.catchPopup("Error while Revoking", err);
    }
    this.checkBalance();
  }

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
        <div class="subtext">${currentPost?.owner? currentPost.owner.isAnonymous()? 'DELETED' : shortPrincipal(currentPost.owner) : ''}<br>${currentPost ? timeAgo(currentPost.timestamp) : ''}</div>
      </div>`;
    }
    let next_post;
    if (this.nextIndex == null) next_post = null; else {
      const nextPost = this.posts[this.nextIndex];
      // console.log({ nextPost });
      next_post = nextPost ? html`<div class="post-content-wrapper">
        <div class="text">${nextPost.content}</div>
        <div class="subtext">${nextPost.owner.isAnonymous()? 'DELETED' : shortPrincipal(nextPost.owner)}<br>${timeAgo(nextPost.timestamp)}</div>
      </div>` : null;
    }
    
    const threads_pane = html`<div class="post-layer current ${this.direction === 'up' ? 'slide-out-up' : this.direction === 'down' ? 'slide-out-down' : ''}">${current_post}</div>
      ${next_post !== null? html`<div class="post-layer next ${this.direction === 'up' ? 'slide-in-up' : 'slide-in-down'}">${next_post}</div>` : null}
    `;
    const replies_pane = this.posts.length > 0 && is_comments_open && this.activeThread
    ? html`
        <div class="panel comments slide-in-left">
          <div class="panel-scroll">
            <div class="comment-grid">
              <div class="comment">
                <div class="meta">#${this.activeThread.id} • ${this.activeThread.owner .isAnonymous()? 'DELETED' : shortPrincipal(this.activeThread.owner)}${this.activeThread.timestamp ? ' • ' + timeAgo(this.activeThread.timestamp) : ''}</div>
                <div class="content">${this.activeThread.content}</div>
              </div>
              <button class="action-btn" @click=${(e) => this.openReply(e, this.activeThread)}>⋮</button>
            </div>
            ${this.threadComments.map(comment => html`
              <div class="comment-grid">
                <div class="comment">
                  <div class="meta">#${comment.id} • ${comment.owner.isAnonymous()? 'DELETED' : shortPrincipal(comment.owner)}${comment.timestamp ? ` • ${timeAgo(comment.timestamp)}` : ''}</div>
                  <div class="content">${comment.content}</div>
                </div>
                <button class="action-btn" @click=${(e) => this.openReply(e, comment)}>⋮</button>
              </div>
            `)}
          </div>
          <div class="action-bar sticky">
            <button class="action-btn" @click=${(e) => this.closeReplies(e)}>Close</button>
            <button class="action-btn" @click=${(e) => this.openCompose(e)}>Add Reply</button>
          </div>
        </div>
      ` : null;
      // todo: fix the small text since we've using 1.25 rem
      // todo: reduce to 1rem on default text
    const reply_action_pane = is_comment_action_open && this.interestingReply? html`
    <div class="panel comment-actions slide-in-left">
      <div class="panel-scroll">
        <p>
          ${this.interestingReply.owner.isAnonymous()? '' : html`<strong>${this.interestingReply.content}</strong><br><br>`}
          <small>
            ${this.interestingReply.owner.isAnonymous()? html`<strong>DELETED</strong>` : html`<i>by, ${this.interestingReply.owner.toText()}</i>`}<br><br>
            at, ${this.interestingReply.timestamp.toLocaleString()}
          </small>
        </p>
      </div>
      <div class="action-bar sticky">
        <button class="action-btn" @click=${(e) => this.closeReply(e)}>Close</button>
        ${caller_principal && this.interestingReply.owner.toText() == caller_principal.toText() ? 
          html`<button class="action-btn failed" @click=${(e) => this.openDeleteConfirm(e)}>Delete</button>`
          : html`<button class="action-btn success" ?disabled=${true}>Tip</button>`
        }
      </div>
    </div>
    ` : null;
    const start_pane = is_start_open ? html`
    <div class="panel start slide-in-right">
      <div class="panel-scroll">
        <p>
          <small>Welcome, <strong>${caller_principal? caller_principal.toText() : `Guest`}</strong></small><br><br>
          <strong>Balance:</strong> ${caller_principal
            ? html`<small>${!is_checking_balance || token_power > 0? normalizeNumber(token_balance / token_power) : html`<span class="spinner"></span>`} ${token_symbol}</small> 
          &nbsp<button class="action-btn compact" ?disabled=${!(token_fee > 0 && token_balance > token_fee)} @click=${(e) => this.openWithdraw(e)}>Withdraw</button>` 
            : html`<button class="action-btn success compact" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>${this.isConnectingWallet
          ? html`<span class="spinner"></span> Connecting...`
          : html`Sign in to see this`}</button>`} <br><br>
          <strong>Approval:</strong> ${caller_principal
            ? html`<small>${!is_checking_balance || (token_approval && token_power > 0)? normalizeNumber(Number(token_approval.allowance) / token_power) : html`<span class="spinner"></span>`} ${token_symbol}</small> 
          &nbsp<button class="action-btn compact" ?disabled=${!(token_fee > 0 && token_balance > token_fee && token_approval.allowance > 0)} @click=${(e) => this.openRevoke(e)}>Revoke</button><br>
          ${token_approval?.allowance > 0? 
            html`<small><small><i>${token_approval.expires_at.length > 0? `Expires ${timeUntil(new Date(Number(token_approval.expires_at[0]) / 1000000))}` : 'No expiry'}</i></small></small>` : ''
          }`
            : html`<button class="action-btn success compact" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>${this.isConnectingWallet
          ? html`<span class="spinner"></span> Connecting...`
          : html`Sign in to see this`}</button>`}<br><br>
          <strong>Sort Threads by:</strong><br>
          <button class="action-btn ${selected_sorting == 'new'? 'success' : ''} compact" @click=${(e) => this.refresh(e, 'new')}>Newest</button>&nbsp
          <button class="action-btn ${selected_sorting == 'new'? '' : 'success'} compact" @click=${(e) => this.refresh(e, 'hot')}>Last Activity</button>
        </p>
      </div>
      <div class="action-bar sticky">
        ${caller_principal? html`<button class="action-btn failed" ?disabled=${this.isConnectingWallet} @click=${(e) => this.logoutInternetIdentity(e)}>Sign Out</button>` : html`<button class="action-btn success" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>${this.isConnectingWallet
            ? html`<span class="spinner"></span> Connecting...`
            : html`Sign in via Internet ID`}</button>`}
        <button class="action-btn" @click=${(e) => this.closeStart(e)}>Close</button>
      </div>
    </div>
    ` : null
    
    const create_new_post_form = is_composing_post
      ? html`<div class="backdraw compose fade-in" @click=${(e) => this.closeCompose(e)}></div>
      <div class="drawer compose slide-in-up">
        <p>
          <strong>${
            // post_input_pitch.header
            is_comments_open? 'Add a Reply' : 'Create a New Thread'
          }</strong><br>
          <small><small>${is_comments_open? reply_input_pitch.body : thread_input_pitch.body}</small></small>
          <br><br>
          <input id="post_input" type="text" ?disabled=${is_posting} placeholder="${is_comments_open? reply_input_pitch.placeholder : thread_input_pitch.placeholder}" @input=${(e) => this.updateCharCount(e)} .value=${post_content || ''}/>
          <small><small>${char_count}</small></small>
        </p>
        <div class="action-bar">
          <button class="action-btn" ?disabled=${is_posting} @click=${(e) => this.closeCompose(e)}>Close</button>
          <button id="post_btn" class="action-btn success" ?disabled=${is_posting || post_content.trim().length == 0} @click=${(e) => {
            post_payment_pitch = randomPitch(post_payment_pitches);
            sign_in_pitch = randomPitch(sign_in_pitches);
            top_up_pitch = randomPitch(top_up_pitches);
            approval_pitch = randomPitch(approval_pitches);
            this.createNewPost(e);
          }}>${is_posting
            ? html`<span class="spinner"></span> Sending...`
            : html`➤ Send`}</button>
        </div>
      </div>
    ` : null;
    const delete_confirm_form = is_delete_open? html`
    <div class="backdraw delete-confirm fade-in" @click=${(e) => this.closeDeleteConfirm(e)}>
    </div>
    <div class="drawer delete-confirm slide-in-up">
      <p>
        <strong>Delete Confirmation</strong><br>
        <small>There's no going back. Are you sure?</small>
      </p>
      <div class="action-bar">
        <button class="action-btn success" ?disabled=${is_deleting} @click=${(e) => this.closeDeleteConfirm(e)}>No</button>
        <button class="action-btn failed" ?disabled=${is_deleting} @click=${(e) => this.deletePost(e)}>${is_deleting? html`<span class="spinner"></span> Deleting...` : html`Yes, Delete`}</button>
      </div>
    </div>` : null;
    let withdraw_form = null;
    if (is_withdraw_open) {
      const withdraw_validity = isValidDestination(withdraw_receiver);
      withdraw_form = html`
        <div class="backdraw withdraw fade-in" @click=${(e) => this.closeWithdraw(e)}>
        </div>
        <div class="drawer withdraw slide-in-up">
          <p>
            <strong>Withdrawing ${normalizeNumber(token_balance / token_power)} ${token_symbol}</strong><br>
            <small><small>
              - Withdrawal fee: ${normalizeNumber(token_fee / token_power)} ${token_symbol}<br>
              = Receiver gets: <strong>${normalizeNumber((token_balance - token_fee) / token_power)} ${token_symbol}</strong>
            </small></small><br><br>
            <input id="withdraw_input" type="text" ?disabled=${is_posting} placeholder="Receiver's Principal or Account ID" @input=${(e) => {
              withdraw_receiver = e.target.value;
              this.renderPosts();
            }} .value=${withdraw_receiver || ''}/>
            <small><small>${withdraw_validity.tips}</small></small>
          </p>
          <div class="action-bar">
            <button class="action-btn success" ?disabled=${is_transferring} @click=${(e) => this.closeWithdraw(e)}>Close</button>
            <button class="action-btn" ?disabled=${is_transferring || !withdraw_validity.is_valid} @click=${(e) => this.withdraw(e)}>${is_transferring? html`<span class="spinner"></span> Withdrawing...` : html`Withdraw`}</button>
          </div>
        </div>`;
    };

    const revoke_form = is_revoke_open ? html`
    <div class="backdraw revoke fade-in" @click=${(e) => this.closeRevoke(e)}>
    </div>
    <div class="drawer revoke slide-in-up">
      <p>
        <strong>Revoke Confirmation</strong><br>
        <small><small>This will disable auto-deduction on your balance on paid operations by the app. You will have to approve the app again the next time you want to perform paid operations. Continue?<br><br>
        Revocation fee: ${normalizeNumber(token_fee / token_power)} ${token_symbol}<br>
        Balance after revoking: ${normalizeNumber((token_balance - token_fee) / token_power)} ${token_symbol}</small></small>
      </p>
      <div class="action-bar">
        <button class="action-btn success" ?disabled=${is_approving} @click=${(e) => this.closeRevoke(e)}>No</button>
        <button class="action-btn failed" ?disabled=${is_approving} @click=${(e) => this.revoke(e)}>${is_approving? html`<span class="spinner"></span>Revoking...` : html`Yes, Revoke`}</button>
      </div>
    </div>` : null;

    const wallet_selectors = this.isSelectingWallet
      ? html`<div class="backdraw wallet fade-in" @click=${(e) => this.closeLogin(e)}></div>
      <div class="drawer wallet slide-in-up">
        <p>
          <strong>${sign_in_pitch.header}</strong><br>
          <small><small>${sign_in_pitch.body}</small></small>
        </p>
        <div class="action-bar">
          <button class="action-btn" @click=${(e) => this.closeLogin(e)}>Close</button>
          <button class="action-btn success" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>${this.isConnectingWallet
            ? html`<span class="spinner"></span> Connecting...`
            : html`Sign in via Internet ID`}</button>
        </div>
      </div>
    ` : null;
    
  //   const token_selectors = html`
  //   ${this.isSelectingToken
  //   ? html`<div class="backdraw token fade-in" @click=${() => { 
  //       this.isSelectingToken = false; 
  //       this.renderPosts(); 
  //     }}></div>`
  //   : null}
  //   <div class="drawer token slide-in-up">
  //     <div>Select the token of your post</div>
      
  //     <button class="send-btn" ?disabled=${this.isConnectingWallet} @click=${(e) => this.loginInternetIdentity(e)}>
  //         ${this.isConnectingWallet
  //           ? html`<span class="spinner"></span> Sending...`
  //           : html`Pay & Send`}
  //       </button>
  //   </div>
  // `;
    const cost_and_reasons = is_seeing_cost
      ? html`<div class="backdraw cost fade-in" @click=${(e) => this.closePayment(e)}></div>
      <div class="drawer cost slide-in-up">
        <p>
          <strong>${token_total.msg}</strong>&nbsp
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
    ` : null;
    const token_balance_waiter_details = is_viewing_cost_details
    ? html`<div class="backdraw cost-breakdown fade-in" @click=${(e) => this.closeCostDetails(e)}></div>
    <div class="drawer cost-breakdown slide-in-up">
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
    ` : null;
    const token_balance_waiter = is_waiting_balance
    ? html`<div class="backdraw balance fade-in" @click=${(e) => this.closeBalanceWaiter(e)}></div>
    <div class="drawer balance slide-in-up">
      <p>
        <strong>${top_up_pitch.header}</strong>
        <!-- <br><small><small>${top_up_pitch.body}</small></small> -->
        <br><br><small>${token_total.msg}</small>
        <br><small>Your balance: ${is_checking_balance ? html`<span class="spinner"></span>` : normalizeNumber(token_balance / token_power)} ${token_symbol}</small>
        <br>
        <br>You need to <strong>send ${is_checking_balance ? html`<span class="spinner"></span>` : normalizeNumber((token_total.amount - token_balance) / token_power)} ${token_symbol}</strong> to one of your ${token_symbol} addresses below:<br>
        <br><strong>• Principal</strong>: &nbsp<button class="action-btn ${caller_principal_copied ? "success" : caller_principal_copy_failed ? 'failed' : ''} compact" @click=${async (e) => { 
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
        <br><br><strong>• Account</strong>: &nbsp<button class="action-btn ${caller_account_copied ? "success" : caller_account_copy_failed? 'failed' : ''} compact" @click=${async (e) => { 
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
            : html`Top-up Done`}
        </button>
      </div>
    </div>
    ` : null;
    const token_approve_form = is_waiting_approval
      ? html`<div class="backdraw approve fade-in" @click=${(e) => this.closeApprovalWaiter(e)}></div>
      <div class="drawer approve slide-in-up">
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
            <small><strong>This post + 9 future posts</strong></small><br>
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
            <small><strong>This post + 99 future posts</strong></small><br>
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
    ` : null;
    const popup = popup_html ? html`
    <div class="backdraw zpopup"></div>
    <div class="popup in">${popup_html}</div>
    ` : null;

    render(html`
    <header class="logo-bar">
      <img src="dhisper_logo.svg" alt="Dhisper Logo"/>
    </header>
    ${threads_pane}
    <div class="action-bar thread">
      <button class="action-btn" @click=${(e) => this.openStart(e)}>Start</button>
      <button class="action-btn" @click=${(e) => this.openCompose(e)}>New Thread</button>
      <button class="action-btn" @click=${(e) => this.openReplies(e)}>Replies</button>
    </div>
    ${replies_pane}
    ${start_pane}
    ${reply_action_pane}
    ${create_new_post_form}   
    ${delete_confirm_form} 
    ${withdraw_form}
    ${revoke_form}
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