---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: ''

---

[A clear and concise description of what the issue is. Bug or unexpected behaviour.]

**Environment** (Please describe the environment showing the issue.)
When on AppVeyor.
[If possible, add a link to the build report and the repository.
If you do not use or a (public) `appveyor.yml` file, please consider adding a (censored) version as a [GitHub Gist](https://gist.github.com).]
- Implementation: [e.g. AppVeyor.com, AppVeyor Server]
- Image: [e.g. "Visual Studio 2019', or when using a custom Docker image, please see describe (see under Local).]

When Local.
- OS: [e.g. Windows 10. For Linux you can use the output of `lsb_release -a`]
- PowerShell version: [e.g. the output of `$PSVersionTable.PSVersion.ToString()`]
- Relevant software versions: [consider supplying the output of `Show-SystemInfo -All`]

**To Reproduce**
Steps to reproduce the behaviour: (if no `appveyor.yml` or script supplied)
1. Method of acquiring this module [download source and `Import-Module` command used].
2. Command called '...'
3. Resulting output and other results '...'

**Expected behaviour**
A clear and concise description of what you expected to happen.

**Additional context and Logs**
[Add any other context about the problem here, to help illustrate your issue.]
