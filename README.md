
## Introduction

This repository is a package containing a set of plugins for the
[CBRAIN](https://github.com/aces/cbrain) platform.

## Contents of this package

This package provides some tasks and models supporting
parts of [PSOM](http://www.ncbi.nlm.nih.gov/pubmed/22493575).

#### 1. Userfile models

| Name             | Description                                                                                                                    |
|------------------|--------------------------------------------------------------------------------------------------------------------------------|
| FmriStudy        | Superclass of all fMRI study models                                                                                              |
| Adhd200FmriStudy | Model for fMRI studies structured according to the conventions used by [ADHD](http://fcon_1000.projects.nitrc.org/indi/adhd200/) |
| GobsFmriStudy    | Model for fMRI studies structured according to the conventions GOBS                                                              |
| NiakFmriStudy    | Model for fMRI studies structured according to the conventions used by [NIAK](https://www.nitrc.org/projects/niak/)              |
| OpenFmriOrgStudy | Model for fMRI studies structured according to the conventions described by [OpenfMRI](https://openfmri.org/)                    |
| XnatFmriStudy    | Model for fMRI studies structured according to the conventions described by [XNAT](http://www.xnat.org/)                         |

#### 2. CbrainTasks

| Name                       | Description                                                                                    |
|----------------------------|------------------------------------------------------------------------------------------------|
| NiakPipelineFmriPreprocess | A subclass of PsomPipelineLauncher to run NiakPipelineFmriPreprocess                           |
| PsomPipelineLauncher       | Generic [PSOM pipeline](http://www.ncbi.nlm.nih.gov/pubmed/22493575) launcher task             |
| PsomSubtask                | Executes a single task inside a PSOM pipeline                                                  |


## How to install this package

An existing CBRAIN installation is assumed to be operational before
proceeding.

This package must be installed once on the BrainPortal side of a
CBRAIN installation, and once more on each Bourreau side.

#### 1. Installation on the BrainPortal side:

  * Go to the `cbrain_plugins` directory under BrainPortal:

```bash
cd /path/to/BrainPortal/cbrain_plugins
```

  * Clone this repository. This will create a subdirectory called
  `cbrain-plugins-fmri-psom` with the content of this repository:

```bash
git clone git@github.com:aces/cbrain-plugins-fmri-psom.git
```

  * Run the following rake task:

```bash
rake cbrain:plugins:install:all
```

  * Restart all the instances of your BrainPortal Rails application.

#### 2. Installation on the Bourreau side:

**Note**: If you are using the Bourreau that is installed just
besides your BrainPortal application, you do not need to make
any other installation steps, as they share the content of
the directory `cbrain_plugins` through a symbolic link; you
only need to *restart your Bourreau server*.

  * Go to the `cbrain_plugins` directory under BrainPortal
  (yes, *BrainPortal*, because that's where files are installed; on
  the Bourreau side `cbrain_plugins` is a symbolic link):

```bash
cd /path/to/BrainPortal/cbrain_plugins
```

  * Clone this repository:

```bash
git clone git@github.com:aces/cbrain-plugins-fmri-psom.git
```
  * Run the following rake task (which is not the same as for
  the BrainPortal side):

``` bash
rake cbrain:plugins:install:plugins
```

  * Restart your execution server (with the interface, click stop, then start).

