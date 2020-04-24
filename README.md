<!-------------------------------------------------------------><a id="top"></a>
# 🔧 AppVeyorHelpers
<!----------------------------------------------------------------------------->
<!-- Badges -->
[![AppVeyor][AppVeyor-logo] ![Status][AppVeyor-badge] ![tests][AppVeyor-tests]
][AppVeyor-link]
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
- [Notes](#notes)
- [Development](#dev)
- [License](#license)

<!--------------------------------------------------------><a id="features"></a>
## 🏱 Features
<!----------------------------------------------------------------------------->
- Keep the build-log clean and informative.
  - Send notifications and detailed reports to the AppVeyor message API.
  - Upload test results to the AppVeyor Test API.
  - Encapsulate common complex commands in function calls.
- For use on [AppVeyor][AppVeyor-link] and local systems.  
  __Minimum required: PowerShell v5.1, tested on AppVeyor Windows images.__
- Support more build configurations.
  - Use Ninja for faster builds (with CMake projects).
- *\[C++\]* Improved vcpkg usage.

<!-----------------------------------------------------------><a id="usage"></a>
## 💻 Usage
<!----------------------------------------------------------------------------->
Usage on AppVeyor. (appveyor.yml)

Import the PowerShell module at the start of the build session:
````YAML
init:
- ps: |
    New-Item -ItemType Directory -Force ~/Tools | pushd
    git clone https://github.com/Farwaykorse/AppVeyorHelpers.git --quiet
    Import-Module -Name .\AppVeyorHelpers
    popd
````

__A few usage examples:__  
Display the build configuration and the installed CMake version:
```YAML
- ps: Show-SystemInfo -CMake
```

Install tools:
`````YAML
install:
- ps: Install-Ninja -Tag v1.9.0 -AddToPath
`````

Install libraries:
````YAML
- ps: Update-Vcpkg
- ps: vcpkg install ms-gsl:x64-Windows
````

<!-----------------------------------------------------------><a id="notes"></a>
## 📝 Notes
<!----------------------------------------------------------------------------->
These modules can create persistent files in the file-system.
These are primarily the `Install-*` functions.
With the exception of installers that install software in their default location
or update software present on the system (notably
`Update-Vcpkg`) these files are all located in `~/Tools`.

<!-------------------------------------------------------------><a id="dev"></a>
## 🏗 Development
<!----------------------------------------------------------------------------->
Unit tests are implemented with [Pester][Pester-link].
To run all unit-tests (and code coverage) for this module call:
```PowerShell
.\RunTests.ps1 -Coverage
```
or [run Invoke-Pester][Invoke-Pester-link] for an individual sub-module:
`````PowerShell
Invoke-Pester -Script .\<script>.Tests.ps1 -CodeCoverage .\<script>.psm1
`````
Note: The version of Pester supplied with Windows (10 and Server 2016) is not
compatible. Refer to the [Pester documentation][PesterDoc-link] for
instructions.

<!---------------------------------------------------------><a id="license"></a>
## ⚖ License
<!----------------------------------------------------------------------------->
Code licensed under the [MIT License](./LICENSE).

[top](#top)

[AppVeyor-logo]:  https://img.shields.io/static/v1?label=&message=AppVeyor&style=flat&logo=appveyor&color=grey
[AppVeyor-badge]: https://ci.appveyor.com/api/projects/status/l6stx6b6ibi57d9q/branch/master?svg=true
[AppVeyor-tests]: https://img.shields.io/appveyor/tests/Farwaykorse/appveyorhelpers/master?compact_message&logo=appveyor
[AppVeyor-link]:  https://ci.appveyor.com/project/Farwaykorse/appveyorhelpers/branch/master
[Pester-link]:    https://pester.dev
[PesterDoc-link]: https://pester.dev/docs/introduction/installation
[Invoke-Pester-link]: https://github.com/pester/Pester/wiki/Invoke‐Pester
