# content/

Static site content, organized by env and site key. Each site lives at
`content/<env>/<site-key>/dist/` — `swa deploy` reads from there.

The `<site-key>` must match a key in `envs/<env>/variables.tf`'s
`var.sites` map.

```
content/
└── dev/
    └── example/
        └── dist/         # build output goes here
```

Build output (`dist/`) is gitignored-style per-env; only placeholders
ship in this repo.