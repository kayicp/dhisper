# Dhisper

**Dhisper** is a decentralized message board protocol built on the Internet Computer, designed to support thread-based discussions with fine-grained ownership, authorization, and metadata control. Its primary functionality allows users to create threads, post replies, query content, and manage ownership or authorization; all on-chain.

Posts and threads can be paginated, queried by timestamp or bump order, and selectively deleted by their owners. It’s built for communities that need both openness and access control.

A live demo is available at: [Dhisper's frontend canister](https://loxja-3yaaa-aaaan-qz3ha-cai.icp0.io/)

> 📸 Screenshots and demo videos coming soon.

---

## Introduction

Dhisper is a decentralized discussion engine for open communities, forums, and apps that require trustless ownership of user content. It supports creation and deletion of posts, full authorization control, and efficient paginated queries; all stored immutably on-chain.

Highlights:

* **Decentralized Ownership**: Each post or reply has identity-based ownership with optional subaccount support.
* **Structured Threads & Replies**: Supports nested threads with max-size constraints, timestamps, and bump tracking.
* **Fine-Grained Deletion**: Posts can be deleted only by thread or post owners under defined rules.
* **Batch Queries**: Optimized endpoints allow bulk-fetching timestamps, owners, and authorizations for frontend efficiency.
* **Metadata-Driven Limits**: Max replies, threads, pagination sizes are configurable through metadata values.

Here’s an example of the system’s architectural flow:

![Dhisper Architecture](local-workflow.png)

---

## Installation
Step-by-step guide to get a copy of the project up and running locally for development and testing.

### Install
A step-by-step guide to installing the project, including necessary configuration etc.

```bash
$ git clone git@github.com:kayicp/dhisper.git
$ cd dhisper
$ npm install
$ bash deploy-local.sh
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
This project is licensed under the MIT license, see LICENSE.md for details. See CONTRIBUTE.md for details about how to contribute to this project. 

## Acknowledgements
- DFINITY
- ICRC WG for ICRC-1, ICRC-2, ICRC-16

## References
- [Internet Computer](https://internetcomputer.org)