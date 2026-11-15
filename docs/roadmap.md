# Next milestones

## 1. Validate the packaging baseline

- Run the Linux package build and installed-output checks.
- Run GPU correctness on a real NVIDIA host and record GPU, driver, and CUDA versions.
- Investigate any actual packaging failure, retain its diagnostic, and add a
  regression test that fails before the fix. Do not invent a debugging story.

## 2. Add a small release update tool

Choose one real upstream source with versioned releases. A Python tool should:

1. Discover a release through a documented upstream endpoint.
2. Validate version and source metadata and calculate a Nix-compatible source hash.
3. Generate a reviewable package update without modifying unrelated files.
4. Run evaluation, build, and installed-output checks.
5. Report failures with an actionable diagnosis and leave the existing package usable.

Test malformed metadata, download failures, hash mismatches, repeated execution,
and installation regressions. Keep network discovery outside the Nix build.
The initial local application has no upstream release feed, so fabricating an
update service for it would not demonstrate a useful maintenance workflow.

## 3. Contribute a focused improvement upstream

Use an issue encountered during real packaging work to propose a documentation
fix, regression test, or package improvement. Link the discussion and describe
review feedback and tradeoffs without implying acceptance before it occurs.

## Deliberately outside the first milestone

Multiple CUDA versions, cuDNN/TensorRT packaging, binary cache publishing,
self-hosted GPU CI, scheduled release bots, and agentic update workflows.
