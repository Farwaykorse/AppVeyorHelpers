<!-------------------------------------------------------------><a id="top"></a>
# AppVeyorHelpers
<!----------------------------------------------------------------------------->
<!-- Badges -->
[![Build status][AppVeyor-badge]][AppVeyor-link]
<!-- Description -->
A PowerShell module, containing a collection of helper functions for use with
the AppVeyor CI platform.
Providing robust and tested functionality, with a clean and intuitive interface
for the more complex operations to unlock the advanced features of the CI
platform.

The initial focus is on support for C++ projects using both MSBuild and CMake on
Windows.

<!-- TOC -->
- [Features](#features)
- [Usage](#usage)
- [License](#license)

<!--------------------------------------------------------><a id="features"></a>
## Features
<!----------------------------------------------------------------------------->
- Keep the build-log clean and informative.
  - Send notifications and detailed reports to the AppVeyor message API.
  - Upload test results to the AppVeyor Test API.
  - Encapsulate common complex commands in function calls.

<!-----------------------------------------------------------><a id="usage"></a>
## Usage
<!----------------------------------------------------------------------------->
Usage on AppVeyor.<br />
`appveyor.yml`:
````
init:
- ps: |
    New-Item -ItemType Directory -Force ~\tools | pushd
    git clone https://github.com/Farwaykorse/AppVeyorHelpers.git --quiet
    Import-Module -Name .\AppVeyorHelpers
    popd
````

<!-------------------------------------------------------------><a id="dev"></a>
### Development
<!----------------------------------------------------------------------------->
Unit tests are implemented with [Pester][Pester-link].
To run all unit-tests (and code coverage) for this module call:
```
`.\RunTests.ps1 -Coverage`
```
or [run Invoke-Pester][Invoke-Pester-link] for an individual sub-module:
```
Invoke-Pester -Script .\<script>.Tests.ps1 -CodeCoverage .\<script>.psm1
```

<!---------------------------------------------------------><a id="license"></a>
## License
<!----------------------------------------------------------------------------->
Code licensed under the [MIT License](./LICENSE).

[top](#top)

[AppVeyor-badge]: https://ci.appveyor.com/api/projects/status/l6stx6b6ibi57d9q/branch/master?svg=true
[AppVeyor-link]:  https://ci.appveyor.com/project/Farwaykorse/appveyorhelpers/branch/master
[Pester-link]:    https://github.com/pester/Pester
[Invoke-Pester-link]: https://github.com/pester/Pester/wiki/Invoke‐Pester
