# Solana Development Resource Navigator

This is an index to organizer-approved documentation and local non-AI development tools. It is not a source of generated solutions.

## Popup controls

- `:Solana` or `Space S`: open this navigator
- `/text`: search this navigator
- `n` / `N`: next or previous result
- `o`: open the URL under the cursor
- `m` or `Enter`: expand or collapse
- `e`: edit this index
- `q` or `Esc`: close

## Start with the challenge

- Rules: `/Users/christianaguilar/solana-hackathon-kit/onion-no-ai-hack/README.md`
- Example brief: `/Users/christianaguilar/solana-hackathon-kit/onion-no-ai-hack/BRIEF_EXAMPLE.md`
- Official templates: https://solana.com/developers/templates
- React + Vite + Anchor template: https://solana.com/developers/templates/react-vite-anchor

Open a local file with:

```vim
:e /Users/christianaguilar/solana-hackathon-kit/onion-no-ai-hack/README.md
```

## Solana concepts

- Documentation home: https://solana.com/docs
- Accounts: https://solana.com/docs/core/accounts
- Transactions: https://solana.com/docs/core/transactions
- Fees: https://solana.com/docs/core/fees
- Program Derived Addresses: https://solana.com/docs/core/pda
- Cross Program Invocation: https://solana.com/docs/core/cpi
- Programs: https://solana.com/docs/programs
- Program deployment: https://solana.com/docs/programs/deploying
- RPC reference: https://solana.com/docs/rpc
- `simulateTransaction`: https://solana.com/docs/rpc/http/simulatetransaction
- Program examples: https://github.com/solana-developers/program-examples

## Anchor syntax and references

- Anchor documentation: https://www.anchor-lang.com/docs
- Local development: https://www.anchor-lang.com/docs/quickstart/local
- Program structure and macros: https://www.anchor-lang.com/docs/basics/program-structure
- Account types: https://www.anchor-lang.com/docs/references/account-types
- Account constraints: https://www.anchor-lang.com/docs/references/account-constraints
- Account space: https://www.anchor-lang.com/docs/references/space
- PDAs: https://www.anchor-lang.com/docs/basics/pda
- CPIs: https://www.anchor-lang.com/docs/basics/cpi
- Custom errors: https://www.anchor-lang.com/docs/features/errors
- Events: https://www.anchor-lang.com/docs/features/events
- TypeScript client: https://www.anchor-lang.com/docs/clients/typescript
- Rust client: https://www.anchor-lang.com/docs/clients/rust
- LiteSVM testing: https://www.anchor-lang.com/docs/testing/litesvm
- Mollusk testing: https://www.anchor-lang.com/docs/testing/mollusk
- Anchor CLI: https://www.anchor-lang.com/docs/references/cli
- `Anchor.toml`: https://www.anchor-lang.com/docs/references/anchor-toml
- Security exploits: https://www.anchor-lang.com/docs/references/security-exploits

## Rust language help

- Rust Book: https://doc.rust-lang.org/book/
- Standard library: https://doc.rust-lang.org/std/
- Error code index: https://doc.rust-lang.org/error_codes/error-index.html
- Rust by Example: https://doc.rust-lang.org/rust-by-example/
- Clippy lints: https://rust-lang.github.io/rust-clippy/master/
- rust-analyzer manual: https://rust-analyzer.github.io/book/
- Crate documentation: https://docs.rs/
- Package registry: https://crates.io/

Local Rust documentation:

```bash
rustup doc --book
rustup doc --std
cargo doc --open
```

## React and TypeScript

- React: https://react.dev/learn
- TypeScript handbook: https://www.typescriptlang.org/docs/handbook/intro.html
- Vite: https://vite.dev/guide/
- MDN JavaScript: https://developer.mozilla.org/en-US/docs/Web/JavaScript
- Tailwind CSS: https://tailwindcss.com/docs
- Solana frontend documentation: https://solana.com/docs/frontend
- Solana Kit: https://solana.com/docs/clients/kit
- Framework Kit: https://github.com/solana-foundation/framework-kit

