# Dev Grant Final Milestone Review

## First + Final

### Documentation:
* Design document of the Dhisper's backend canister. [(LINK HERE)](DesignDocument.md)

### Backend: 
* Deployed on the IC mainnet [(LINK HERE)](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=lhuc4-nqaaa-aaaan-qz3gq-cai)
* User can update-call the `kay4_create` endpoint to create a new thread/reply (with ICP token's icrc2_transfer_from to combat Sybil spam) (with pre-defined characters limit).
* User can query-call the `kay4_threads` endpoint to fetch threads (in batches) (sorted by newest to oldest).
* User can query-call the `kay4_replies_of` endpoint to fetch replies (in batches) (sorted by oldest to newest) of current thread.
* User can query-call the `kay4_timestamps_of`, `kay4_contents_of`, `kay4_owners_of`, etc. (in batches) to build the threads/replies.
* User can update-call the `kay4_delete` endpoint to delete their own thread/reply (free-to-use but access-controlled) (usable once). If the deleted post is a thread, the replies within the thread will remain (to honor the other users who have paid to post their replies).
* User can update-call the `kay4_create` endpoint to create a new thread/reply, with ability to bypass the characters limit by paying ICP token proportional to the length of extra characters (total characters length minus predefined character limit) (according to the fee rate).
* User can query-call the `kay4_bumps` endpoint to fetch threads (in batches) (sorted by recently-replied to anciently-replied).

### Frontend:
* Deployed on the IC mainnet [(LINK HERE)](https://loxja-3yaaa-aaaan-qz3ha-cai.icp0.io/).
* User can browse the threads (one-by-one via sliding animation) (anonymously).
* User can read the replies of current thread (in a list pane) (anonymously).
* User can create a new thread (requires login via Internet Identity) (includes ICP token allowance approval).
* User can add a reply to current thread (requires login via Internet Identity) (includes ICP token allowance approval).
* User can create a new thread/reply with optional characters limit bypass to input longer content, according to the fee rates.
* User can delete their threads/replies, with confirmation.
* User can select to sort the threads between "New" (newest first) or "Hot" (recently-replied first) when browsing.
* ~~User can click to view more of the thread/reply's content if it's too long.~~ (Canceled)

## What's next?
* Set myself as moderator (temporary centralized moderation) to delete harmful posts.
* Anonymous posting to increase user flows (then incentivize the users to login via Internet Identity to get higher character limits and shorter cooldown)
* Share on Reddit (Whisper community, Yikyak community, and other anonymous sharing community)
* Share on 4chan (advice board, business board, etc.)
* Share on ProductHunt(?)
* Caching contents on browser to enhance UX
* Optimistic rendering to enhance UX
* Tipping to encourage high quality posts
* Reputation scoring to reward good behaviors (eg: higher char limits, per user cooldown instead of global cooldown)
* Community-based Reporting+Moderation to punish bad actors (spammers, illegal posts, etc.)
* Launch a token if this gets traction to reward early users

## Questions

* What do you think? Any feedbacks? (eg: character limits, cooldown duration, bumping rules, overall design, etc.)
* Which has a more pressing need in the ICP eco right now to increase the adoption? 
  - ProductHunt for ICP (to enable community discovery/visibility for ICP dapps), or LinkTree for ICP (to mask canister URL), or should I just continue with Dhisper, or do you have something better?
* If I choose to continue with Dhisper or start a new dapp, is it okay to apply for the Developer Grant again? If so, then what is the amount I should go for?