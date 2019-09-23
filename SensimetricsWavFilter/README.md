# Sensimetrics wav-file filtering in Python #

Module ```sens_filt_wav.py``` performs equalization filtering for the Sensimetrics S14 system employing their \*.bin filters for Left and Right channels individually. When a single-channel wav-file is provided, channel 1 will be copied to channel 2. Filtered files are saved in \*.wav file directory.

**_Note_**: only processing of 16bit wave-files sampled at the same frequency as your Sensimetrics filter sampling frequency (44.1kHz generally) is supported, i.e., no resampling is performed on the filter impulse in the current version.

Dependency towards [Scipy](https://www.scipy.org "https://www.scipy.org") with the [Numpy](http://www.numpy.org "http://www.numpy.org") package included.

Code has been tested in Python 2.7.12 and 3.5.2 using Scipy 0.18.0 and Numpy 1.11.1. Resulting \*.wav files after filtering are equal to employing the [Sensimetrics official](http://www.sens.com/downloads "http://www.sens.com/downloads/") EQ Filtering application as well as the MATLAB utility.

### Command line ###
```python
# Syntax:
 sens_filt_wav.py [-h] [-ls] wav_file filt_left filt_right

# Positional arguments:
 wav_file  # path *.wav file
 filt_right  # path right filter
 filt_left  # path left filter

# Optional argument:
 -ls  # wave file save-name suffix, e.g. lab_name
```

### Import ###
```python
# Syntax:
 sens_filt_wav.sens_filt(wav_file, filt_left, filt_right)
 sens_filt_wav.sens_filt(wav_file, filt_left, filt_right, lab_suffix)

# Example:
 import os
 import sens_filt_wav as sfw

 lab_suffix = "7T"
 filt_dir = "S:/SensFilts/7T"
 wav_file = "S:/SoundFiles/Stim1.wav"
 filt_left = os.path.join(filt_dir, "EQF_219L.bin")
 filt_right = os.path.join(filt_dir, "EQF_219R.bin")

 sfw.sens_filt(wav_file, filt_left, filt_right, lab_suffix)  # file saved as Stim1_sensFilt7T.wav
```
