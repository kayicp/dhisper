# Dhisper

**Dhisper** is a free-to-use Web3 thread-based discussion platform, prioritizing on user experience. Both frontend and backend is hosted on [the Internet Computer](internetcomputer.org).

A live demo is available at: https://loxja-3yaaa-aaaan-qz3ha-cai.icp0.io/

A video in action: https://youtu.be/40pLkVNUWbM?t=115

---

## Introduction

Dhisper is a place for people tired of chaotic social feeds to have calm, focused conversations one topic at a time.

Highlights:

* **Explore one thread at a time**, allowing users to focus on reading, instead of being bombarded with tons of texts on their screen like other platforms. 
* **Mobile-first thumb-friendly buttons** to make users feel comfortable when using it on small devices, instead of some buttons being at the very top causing users to make awkward finger movements just to click them like on the other platforms. 
* **Anti-noise** as only one thread can be created per minute, and one reply can be created per 30 seconds per thread.  
* **Free to use** unlike many web3 social platforms. 
* **Immediately use it** as there are no landing page.
* **No login required** to browse the contents, but to post one have to login via Internet Identity.
* **Thread bumping to the top** for the owner of a paid thread each time they receive a paid reply, to gain visibility.
* **Moderation power per thread** for the owner of a paid thread to delete free replies within their thread.

The backend architecture is nothing fancy as most work is on the UX/UI:

```motoko
// store the settings such as cooldown duration and 
stable var metadata = RBTree.empty<Text, ICRC_16.Value>();

// map the post id to post object
stable var posts = RBTree.empty<Nat, Post>();
stable var post_id = 0; // to increment each post

// map the thread's post id to replies' post ids
stable var threads = RBTree.empty<Nat, RBTree.RBTree<Nat, ()>>();

// map bumping reply to their thread to track visibility
stable var bumps = RBTree.empty<Nat, Nat>(); // PostId -> ThreadId
```

---

## Installation
Step-by-step guide to get a copy of the project up and running locally for development and testing.

```bash
$ git clone git@github.com:kayicp/dhisper.git
$ cd dhisper
$ npm install
$ bash deploy-local.sh # to deploy the token too
```

## Usage
Start [here](https://loxja-3yaaa-aaaan-qz3ha-cai.icp0.io/).

One can browse the threads and read their replies without signing in. To scroll the threads, use the mouse-scrollwheel or the slide/swipe touch gesture.

Only interactions such as Creating a Post, Deleting a Post, Withdrawing Balance, and Revoking Token Approval, require signing in via Internet Identity. 


## Documentation
Further information on the backend architecture can be found in the [Design Document](DesignDocument.md)

## Roadmap

- [x] Backend - metadata, with payment table
- [x] Backend - create thread/reply, with payment
- [x] Backend - query endpoints
- [x] Frontend - one-by-one thread scrolling
- [x] Frontend - mobile-first, thumb-friendly, post+pay UX
- [x] Frontend - reply pane
- [x] Backend - [deployed on the IC](https://dashboard.internetcomputer.org/canister/lhuc4-nqaaa-aaaan-qz3gq-cai)
- [x] Frontend - [deployed on the IC](https://loxja-3yaaa-aaaan-qz3ha-cai.icp0.io/)
- [x] Backend - delete thread/reply
- [x] Backend - thread bumping
- [x] Backend - paid posting with limit bypass
- [x] Backend - free posting with cooldown limit
- [x] Frontend - wallet (balance, approval, withdraw, revoke)
- [x] Frontend - delete UX
- [x] Frontend - threads sorter (recently created, recently bumped)
- [ ] Backend/Frontend - Anonymous (2vxsx-fae) posting, login users can delete their postings
- [ ] Backend/Frontend - Tests
- [ ] Backend - Temporary Admin
- [ ] Backend - Fee collection
- [ ] Backend - ICRC-3 to archive the owners of the posts
- [ ] Backend - Trim posts to save space
- [ ] Frontend - Caching
- [ ] Frontend - Optimistic Rendering
- [ ] Backend/Frontend - Tipping
- [ ] Backend/Frontend - Reporting
- [ ] Backend/Frontend - Moderating
- [ ] Backend/Frontend - Reputation scoring

## License
No license (as this repo is only made public for the ICP Grant comittee)

## Acknowledgements
- DFINITY
- ICRC WG for ICRC-1, ICRC-2, ICRC-16

## References
- [Internet Computer](https://internetcomputer.org)