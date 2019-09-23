#!/usr/bin/env python

"""Apply Sensimetrics filters to *.wav file
    
    This performs equalification filtering for the Sensimetrics system;
    official script-based filtering is only supported in MATLAB. Testing
    performed by comparison of resulting wav-files to both MATLAB and official
    EQ Filtering application of Sensimetrics, using Python 2.7.12 and 3.5.2 with
    scipy 0.18 and numpy 1.11.1.

    Implementation for 16bit *.wav-files only; Sensimetrics filter-files tend
    to be sampled at 44.1kHz, in case wav-file is at different sample frequency a
    warning will be issued. No re-sampling is currently implemented.
"""

# built-in modules
import os
import sys
import argparse
import warnings

# third-party modules
import numpy as np
from scipy.io import wavfile


__author__ = "Niels R Disbergen"
__version__ = "0.1"
__license__ = "MIT"


def main(args):

    """Arguments (args) are send through the option parser and fed to sens_filt
    """

    psr = argparse.ArgumentParser(argument_default="", prog="sens_filt_wav.py", description="Filter wav-files using"
                                  "Sensimetrics *.bin filters for Left and Right Channels",
                                  epilog="@ Niels R. Disbergen - August 2016")
    psr.add_argument('wav_file', help="path to be filtered *.wav-file")
    psr.add_argument('filt_left', help="path to left *.bin filter")
    psr.add_argument('filt_right', help="path to right *.bin filter")
    psr.add_argument('--lab_suffix', '-ls', help="*.wav save-name suffix, e.g. identifying lab")
    res = psr.parse_args(args)

    return sens_filt(res.wav_file, res.filt_left, res.filt_right, res.lab_suffix)


def sens_filt(wav_file, filt_left, filt_right, lab_suffix=""):

    """Applies Sensimetrics filters to a *.wav file
        
        Filters are loaded from Sensimetrics provided binary files and 
        applied to *.wav file left and right channels independently. If the 
        *.wav file is only a single channel, channel one will be copied to 
        channel two and filters applied accordingly. A new wav-file is
        written to the original *.wav directory and saved with suffix
        '_sensFilt.wav'. When called with a lab_suffix this will be suffix to
        the file-name, e.g. '_sensFilt7T.wav'.
        
        Args:
            wav_file (file): *.wav file to filter, 16-bit only
            filt_left (file): left channel Sensimetrics filter file 
            filt_right (file): right channel Sensimetrics filter file
            lab_suffix (str): name to be added as suffix at the end of 
                the filtered *.wav file
        
        Returns:
            int: 0 if successful
        
        Raises:
            NotImplementedError: *.wav file not 16 bits
            NotImplementedError: *.wav file with more than two channels
            
        Example:
            sens_filt('/MyWav.wav', '/7Tleft.bin', 
            '/7Tright.bin', '7TeslaMri')
        
            >>> Wav-file filtering successful, saved as 
            '/MyWav_sensFilt_7TeslaMri.wav'
    """

    # import Sensimetrics filters
    left_imp = np.fromfile(filt_left, dtype=float)
    right_imp = np.fromfile(filt_right, dtype=float)

    [fs, wav_dat] = wavfile.read(wav_file)

    # error if not 16bit wav-file
    if wav_dat.dtype != 'int16':
        raise NotImplementedError("input wav-file is \"%s\" format, code implemented for 16bit only" % wav_dat.dtype)

    if fs != 44100:
        warnings.warn("input wav-file is sampled at %iHz, Sensimetrics files tend to be sampled at 44.1kHz, hence operation could lead to incorrect filtering" % fs, Warning)


    # handle number of channels in wav-file
    if np.size(wav_dat.shape) == 1:  # single channel, left copy before filtering
        wav_out = np.stack((wav_dat, wav_dat), axis=1)
        print("Wave-data \"%s\" is single-channel, left channel copied before filtering" % os.path.split(wav_file)[1])
    elif np.size(wav_dat.shape) == 2 & wav_dat.shape[1] == 2:  # 2-channel keep original
        wav_out = wav_dat
    else:  # Not equal 1 or 2 channel, raise error
        raise NotImplementedError("Wave-data \"%s\" is %s-channels, code built for 1 or 2 channel wav-files only"
                                  % (os.path.split(wav_file)[1], wav_dat.shape[1]))

    # convolve wav-data with filters and truncate overflow
    # data converted (back) to int16, as for writing bit-depth determines bit-rate
    conv_wav_left = np.int16(np.convolve(left_imp, wav_out[:, 0], mode='full'))
    conv_wav_right = np.int16(np.convolve(right_imp, wav_out[:, 1], mode='full'))

    # re-merge channels and write new wav-file
    wav_out = np.stack((conv_wav_left[:np.size(wav_dat, 0)], conv_wav_right[:np.size(wav_dat, 0)]), axis=1)
    save_name = ("%s_sensFilt%s.wav" % (wav_file[:-4], lab_suffix))
    wavfile.write(save_name, fs, wav_out)
    print("Wav-file filtering successful, saved as '%s'" % save_name)

    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
