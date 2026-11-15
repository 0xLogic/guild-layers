Guild Layers 1.3.0

- Header compares your layer with the requested destination; rows use Layer A/B/C labels.
- Labels remain stable within each zone for the UI session. They are local aliases, not server-wide identifiers.
- Manual and automatic requests record their destination only after request acceptance.
- Requesting/joining alone never claims a layer change. Confirmation requires observing the different requested layer in the same zone.
- 30 headless tests pass. Live display/transfer and Mojow's presence still require verification.
- Reload the UI after updating.
