This repository contains brain imaging analysis and processing related codes as well as some smaller [miscellaneous functions](/MiscFunctions). All codes have been developed for personal use, hence they are not generalizable under all conditions, do not provide exhaustive error and input checking, nor are they fully optimized for speed. Please employ codes accordingly.

The BrainCodes [Wiki](https://github.com/nielsdisbergen/BrainCodes/wiki "BrainCodes Wiki") is **under development** and contains a more general collection of documentation and tips related to (scientific) coding, MRI data analysis, and BrainVoyager usage.

On my personal website I occasionally post [blogs](https://www.nielsdisbergen.net/content/blog_main.html "www.nielsdisbergen.net - Blogs") on similar topics.

In case you have any questions or suggestions, feel free to contact me or open an issue.

## Repository Tree ##

### BrainVoyager (Matlab) ###
- Build design matrices based on protocol (\*.prt) files - [```BuildDesignMatrices.m```](/BuildDesignMatrices)
- Compute GLM contrast(s) from fitted \*.glm files - [```BvGlmContr.m```](/GLMcontrasts)

### Wav-processing (Python) ###
- Apply Sensimetrics Equalization filters to \*.wav files - [```sens_filt_wav.py```](/SensimetricsWavFilter)

### Miscellaneous Functions (Matlab) ###
- Send an Email with Outlook on Windows through ```actxserver```  - [```SendMailOutlook.m```](/MiscFunctions/SendMailOutlook.m)
- Add the currently open Matlab tab to a (git) folder - [```MatlabTabToGit.m```](/MiscFunctions/MatlabTabToGit.m)
- List all files in a directory and perform optional path manipulations - [```GetAllFiles.m```](/MiscFunctions/GetAllFiles.m)

_More codes will follow when I find the time to prepare them for sharing_

**Niels R. Disbergen**
