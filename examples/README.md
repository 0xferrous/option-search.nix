# Examples

## AgentSpace

Build the AgentSpace option search site:

```bash
nix build ./examples
```

For local repo development, override the option-search input:

```bash
nix build ./examples --override-input option-search path:.
```
