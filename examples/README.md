# Examples

## AgentSpace

Build the AgentSpace option search site:

```bash
nix build ./examples
```

For local repo development, override the nix-options-search input:

```bash
nix build ./examples --override-input nix-options-search path:.
```