## Neovim inspection tools

Use these before searching the web:

- `K`: documentation for the symbol under the cursor
- `gd`: go to definition
- `gD`: go to declaration
- `gi`: go to implementation
- `grr`: show references
- `grn`: rename symbol
- `gra`: available code actions
- `Space ld`: full diagnostic under the cursor
- `[d` / `]d`: previous or next diagnostic
- `Space sd`: all project diagnostics
- `Space ss`: workspace symbols
- `Ctrl-space`: completion and documentation
- `:LspInfo`: verify the attached language server
- `:Mason`: inspect installed language and debugging tools
- `:checktime`: reload files changed outside Neovim

Rust and Anchor commands:

- `Space rc`: `cargo check --all-targets`
- `Space rl`: strict `cargo clippy`
- `Space rt`: `cargo test`
- `Space ab`: `anchor build`
- `Space at`: `anchor test`
- `Space db`: toggle a native Rust breakpoint
- `Space dc`: start or continue CodeLLDB
- `Space di`: step into
- `Space do`: step over
- `Space dO`: step out
- `Space du`: debugger interface
- `Space dr`: debugger REPL
- `Space dt`: terminate debugging

## Terminal inspection commands

Toolchain:

```bash
rustc --version
cargo --version
rust-analyzer --version
solana --version
anchor --version
node --version
```

Cluster and wallet:

```bash
solana config get
solana address
solana balance
solana cluster-version
```

Rust:

```bash
cargo fmt --all -- --check
cargo check --all-targets
cargo clippy --all-targets --all-features -- -D warnings
cargo test
cargo test TEST_NAME -- --nocapture
RUST_BACKTRACE=1 cargo test -- --nocapture
cargo tree
cargo tree -d
```

Anchor:

```bash
anchor keys list
anchor keys sync
anchor build
anchor test
anchor expand
ANCHOR_LOG=1 anchor build
anchor debugger
```

Program and transaction inspection:

```bash
solana logs
solana confirm -v SIGNATURE
solana account ADDRESS
solana program show PROGRAM_ID
solana program show --programs
```

## Non-AI debugging route

Use the smallest tool that exposes the next concrete fact:

1. Read the first compiler or runtime error completely.
2. Use `Space ld` or `K` on the relevant symbol.
3. Run the narrowest command that reproduces it.
4. Search the exact error text in the official documentation.
5. Use `gd` to inspect the called type or function.
6. Add temporary `msg!` output for on-chain values.
7. Inspect transaction logs with `solana confirm -v SIGNATURE`.
8. Change one assumption, rerun the same reproduction, and compare.

Search patterns:

```text
E0502 site:doc.rust-lang.org
ConstraintSeeds site:anchor-lang.com
AccountNotInitialized site:anchor-lang.com
simulateTransaction site:solana.com/docs
exact crate API site:docs.rs
```

Avoid search result AI summaries. Open the underlying documentation page.

## Determine which layer is broken

Run checks in this order and stop at the first failing layer:

1. Rust syntax and types: `cargo check --all-targets`
2. Rust correctness warnings: `cargo clippy`
3. Program behavior: `cargo test` or `anchor test`
4. Program artifact: `anchor build`
5. Generated client: run the template's client-generation command
6. TypeScript types: `npm run build` or the project type-check command
7. Browser behavior: browser console and network panel
8. Wallet/RPC: cluster, wallet address, balance, transaction signature
9. On-chain execution: `solana confirm -v SIGNATURE`

## Deployment references

Before any deployment, manually confirm:

```bash
solana config get
solana address
solana balance
anchor keys list
```

Official deployment instructions:

- https://solana.com/docs/programs/deploying
- https://www.anchor-lang.com/docs/quickstart/local

Explorer:

- https://explorer.solana.com/?cluster=devnet

Never commit wallet keypairs, seed phrases, private RPC credentials, or `.env` secrets.
