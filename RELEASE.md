Guild Layers 1.4.0

- Standalone LayerSwap compatibility: registers its addon-message prefix and reads standard layer/zone/hosting replies.
- Addon-only now includes verified LayerSwap users. Rows show [GL] or [LS].
- Bounded standard LayerSwap discovery requests can provoke host invitations; discovery does not automatically accept them.
- Clicking a LayerSwap member uses the standard request protocol and accepts only their matching invitation. Stock hosting and zone restrictions still apply.
- Fresh Guild Layers presence takes precedence when both addons are installed.
- 31 headless tests pass, including a LayerSwap-only Mojow Joejoe report, filtering, request encoding and matched acceptance. Actual live presence/transfer remains unverified.
- Reload the UI after updating.
